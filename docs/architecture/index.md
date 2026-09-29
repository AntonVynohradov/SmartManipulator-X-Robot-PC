# System Architecture

## Project objective

The target is to use the ROS 2 control and operator-software concepts of ROBOTIS [OpenMANIPULATOR-X](https://docs.robotis.com/docs/systems/openmanipulator_x/overview/) with the mechanical design of [BCN3D Moveo](https://github.com/BCN3D/BCN3D-Moveo). SmartFusion2 is intended to replace the original motor controller/actuator electronics and control stepper motors on the Moveo mechanism.

These sources have different roles. OpenMANIPULATOR-X is the reference for the ROS/DYNAMIXEL software stack; BCN3D Moveo is the mechanical reference. The OpenMANIPULATOR-X robot geometry, joints, actuator assumptions, and hardware configuration must not be copied as if they described Moveo.

## System context

```text
 Operator PC                              Robot PC
+--------------------------+   ROS 2    +-------------------------------+
| MoveIt 2                 |    DDS     | ROS 2 Jazzy                   |
| RViz2                    |<---------->| ros2_control                  |
| Gazebo (simulation mode) |            | ROBOTIS hardware interface    |
+--------------------------+            | DynamixelSDK                  |
                                        +---------------+---------------+
                                                        | USB CDC
                                                        | DYNAMIXEL Protocol 2.0
                                        +---------------v---------------+
                                        | SmartFusion2                   |
                                        | ARM + FPGA; partition TBD      |
                                        | virtual DYNAMIXEL device       |
                                        +---------------+---------------+
                                                        | STEP/DIR or another
                                                        | verified driver link
                                        +---------------v---------------+
                                        | Stepper drivers and motors     |
                                        +---------------+---------------+
                                                        |
                                        +---------------v---------------+
                                        | BCN3D Moveo mechanics          |
                                        +-------------------------------+
```

The motor-driver interface shown above is a design boundary, not a selected hardware implementation. The SmartFusion2 is a motor controller implementing device behavior; it is not merely a USB-to-DYNAMIXEL converter.

## Component ownership

| Component | Responsibility | Repository boundary |
| --- | --- | --- |
| Robot PC | ROS 2 Jazzy, `ros2_control`, verified ROBOTIS hardware path, USB CDC access, robot bringup | This repository |
| Operator PC | MoveIt 2, RViz2, Gazebo, operator workflows, ROS 2 DDS client | Separate Operator PC repository |
| SmartFusion2 | DYNAMIXEL Protocol 2.0 device behavior, control table, motor-control coordination | Separate firmware repository |
| BCN3D Moveo | Mechanical links, joints, printed parts, assembly and mechanical limits | Upstream mechanical source; project model integration belongs in this repository or a shared description repository |
| ROBOTIS packages | Reusable SDK, hardware interface, messages, and upstream OpenMANIPULATOR software | Separate upstream checkouts managed by the manifests |

The canonical project robot-description package is `ros2_ws/src/smartmanipulator_x/smartmanipulator_x_description/`. It is currently empty apart from placeholders. The Operator PC should consume this package or a future shared-description package rather than maintain a divergent robot model.

## Software reuse boundary

The intended physical path is:

```text
MoveIt 2
  -> ros2_control
  -> ROBOTIS dynamixel_hardware_interface
  -> DynamixelSDK
  -> USB CDC
  -> SmartFusion2 virtual DYNAMIXEL device
  -> stepper motor control
```

Reuse the existing ROBOTIS hardware interface if source analysis confirms that its model configuration, protocol operations, control-table accesses, command/state interfaces, and timing requirements can be supported. Do not add a project-specific `smartfusion2_hardware_interface` pre-emptively. Implement only the device behavior needed by the verified host stack, not a presumed complete XM430 clone.

Reusing the OpenMANIPULATOR-X ROS application does not make its robot model or joint/controller configuration valid for Moveo. MoveIt planning groups, joint names, limits, kinematics, transmission assumptions, ros2_control interfaces, and controller configuration must agree with a verified Moveo description and the physical stepper setup.

The Robot PC image is intentionally separate from the Operator PC runtime. MoveIt, RViz2, and Gazebo do not belong in the current Robot PC Docker image. In simulation, route `ros2_control` to the selected Gazebo integration; on the real robot, route it to the verified DYNAMIXEL/SmartFusion2 path. Keep the robot model and joint semantics consistent across both modes.

## Operating assumptions

- The Robot PC target is Ubuntu 24.04 with ROS 2 Jazzy; the current Robot PC profile uses Docker.
- The Operator PC runs ROS 2 Jazzy and reaches the Robot PC using DDS over the configured network.
- SmartFusion2 is expected to enumerate as USB CDC, commonly `/dev/ttyACM0`; this must be confirmed on the actual board and host.
- Only the Robot PC owns the USB connection to SmartFusion2. The Operator PC does not require direct USB access.
- DDS domain ID, interface selection, discovery, and firewall policy must be configured consistently across hosts. SSH is for administration, not the ROS data path.
- ARM/FPGA partitioning, motor-driver hardware, feedback sensors, and safety behavior are not finalized.

## Verified state versus target

| Area | Current repository state | Target or open verification |
| --- | --- | --- |
| Robot description | Empty URDF/mesh placeholders | Import/author BCN3D Moveo model; verify frame, joint, limit, and visual/collision data |
| Robot PC | Draft Docker profile and ROS package scaffolds | Verify current upstream Jazzy sources, USB behavior, and physical bringup |
| Operator PC | Not implemented in this repository | Separate project; consume the canonical Moveo description and validate DDS |
| SmartFusion2 | Firmware not included here | Separate project; implement the minimum verified DYNAMIXEL device contract |
| Hardware configuration | Plugin and YAML parameter schema unselected | Verify stock ROBOTIS interface compatibility before choosing an adapter |
| Mechanical/electrical integration | No Moveo assets or motor-driver design in this repository yet | Establish joint-to-motor mapping, drivers, sensing, limits, and safety requirements |

## Upstream references

- [ROBOTIS OpenMANIPULATOR-X overview](https://docs.robotis.com/docs/systems/openmanipulator_x/overview/)
- [BCN3D Moveo source repository](https://github.com/BCN3D/BCN3D-Moveo)
- [ROBOTIS OpenMANIPULATOR ROS 2 source](https://github.com/ROBOTIS-GIT/open_manipulator)
- [DynamixelSDK source](https://github.com/ROBOTIS-GIT/DynamixelSDK)
- [DYNAMIXEL hardware interface source](https://github.com/ROBOTIS-GIT/dynamixel_hardware_interface)