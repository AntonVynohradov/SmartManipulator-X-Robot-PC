---
name: operator-pc
description: "Use when working on the SmartManipulator-X Operator PC, MoveIt 2, RViz2, Gazebo, robot visualization, simulation, or ROS 2 DDS between computers."
---

# SmartManipulator-X Operator PC

## Governing Architecture

This file extends the [main SmartManipulator-X architecture](../smartfusion2-openmanipulator/SKILL.md). Read and follow that architecture for all Operator PC changes; it defines the Operator PC/Robot PC boundary and the shared robot model and DDS requirements.

Use this skill for the operator/simulation computer. Its role is planning, visualization, and simulation, not direct access to the SmartFusion2 USB device.

## Responsibilities

The Operator PC owns:

- MoveIt 2 planning and the operator interface.
- RViz2 visualization.
- Gazebo simulation and simulation-specific configuration.
- ROS 2 DDS communication with the Robot PC over Ethernet or the configured network.

The Operator PC project is maintained in a separate repository. Keep its Operator-specific simulation assets there, for example:

```text
simulation/gazebo/
simulation/rviz/
simulation/moveit/
```

These paths do not exist in the current Robot PC repository; create them in the separate Operator PC repository. Keep only configuration and assets owned by SmartManipulator-X there. The canonical robot model currently lives at `ros2_ws/src/smartmanipulator_x/smartmanipulator_x_description/` in the Robot PC repository. Consume that package or a future extracted shared-description repository instead of duplicating its URDF/Xacro or joint definitions. Keep ROBOTIS upstream source managed through `ros2.repos` or the Operator PC repository's own manifest.

## Runtime separation

The Operator PC does not need `/dev/ttyACM0` or direct USB permissions for the SmartFusion2. The Robot PC owns that hardware connection and runs `ros2_control` for the physical robot.

MoveIt 2, RViz2, Gazebo, and their graphical/runtime dependencies belong on the Operator PC. They may run natively on Ubuntu 24.04 with ROS 2 Jazzy or in a dedicated Operator PC container. If containerized, configure display and GPU access separately from the Robot PC container and preserve ROS 2 DDS connectivity between computers.

The Robot PC Dockerfile is based on `ros:jazzy-ros-base` and excludes visualization/simulation packages. The Operator PC repository owns its runtime setup and may use native ROS 2 Jazzy or a separate image. Do not add Operator PC dependencies to the Robot PC Dockerfile.

## Real robot and simulation

The same MoveIt 2 application should be usable with either the real Robot PC or Gazebo simulation. Keep the robot description and joint/controller semantics consistent across both modes. In simulation, route `ros2_control` to the Gazebo integration; for the physical robot, route it through the verified ROBOTIS DYNAMIXEL hardware path on the Robot PC.

Validate DDS discovery, domain ID, network interfaces, and firewall behavior when the two computers are on separate hosts. SSH is for administration, not the ROS communication path.
