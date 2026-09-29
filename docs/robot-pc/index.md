# Robot PC

## Responsibility

The Robot PC owns the real-time-facing ROS 2 control path and is the only computer that connects directly to the SmartFusion2 USB CDC device:

```text
ros2_control
  -> ROBOTIS dynamixel_hardware_interface
  -> DynamixelSDK
  -> USB CDC (commonly /dev/ttyACM0)
  -> SmartFusion2
  -> stepper motor control
```

The stock ROBOTIS hardware interface is the preferred starting point, but it must not be assumed compatible until the exact protocol and control-table accesses have been checked against current Jazzy source. See the [compatibility specification](../dynamixel/compatibility-spec.md).

## Host and container

The target Robot PC host is Ubuntu 24.04 with Docker Engine and Docker Compose. The current `docker/` profile is based on `ros:jazzy-ros-base`. It imports the DYNAMIXEL SDK/interface dependencies through `ros2_robot.repos`, builds the project-owned packages, and maps `/dev/ttyACM0` into the container with the `dialout` group.

MoveIt 2, RViz2, Gazebo, and the Operator PC application are intentionally excluded from this image. The Operator PC owns those dependencies and connects over ROS 2 DDS.

Build and start the Robot PC container from the repository root:

```bash
docker compose -f docker/docker-compose.yml build
docker compose -f docker/docker-compose.yml run --rm smartmanipulator_x
```

Before starting, connect the board and confirm the device path on the Linux host:

```bash
lsusb
ls -l /dev/ttyACM0
```

If the board enumerates under another `/dev/ttyACM*` path, update the Compose device mapping. Ensure the host user and container have appropriate device permissions. Windows does not expose a Linux `/dev/ttyACM0` device directly to this container configuration.

Inside the container, inspect the available packages with:

```bash
ros2 pkg list | grep -E '^(dynamixel_sdk|dynamixel_interfaces|dynamixel_hardware_interface|smartmanipulator_x_)'
```

The current launch/configuration packages are scaffolds. No complete physical bringup or SmartFusion2 hardware operation is documented as validated.

## Network and operation

The Robot PC communicates with the Operator PC using ROS 2 DDS over the configured network. Configure the same `ROS_DOMAIN_ID` on both computers and validate DDS discovery, selected network interfaces, multicast/unicast policy, and firewall behavior on the actual network. Do not use SSH as the ROS transport.

Do not enable motor motion until the actuator mapping, motor-driver configuration, limits, homing behavior, and an appropriate stop/safety procedure have been reviewed on the assembled robot. Test incrementally: upstream ROS without hardware, USB/device communication, one virtual actuator, one physical axis, then the complete mechanism.

## Repository ownership

- Robot PC Docker and bringup: `docker/` and `ros2_ws/src/smartmanipulator_x/smartmanipulator_x_bringup/`.
- Project controller and hardware configuration: `ros2_ws/src/smartmanipulator_x/smartmanipulator_x_config/`.
- Canonical robot description location: `ros2_ws/src/smartmanipulator_x/smartmanipulator_x_description/`.
- Upstream dependencies: separate source checkouts selected by `ros2_robot.repos`; pin immutable revisions for reproducible builds before production use.