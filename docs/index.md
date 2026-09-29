# SmartManipulator-X

SmartManipulator-X combines the ROS control approach used by ROBOTIS OpenMANIPULATOR-X with the mechanical design of the [BCN3D Moveo](https://github.com/BCN3D/BCN3D-Moveo). A Microchip SmartFusion2-based controller is intended to replace the original actuator electronics and drive stepper motors while presenting the host with the verified DYNAMIXEL behavior required by the ROS hardware stack.

The target system separates planning, robot-side control, and deterministic motor control:

```text
Operator PC                         Robot PC
MoveIt 2 / RViz2 / Gazebo   --DDS--> ROS 2 Jazzy / ros2_control
                                             |
                                      ROBOTIS DYNAMIXEL
                                      hardware interface
                                             |
                                         USB CDC
                                             |
                                      SmartFusion2
                                   ARM + FPGA, design TBD
                                             |
                              stepper drivers and motors
                                             |
                                  BCN3D Moveo mechanics
```

## Current status

This repository is an integration scaffold, not a validated Moveo controller. The Robot PC Docker profile and ROS package skeletons are present. The project robot-description package contains no URDF/Xacro or mesh assets yet; controller parameters and the hardware plugin are also unselected. SmartFusion2 firmware and the Operator PC application are maintained in separate repositories.

No actuator compatibility, motor-driver design, robot joint mapping, real-hardware bringup, or complete simulation is claimed. See the [system overview](architecture/index.md), [development roadmap](development/index.md), and [DYNAMIXEL compatibility contract](dynamixel/compatibility-spec.md) for decisions and open work.

## Documentation map

- [System architecture](architecture/index.md) describes component boundaries and the intended control path.
- [BCN3D Moveo mechanics](mechanical/index.md) describes the mechanical source and model-integration work.
- [Robot PC](robot-pc/index.md) covers ROS control, Docker, and physical USB ownership.
- [Operator PC](operator-pc/index.md) covers planning, visualization, simulation, and DDS.
- [SmartFusion2 firmware](smartfusion2/index.md) covers the virtual actuator and ARM/FPGA design boundary.
- [DYNAMIXEL compatibility](dynamixel/compatibility-spec.md) tracks the still-unverified host/device contract.

## Build this site

Create and activate the repository-local `.venv` first, then build from the repository root:

```bash
python -m mkdocs build --strict
```

Use `python -m mkdocs serve` to preview edits locally. See the [development guide](development/index.md) for `.venv` setup on Windows and Linux.