---
name: robot-pc
description: "Use when working on the SmartManipulator-X Robot PC, ROS 2 Jazzy hardware bringup, ros2_control, DYNAMIXEL, USB CDC, or robot-side Docker."
---

# SmartManipulator-X Robot PC

## Governing Architecture

This file extends the [main SmartManipulator-X architecture](../smartfusion2-openmanipulator/SKILL.md). Read and follow that architecture for all Robot PC changes; it defines the Robot PC/Operator PC boundary and the shared ROS-to-SmartFusion2 contract.

Use this skill for the embedded/robot computer that runs ROS 2 control and communicates with the physical SmartFusion2 controller.

## Responsibilities

The Robot PC owns:

- ROS 2 Jazzy and `ros2_control`.
- The ROBOTIS `dynamixel_hardware_interface` and DynamixelSDK path, where source analysis confirms it can be reused.
- The project-owned hardware configuration and real-robot bringup under `ros2_ws/src/smartmanipulator_x/`.
- USB CDC communication with SmartFusion2, normally exposed as `/dev/ttyACM0`.
- ROS 2 DDS communication with the Operator PC over the network.

The intended physical control path is:

```text
ros2_control
  -> dynamixel_hardware_interface
  -> DynamixelSDK
  -> USB CDC (/dev/ttyACM0)
  -> SmartFusion2
  -> stepper motors
```

Do not add a custom `smartfusion2_hardware_interface` unless source analysis shows the existing ROBOTIS interface cannot be reused without significant modifications.

## Host and container

The target host is Ubuntu 24.04. The current Docker setup is a development draft in `docker/`; it builds from the repository root and passes `/dev/ttyACM0` into the container. Keep the physical USB device and `dialout` permissions on the Robot PC side.

The current `docker/Dockerfile` is the Robot PC profile. It uses `ros:jazzy-ros-base`, passes `/dev/ttyACM0`, and excludes MoveIt, RViz, Gazebo, and upstream OpenMANIPULATOR GUI/bringup packages. It imports only DYNAMIXEL repositories from `ros2_robot.repos` and scopes `rosdep` and `colcon` to the Robot PC package paths. Operator PC code is maintained in a separate repository; keep its visualization and simulation dependencies out of this image.

Build Robot PC dependencies from `ros2_robot.repos` using `vcs`. The broader `ros2.repos` manifest is for the complete development/operator workspace. ROBOTIS upstream source is checked out separately under `ros2_ws/src/robotis/`; do not copy upstream source into project-owned packages. Verify `jazzy` refs before relying on them, and pin tags or commits for reproducible builds.

## Compatibility requirements

Before enabling real hardware, analyze current ROBOTIS Jazzy sources and record verified findings in the repository's `docs/dynamixel/compatibility-spec.md`:

- DYNAMIXEL models, protocol instructions, and response behavior.
- Control Table addresses, widths, access rules, and initialization sequence.
- Required command/state interfaces, operating modes, update rate, and timeouts.
- Whether the stock hardware interface works with the SmartFusion2 device.

Do not guess XM430 registers or claim compatibility before this analysis. Implement only the minimum virtual-device behavior required by the ROS stack.

## Development sequence

1. Validate the upstream ROS 2 Jazzy stack without SmartFusion2.
2. Verify communication and device access through `/dev/ttyACM0`.
3. Validate the SmartFusion2 protocol and minimum Control Table contract.
4. Test one virtual actuator, then one physical axis, before bringing up the complete robot.
