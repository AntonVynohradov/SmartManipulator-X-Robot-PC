---
name: smartfusion2-openmanipulator
description: "Use as the governing architecture for SmartManipulator-X and OpenMANIPULATOR-X work spanning the Robot PC, Operator PC, ROS 2, or SmartFusion2. Load the matching domain skill for focused implementation."
---

# SmartManipulator-X Project Architecture

## Skill Hierarchy

This is the canonical project skill. It defines the system boundaries and cross-component contracts; domain skills extend it and must not contradict it.

- [Robot PC extension](../robot-pc/SKILL.md): ROS 2 control, hardware bringup, USB, and the robot-side container.
- [Operator PC extension](../operator-pc/SKILL.md): MoveIt 2, RViz2, Gazebo, simulation, and DDS.
- [SmartFusion2 extension](../smartfusion2/SKILL.md): the separate firmware repository, ARM/FPGA partition, and DYNAMIXEL emulation.

For a focused task, apply this architecture together with the matching domain extension. For work crossing system boundaries, use every relevant extension and preserve the shared contracts described here. If a domain detail conflicts with this architecture, resolve the conflict in this main skill and the affected extension together.

---

## Project Goal

The project aims to develop a custom motor controller based on **Microchip SmartFusion2**, functionally replacing the DYNAMIXEL controllers/actuators used by the ROBOTIS OpenMANIPULATOR-X.

The SmartFusion2 contains:

* an ARM processor,
* FPGA fabric,
* an implementation of DYNAMIXEL Protocol 2.0,
* stepper motor control,
* USB CDC interface to the host computer,
* and, ultimately, functionality corresponding to the XM430 actuator.

The ROS 2 computer should interact with the SmartFusion2 as similarly as possible to a standard DYNAMIXEL interface.

---

# Target Architecture

```text
                         Ethernet / ROS 2 DDS
                  ┌──────────────────────────────┐
                  │                              │
                  ▼                              ▼
        ┌─────────────────────┐        ┌─────────────────────┐
        │ Embedded / Robot PC │        │ Operator PC         │
        │                     │        │                     │
        │ Docker              │        │ ROS 2 Jazzy         │
        │ ROS 2 Jazzy         │        │ MoveIt 2            │
        │ ros2_control        │        │ RViz2               │
        │ DynamixelSDK        │        │ Gazebo              │
        │ OpenMANIPULATOR     │        │                     │
        └──────────┬──────────┘        └─────────────────────┘
                   │
                   │ USB CDC
                   │ /dev/ttyACM0
                   ▼
        ┌────────────────────────────┐
        │ SmartFusion2               │
        │                            │
        │ ARM + FPGA                 │
        │ DYNAMIXEL Protocol 2.0     │
        │ Virtual DYNAMIXEL device   │
        │ Control Table              │
        │ Motor control              │
        └─────────────┬──────────────┘
                      │
                      ▼
                 Stepper motors
```

---

# Main Assumptions

## Operating System

The ROS host system is:

* Ubuntu 24.04
* Docker
* ROS 2 Jazzy

ROS 2 Jazzy is the target ROS distribution for this project.

## USB Communication

The SmartFusion2 exposes a:

```text
USB CDC
```

interface to the host computer and should appear as, for example:

```text
/dev/ttyACM0
```

The Docker container must have access to this device.

## Communication with SmartFusion2

The PC sends packets over USB using DYNAMIXEL Protocol 2.0.

The SmartFusion2:

1. receives the packet,
2. parses DYNAMIXEL Protocol 2.0,
3. operates on its own Control Table,
4. executes the requested control operation,
5. returns a response compliant with Protocol 2.0.

The SmartFusion2 is therefore **not simply a USB-to-DYNAMIXEL bridge**.

It is a custom motor controller implementing DYNAMIXEL-device behavior.

---

# ROS Integration Strategy

The preferred architecture is:

```text
ROS 2
  │
  ▼
ros2_control
  │
  ▼
dynamixel_hardware_interface
  │
  ▼
DynamixelSDK
  │
  ▼
USB CDC
  │
  ▼
SmartFusion2
```

At the first stage, DO NOT create a custom:

```text
smartfusion2_hardware_interface
```

if the existing `dynamixel_hardware_interface` can be used without significant modifications.

The goal is to maximize reuse of the existing ROBOTIS software stack.

---

# Role of the SmartFusion2

The SmartFusion2 should functionally replace DYNAMIXEL actuators/controllers.

The target system should allow:

```text
MoveIt 2
   ↓
ros2_control
   ↓
DynamixelSDK
   ↓
SmartFusion2
   ↓
Stepper motor
```

without requiring changes to the higher-level ROS application logic.

---

# Virtual DYNAMIXEL / XM430 Compatibility

The SmartFusion2 should provide its own Control Table.

It should contain at least the elements actually required by:

* `dynamixel_hardware_interface`,
* OpenMANIPULATOR-X,
* the `ros2_control` configuration,
* DynamixelSDK.

The entire XM430 Control Table should NOT be implemented automatically.

First determine the minimum required register set.

Potential elements include:

```text
Model Number
Firmware Version
ID
Baud Rate
Operating Mode
Torque Enable
Goal Position
Goal Velocity
Goal Current
Present Position
Present Velocity
Present Current
Hardware Error Status
```

This list is provisional and must be verified against the current ROBOTIS source code.

---

# OpenMANIPULATOR-X

The project is based on the current ROBOTIS ROS 2 Jazzy stack.

Relevant components include:

```text
DynamixelSDK
dynamixel_interfaces
dynamixel_hardware_interface
open_manipulator
ros2_control
MoveIt 2
RViz2
Gazebo
```

The ROBOTIS source code should not be copied wholesale into the custom repository.

Upstream repositories should be managed as separate repositories.

---

# Repository Structure

The current scaffold structure is:

```text
SmartManipulator-X/
│
├── README.md
├── LICENSE
├── .gitignore
├── .dockerignore
├── ros2.repos
├── ros2_robot.repos
├── mkdocs.yml
├── requirements-docs.txt
├── .agents/
│   └── skills/
│       ├── smartfusion2-openmanipulator/SKILL.md
│       ├── robot-pc/SKILL.md
│       ├── operator-pc/SKILL.md
│       └── smartfusion2/SKILL.md
│
├── docker/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── entrypoint.sh
│
├── ros2_ws/
│   └── src/
│       │
│       ├── robotis/
│       │   ├── DynamixelSDK/
│       │   ├── dynamixel_interfaces/
│       │   ├── dynamixel_hardware_interface/
│       │   └── open_manipulator/
│       │
│       └── smartmanipulator_x/
│           │
│           ├── smartmanipulator_x_description/
│           │   ├── urdf/
│           │   ├── meshes/
│           │   ├── rviz/
│           │   ├── CMakeLists.txt
│           │   └── package.xml
│           │
│           ├── smartmanipulator_x_bringup/
│           │   ├── launch/
│           │   ├── config/
│           │   ├── CMakeLists.txt
│           │   └── package.xml
│           │
│           ├── smartmanipulator_x_config/
│           │   ├── config/
│           │   │   ├── controllers.yaml
│           │   │   ├── hardware.yaml
│           │   │   └── dynamixel/
│           │   ├── CMakeLists.txt
│           │   └── package.xml
│           │
│           └── smartmanipulator_x_tests/
│               └── README.md
│
├── tools/
│   ├── diagnostics/
│   └── usb/
│
└── docs/
   ├── index.md
   ├── architecture/index.md
   ├── mechanical/index.md
   ├── robot-pc/index.md
   ├── operator-pc/index.md
   ├── smartfusion2/index.md
   ├── dynamixel/compatibility-spec.md
   └── development/index.md
```

The ROBOTIS directories under `ros2_ws/src/robotis/` are checkout targets, not vendored source. `vcs import` creates them from `ros2.repos`; `ros2_robot.repos` is the Robot PC-only dependency subset. Empty project areas are retained with `.gitkeep` files. Docker builds use the repository root as context and the root `.dockerignore`; the Operator PC tree is excluded from the Robot PC image.

---

# Responsibility Separation

## `robotis/`

Contains ROBOTIS upstream code.

Avoid modifying it unless necessary.

Expected components:

```text
DynamixelSDK
dynamixel_interfaces
dynamixel_hardware_interface
open_manipulator
```

## `smartmanipulator_x/`

Contains project-specific code.

This includes:

* robot description,
* configuration,
* launch files,
* controllers,
* tests.

## Operator PC Repository Boundary

The Operator PC application is maintained in a separate repository and is not part of this Robot PC repository. Keep MoveIt 2, RViz2, Gazebo, operator UI, and simulation-only assets there. The `.agents/skills/operator-pc/SKILL.md` file remains here as cross-repository architecture guidance for agents.

The canonical robot description currently lives in `ros2_ws/src/smartmanipulator_x/smartmanipulator_x_description/`. The separate Operator PC repository should consume this shared package or a future extracted shared-description repository; do not maintain a divergent URDF/Xacro copy.

## Firmware Repository Boundary

The SmartFusion2 firmware is maintained in a separate repository and is not stored under this repository. Keep the ARM, FPGA, USB CDC, DYNAMIXEL protocol, Control Table, and motor-control implementation in that firmware repository. This repository owns the ROS integration and the compatibility contract shared with the firmware.

The firmware's logical areas are:

```text
ARM
FPGA
DYNAMIXEL Protocol
USB CDC
Control Table
Motor Control
```

---

# SmartFusion2 Firmware

The firmware lives in a separate repository. The following is its preferred logical architecture and applies across the repository boundary.

Preferred logical architecture:

```text
USB CDC
   │
   ▼
DYNAMIXEL Protocol 2.0 parser
   │
   ▼
Virtual DYNAMIXEL Control Table
   │
   ▼
Motor Control
   │
   ├── ARM
   └── FPGA
```

The FPGA should be used where deterministic hardware behavior is required, for example:

* STEP/DIR signal generation,
* encoder interfaces,
* high-speed control loops,
* axis synchronization.

The ARM should primarily handle:

* USB CDC,
* protocol processing,
* configuration,
* diagnostics,
* communication with the FPGA,
* higher-level control logic.

The exact ARM/FPGA partition remains to be designed.

---

# Real Robot vs Simulation

The same MoveIt 2 application should be usable with both the real robot and the simulation.

## Real Robot

```text
MoveIt 2
   ↓
ros2_control
   ↓
dynamixel_hardware_interface
   ↓
DynamixelSDK
   ↓
USB
   ↓
SmartFusion2
   ↓
motors
```

## Simulation

```text
MoveIt 2
   ↓
ros2_control
   ↓
Gazebo
   ↓
simulated joints
```

The same robot model should be shared between both modes.

---

# ROS 2 DDS

The system consists of two computers.

## Embedded / Robot PC

Responsible for:

* SmartFusion2,
* the physical robot,
* ROS 2,
* `ros2_control`.

## Operator PC

Responsible for:

* MoveIt 2,
* RViz2,
* Gazebo,
* user interface.

The computers should communicate through ROS 2 DDS.

SSH is considered an administrative mechanism, not the primary ROS communication mechanism.

---

# Docker and Deployment Environments

The target deployment separates the two computers:

| Environment | Primary responsibilities | Container scope |
| --- | --- | --- |
| Robot PC | ROS 2 Jazzy, `ros2_control`, ROBOTIS hardware interface, DynamixelSDK, physical USB CDC access | Focused robot-control image with `/dev/ttyACM0` and required USB permissions |
| Operator PC | MoveIt 2, RViz2, Gazebo, user interface, and simulation | Native ROS 2 Jazzy or a separate operator image with GUI/GPU and DDS networking |

The Robot PC owns `/dev/ttyACM0` and the `dialout` access needed by the SmartFusion2 connection. The Operator PC communicates with the Robot PC using ROS 2 DDS; it does not need direct access to the controller USB device. SSH is administrative only.

The current `docker/Dockerfile` is the Robot PC profile, based on `ros:jazzy-ros-base`. It imports the DYNAMIXEL-only subset in `ros2_robot.repos`, scopes `rosdep` and `colcon` to DYNAMIXEL and project-owned Robot PC packages, and passes `/dev/ttyACM0` through Compose. It excludes MoveIt 2, RViz2, Gazebo, and upstream OpenMANIPULATOR GUI/bringup packages, whose manifests pull in operator/simulation dependencies. The Operator PC has no dedicated image yet; use native ROS 2 Jazzy or create a separate image without expanding the Robot PC container.

The Dockerfile installs dependencies with `rosdep` and runs `colcon build` in `/ws`. Compose builds from the repository root, passes `/dev/ttyACM0`, adds `dialout`, and sets ROS domain ID `0`. It does not bind-mount the host workspace, so rebuild after changing project sources or dependency refs. Operator PC assets are maintained in another repository and are not part of this build context. Verify upstream `jazzy` refs before relying on them and pin commits or tags for reproducible builds.

The Robot PC image builds and compiles the selected packages. The physical USB/hardware workflow remains untested, and the Operator PC has no dedicated image yet.

---

# `ros2.repos`

Upstream dependencies should be managed using `vcs`.

Conceptually:

```yaml
repositories:

  robotis/DynamixelSDK:
    type: git
    url: https://github.com/ROBOTIS-GIT/DynamixelSDK.git
    version: jazzy

  robotis/dynamixel_interfaces:
    type: git
    url: https://github.com/ROBOTIS-GIT/dynamixel_interfaces.git
    version: jazzy

  robotis/dynamixel_hardware_interface:
    type: git
    url: https://github.com/ROBOTIS-GIT/dynamixel_hardware_interface.git
    version: jazzy

  robotis/open_manipulator:
    type: git
    url: https://github.com/ROBOTIS-GIT/open_manipulator.git
    version: jazzy
```

The current `ros2.repos` file uses the `jazzy` branch for each upstream repository. Verify that these repositories and refs exist and are mutually compatible before building or depending on them. For reproducible releases, replace moving branch refs with verified tags or commit hashes.

---

# Development Strategy

The project should be developed in layers.

## Stage 1 — ROS without SmartFusion2

Run:

```text
ROS 2 Jazzy
+
OpenMANIPULATOR-X
+
ros2_control
+
RViz2
```

## Stage 2 — DynamixelSDK

Verify communication with a device through:

```text
/dev/ttyACM0
```

## Stage 3 — SmartFusion2 Protocol

Implement:

```text
USB CDC
+
DYNAMIXEL Protocol 2.0
+
Control Table
```

## Stage 4 — Single Virtual Actuator

Make the SmartFusion2 emulate one DYNAMIXEL actuator.

Initially test:

```text
PING
READ
WRITE
```

Then:

```text
Torque Enable
Goal Position
Present Position
```

## Stage 5 — Single Axis

Connect one stepper motor.

## Stage 6 — Complete Robot

Bring up all robot axes.

## Stage 7 — MoveIt 2

Connect the real robot to MoveIt 2.

## Stage 8 — Gazebo

Add the parallel simulation.

## Stage 9 — Two Computers

Separate:

```text
robot PC
```

and:

```text
operator/simulation PC
```

using ROS 2 DDS.

---

# Most Important Next Step

Before treating the prepared Docker image as a validated runtime, or implementing the compatibility layer, analyze the current source code of:

```text
dynamixel_hardware_interface
DynamixelSDK
open_manipulator
```

and determine exactly:

1. which DYNAMIXEL models are declared,
2. which Control Table registers are accessed,
3. which `command_interfaces` are required,
4. which `state_interfaces` are required,
5. which Operating Modes are used,
6. which Control Table addresses are required,
7. which Protocol 2.0 instructions are used,
8. what `ros2_control` update frequency is expected,
9. what response behavior is required from the device,
10. whether the SmartFusion2 can work without modifying `dynamixel_hardware_interface`.

Based on this analysis, create a specification for:

```text
SmartFusion2
DYNAMIXEL/XM430 Compatibility Layer
```

This specification should become the common contract between the SmartFusion2 firmware and the ROS software stack.

---

# Design Principle

The SmartFusion2 does not need to be an exact copy of the XM430.

The objective is:

```text
functional compatibility
```

with the requirements of:

```text
OpenMANIPULATOR-X
+
ros2_control
+
dynamixel_hardware_interface
+
MoveIt 2
```

rather than implementing every XM430 feature.

Unnecessary functionality should be omitted unless it is required by the software stack.

---

# Project Name

Project name:

```text
SmartManipulator-X
```

Main controller:

```text
SmartFusion2
```

Target functionality:

```text
SmartFusion2-based DYNAMIXEL-compatible
controller for OpenMANIPULATOR-X
```

---

# Information Validity

ROS distributions, ROBOTIS repositories, branches, APIs, and configurations may change over time.

Before implementation, verify the current ROBOTIS source code and ROS 2 Jazzy documentation.

Do not guess XM430 Control Table parameters or device behavior.

Derive them from the current source code and documentation.
