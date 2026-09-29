# Operator PC

## Responsibility

The Operator PC owns motion planning, operator visualization, and simulation workflows:

- MoveIt 2 planning and execution clients.
- RViz2 visualization and operator-facing configuration.
- Gazebo simulation and simulation-specific `ros2_control` integration.
- ROS 2 DDS communication with the Robot PC over the configured network.

It does not own the SmartFusion2 USB connection, motor hardware, or physical `ros2_control` hardware interface. Do not pass `/dev/ttyACM0` through to the Operator PC.

## Separate repository

Operator PC implementation is maintained in a separate repository; this repository contains its architecture guidance only. Keep Operator-specific launch files, MoveIt configuration, RViz setup, Gazebo assets, and runtime/container configuration in that repository. The Robot PC Docker image must remain free of Operator PC GUI and simulation dependencies.

Consume the canonical robot description from `smartmanipulator_x_description` or a future shared-description repository. The current description package is only an empty scaffold, so a validated BCN3D Moveo model must be integrated before configuring planning or simulation. Do not duplicate an independent URDF/Xacro or substitute the OpenMANIPULATOR-X model for Moveo.

## Real robot and simulation

The intended MoveIt application should work with either the physical Robot PC or simulation. The robot model, joint names, limits, planning groups, and controller-facing joint semantics must agree in both modes:

```text
Real robot: MoveIt -> DDS -> Robot PC ros2_control -> verified DYNAMIXEL path -> SmartFusion2
Simulation: MoveIt -> Gazebo ros2_control integration -> simulated Moveo joints
```

Use the physical path only after SmartFusion2 compatibility and robot bringup are verified. Gazebo integration and Moveit configuration are not implemented in this repository.

## DDS checklist

For two-host operation, configure matching ROS 2 domain IDs and verify that both hosts use reachable network interfaces. Check DDS discovery, routing/multicast support, and firewall rules in the deployment network. SSH can be used for administration, but it is not a substitute for DDS connectivity. Simulation-only runs can be local to the Operator PC and do not require physical hardware.