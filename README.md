# SmartManipulator-X

SmartManipulator-X combines the ROS control approach of ROBOTIS OpenMANIPULATOR-X with the mechanical design of [BCN3D Moveo](https://github.com/BCN3D/BCN3D-Moveo). A SmartFusion2-based controller is intended to replace the original actuator electronics and drive stepper motors while providing the verified DYNAMIXEL Protocol 2.0 behavior required by the ROS host stack. The target Robot PC is Ubuntu 24.04; its ROS environment is ROS 2 Jazzy in Docker.

The SmartFusion2 is intended to act as a virtual DYNAMIXEL device over USB CDC, not as a USB-to-DYNAMIXEL bridge. Control Table addresses, operating modes, timing, and device responses remain unverified until checked against current ROBOTIS sources.

## Repository layout

- `.agents/skills/`: governing project architecture and focused Robot PC, Operator PC, and SmartFusion2 guidance. The Operator PC skill is cross-repository guidance; its implementation lives in a separate repository.
- `docker/`: ROS 2 Jazzy Robot PC image, Compose service, and entrypoint.
- `ros2_ws/src/smartmanipulator_x/`: project-owned description, bringup, configuration, and test areas.
- `ros2_ws/src/robotis/`: checkout target for upstream repositories selected by `ros2_robot.repos` in the Robot PC image; `ros2.repos` remains the broader workspace manifest.
- SmartFusion2 firmware is maintained in a separate repository and is not included in this repository.
- `tools/`: diagnostics and USB utilities.
- `docs/`: the MkDocs site covering architecture, Moveo mechanics, Robot PC, Operator PC, SmartFusion2, DYNAMIXEL compatibility, and development. See [`docs/index.md`](docs/index.md).

Use the repository-local `.venv` for MkDocs. Follow the platform-specific setup and Docker development workflow in the [development guide](docs/development/index.md); the [documentation home](docs/index.md) provides the site overview.

## Prerequisites

- Ubuntu 24.04 Linux Robot PC. The USB device mapping below targets Linux; Docker Desktop on Windows does not automatically expose a Linux `/dev/ttyACM0` device.
- Docker Engine and Docker Compose.
- For hardware use, a SmartFusion2 board enumerated as USB CDC, typically `/dev/ttyACM0`.

## Robot PC Docker image

Connect the SmartFusion2 to the Robot PC and check that Linux sees the USB CDC device:

```bash
lsusb
ls -l /dev/ttyACM0
```

If the board appears under another `/dev/ttyACM*` path, update the device mapping in `docker/docker-compose.yml` to match before starting the container. Check `ros2_robot.repos`; its `jazzy` refs are branch names and can move. From the repository root, build the image:

```bash
docker compose -f docker/docker-compose.yml build
```

The Compose service builds the image tagged `smartmanipulator-x-robot:jazzy`. Start an interactive Robot PC container with the USB device passed through:

```bash
docker compose -f docker/docker-compose.yml run --rm smartmanipulator_x
```

The container entrypoint sources ROS Jazzy and the built workspace automatically. Inside it, confirm the USB node and key ROS packages are visible:

```bash
ls -l /dev/ttyACM0
ros2 pkg list | grep -E '^(dynamixel_sdk|dynamixel_interfaces|dynamixel_hardware_interface|smartmanipulator_x_)'
```

Type `exit` to stop the interactive shell; `--rm` removes that container. The image uses `ros:jazzy-ros-base` and contains ROS control, the DYNAMIXEL SDK/interface, Robot PC packages, USB diagnostics, and build tools. It deliberately excludes MoveIt 2, RViz2, Gazebo, and the upstream OpenMANIPULATOR GUI/bringup packages. The workspace is baked into the image, not bind-mounted, so rebuild after changing project sources or `ros2_robot.repos`.

The image build and package compilation have succeeded. Hardware operation is not yet validated: the Control Table, protocol behavior, timing, and final robot configuration remain to be verified in [`docs/dynamixel/compatibility-spec.md`](docs/dynamixel/compatibility-spec.md), and the current bringup/config packages are still scaffolds without a complete real-robot launch configuration. Operator PC code and assets are maintained in a separate repository and are not included here.

## Development

See the [development guide](docs/development/index.md) for prerequisites, `.venv` setup, Docker image build/use, and the staged integration roadmap.

Project-owned files are licensed under Apache License 2.0, matching the ROBOTIS OpenMANIPULATOR-X ROS 2 repository. Third-party dependencies retain their own licenses; see [`LICENSE`](LICENSE).

No actuator addresses, operating modes, update frequencies, or compatibility claims are assumed by this scaffold.
