# Development Guide

Work is split across this ROS integration repository, a separate Operator PC repository, and a separate SmartFusion2 firmware repository. Keep the interfaces between them documented and verified; do not treat a scaffold, a successful compile, or an upstream branch name as proof of working hardware compatibility.

## Development prerequisites

- Git and a checkout of this repository.
- Docker Engine and the Docker Compose plugin for building/running the Robot PC image. The physical USB workflow targets Ubuntu 24.04 Linux.
- Python 3 with the `venv` module for building or previewing this documentation site.
- Network access during the first Docker image build so `vcs`, `rosdep`, and package managers can retrieve dependencies.
- For physical Robot PC runs, a SmartFusion2 board connected to the Linux host as USB CDC, typically `/dev/ttyACM0`, with appropriate host permissions.

## Documentation environment

Keep documentation tools isolated in the repository-local `.venv`. Do not install the MkDocs requirements into the system Python environment.

Run these commands in a shell that has not sourced a ROS environment. If `PYTHONPATH` is set by a ROS/Pixi environment, clear it in this documentation shell first so external ROS packages do not leak into the virtual environment.

### Windows PowerShell

```powershell
Remove-Item Env:PYTHONPATH -ErrorAction SilentlyContinue
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install --upgrade pip
.\.venv\Scripts\python.exe -m pip install -r requirements-docs.txt
.\.venv\Scripts\python.exe -m mkdocs serve
```

Open the local URL printed by MkDocs. For a production-style check, replace `serve` in the final command above with `build --strict`. The commands call the virtual-environment interpreter directly, so PowerShell activation is not required.

### Ubuntu / Linux Bash

On Ubuntu, install the venv support package if needed (`sudo apt install python3-venv`). Then run:

```bash
unset PYTHONPATH
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install -r requirements-docs.txt
python -m mkdocs serve
```

Use `python -m mkdocs build --strict` to check the site. Run `deactivate` to leave the environment. The `.venv/` directory is local and must not be committed.

## Build the Robot PC image

Run these commands from the repository root. Building the image does not require the SmartFusion2 board to be connected:

```bash
docker compose -f docker/docker-compose.yml build
```

The Compose build uses the repository root as its context. The Dockerfile installs ROS 2 Jazzy and build dependencies, imports the Robot PC repositories from `ros2_robot.repos`, copies the project packages into the image, and runs `rosdep` and `colcon build`. The result is tagged `smartmanipulator-x-robot:jazzy`.

The upstream manifest currently tracks `jazzy` branches, which may move. For repeatable development, review and pin immutable revisions before relying on a particular image. Rebuild after changing source files, manifests, or Docker configuration: the Compose service does not mount the host source tree into the container.

## Use the image

### Software development without hardware

After building the image, start its default shell without the USB mapping:

```bash
docker run --rm -it smartmanipulator-x-robot:jazzy
```

The entrypoint sources ROS Jazzy and the built workspace. The default command is Bash. Inspect the available project and DYNAMIXEL packages with:

```bash
ros2 pkg list | grep -E '^(dynamixel_sdk|dynamixel_interfaces|dynamixel_hardware_interface|smartmanipulator_x_)'
```

Changes made only inside this temporary container are discarded when it exits. Make source changes in the host checkout, rebuild the image, and start a new container to test them.

### Robot PC with SmartFusion2

The hardware workflow requires Ubuntu 24.04 Linux with Docker Engine. Connect the board and check that it appears on the host:

```bash
lsusb
ls -l /dev/ttyACM0
```

Ensure the host user and container can access the serial device. If the board uses another `/dev/ttyACM*` path, update the device mapping in `docker/docker-compose.yml`. Then run:

```bash
docker compose -f docker/docker-compose.yml run --rm smartmanipulator_x
```

This starts an interactive shell with `/dev/ttyACM0` passed into the container. Type `exit` to stop it; `--rm` removes the temporary container. Docker Desktop on Windows does not expose a Linux `/dev/ttyACM0` device through this configuration, so use the Linux Robot PC for physical hardware access.

The image contains the Robot PC ROS/control dependencies only. MoveIt 2, RViz2, Gazebo, and Operator PC workflows belong to the separate Operator PC environment. The current project bringup and controller configuration are scaffolds; building or entering the image does not validate motion or SmartFusion2 compatibility.

## Development roadmap

1. **Freeze inputs and boundaries.** Record the BCN3D Moveo mechanical source revision and applicable asset license. Verify the required ROS 2 Jazzy upstream repositories and pin immutable commits or tags for reproducible builds. Keep firmware and Operator PC implementations in their designated repositories.
2. **Establish the Moveo model.** Integrate the Moveo geometry into `smartmanipulator_x_description`. Verify frames, joint types and axes, joint limits, collision geometry, and the assembled robot. Define measured joint-to-stepper mappings and required driver/sensor hardware; do not reuse OpenMANIPULATOR-X joint configuration by assumption.
3. **Verify the host contract.** Inspect the pinned ROBOTIS `dynamixel_hardware_interface`, DynamixelSDK, and relevant OpenMANIPULATOR ROS 2 sources. Record required Protocol 2.0 operations, register accesses, command/state interfaces, operating modes, initialization, timing, and failure behavior in `../dynamixel/compatibility-spec.md`.
4. **Validate the ROS stack without SmartFusion2.** Build the Robot PC workspace and validate the selected OpenMANIPULATOR software components and the project Moveo description independently. Select controller names, joint names, update rates, and parameter schemas from verified sources and the Moveo model.
5. **Implement and test one virtual actuator.** In the separate firmware repository, implement USB CDC and the minimum verified DYNAMIXEL-device behavior. Test framing, device discovery, required reads/writes, status/error responses, and timeout behavior against the actual host implementation.
6. **Bring up one physical axis.** Confirm the stepper driver, electrical limits, reference/homing method, position conversion, travel limits, and stop behavior. Test small motions at conservative settings before scaling out.
7. **Integrate the complete robot and simulation.** Validate all Moveo axes, controller switching and state reporting. Configure Gazebo in the Operator PC repository using the same robot description and joint semantics as hardware.
8. **Validate two-computer operation.** Configure ROS 2 DDS domain/network settings and verify planning/execution from Operator PC to Robot PC without routing the USB device to the Operator PC.

## Current repository state

- The Robot PC Docker profile and ROS package scaffolds exist. The Docker profile is not evidence of successful physical operation.
- The project robot-description package has empty URDF and mesh placeholders. No Moveo model is integrated yet.
- `hardware.yaml` is a template; `controllers.yaml` has no controller parameters. A physical launch configuration and plugin selection are not complete.
- SmartFusion2 firmware and the Operator PC application are outside this repository.
- DYNAMIXEL compatibility values remain unverified; the compatibility table must not be filled with inferred XM430 values.

## Validation boundaries

Use `.venv`'s Python to run `python -m mkdocs build --strict` for documentation changes and the Docker image build to verify that the Robot PC workspace compiles. Hardware-in-the-loop checks must be performed on the actual target host and board; they cannot be inferred from a documentation build or container compile. Follow the staged roadmap before enabling motion.
