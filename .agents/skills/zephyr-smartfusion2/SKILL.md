---
name: zephyr-smartfusion2
description: "Use when changing the SmartManipulator-X Zephyr firmware for the Microchip SmartFusion2 M2S Hello FPGA Kit (M2S010, Cortex-M3): application architecture, threads and module APIs, Docker/Dev Container builds, west, ccache, DeviceTree, Kconfig, host unit tests, firmware artifacts, and the Libero hardware contract."
---

# Zephyr SmartFusion2 Development Skill

## Purpose

This skill defines the engineering rules and workflow for this repository.

The repository contains firmware for the:

* Microchip SmartFusion2 M2S010
* M2S Hello FPGA Kit
* ARM Cortex-M3
* Zephyr RTOS

The project uses Docker as the reproducible firmware build environment and
VS Code Dev Containers as the primary development environment.

Microchip Libero SoC is intentionally kept outside the Docker environment.

Sections 1-24 define the build environment and workflow rules. Sections
25-30 describe the current application architecture, concurrency model,
configuration, tests, the Libero hardware contract, and known gaps. Read
sections 25-30 before changing code under `apps/SmartManipulator_Controller`.

---

# 1. Repository Architecture

The project is split into two environments.

## Firmware environment

The Docker container is responsible for:

* Zephyr RTOS
* west
* Zephyr SDK
* ARM Cortex-M3 toolchain
* CMake
* Ninja
* ccache
* firmware compilation
* firmware artifacts

The expected flow is:

```text
Application
    |
    v
Zephyr RTOS
    |
    v
ARM Cortex-M3
    |
    v
ELF / HEX / BIN
```

## Hardware environment

Microchip Libero SoC is responsible for:

* SmartFusion2 MSS configuration
* clock configuration
* FPGA fabric
* pin configuration
* hardware generation
* FPGA-related artifacts

The expected separation is:

```text
Docker
  |
  +-- Zephyr firmware
  +-- ARM toolchain
  +-- ELF / HEX / BIN

Host
  |
  +-- Libero SoC
  +-- SmartFusion2 hardware project
  +-- Microchip licensing
```

Do not merge these environments unless explicitly requested.

---

# 2. Target Board

The default Zephyr target is:

```text
m2s_hello_fpga_kit/m2s010
```

Use this target for normal builds.

Example:

```bash
west build \
    -b m2s_hello_fpga_kit/m2s010 \
    -s apps/SmartManipulator_Controller \
    -d build
```

Run this command from the workspace root. The root is a west workspace, not a
Zephyr application; `-s` selects the product firmware.
`apps/SmartManipulator_Controller` is currently the only application in
`apps/`. The board examples mentioned in older documentation (`01_blink`,
`02_solution_i2c_driver`, `03_demo_spi_raw_cs1`) are not present in this
workspace; do not reference them as available.

Do not silently change the board target.

If a different board is requested, verify that the requested Zephyr board target exists before modifying build configuration.

---

# 3. Toolchain

The project targets:

```text
ARM Cortex-M3
```

The expected compiler is:

```text
arm-zephyr-eabi-gcc
```

The Zephyr SDK is installed under:

```text
/opt/zephyr-sdk
```

With Zephyr SDK 1.0.0, the ARM compiler is installed under:

```text
/opt/zephyr-sdk/gnu/arm-zephyr-eabi/bin
```

The production image downloads the SDK 1.0.0 minimal bundle and the ARM
toolchain as separate, SHA-256-verified archives. Extract the toolchain into
`/opt/zephyr-sdk/gnu`, then run `setup.sh -h -c` to install host tools and
register the CMake package. Do not extract the compiler at the SDK root; SDK 1.0
uses the `gnu/arm-zephyr-eabi` layout.

Do not introduce another ARM toolchain unless explicitly required.

Do not install unrelated Zephyr toolchains such as:

* RISC-V
* ARC
* Xtensa
* x86
* LLVM

unless the project requirements change.

---

# 4. Version Pinning

Reproducibility is a project requirement.

Important versions must be explicitly pinned.

The Dockerfile currently defines:

```text
WEST_VERSION
ZEPHYR_SDK_VERSION
DYNAMIXEL_SDK_VERSION
DYNAMIXEL_SDK_COMMIT
JSONSCHEMA_VERSION
CMAKE_VERSION
PYELFTOOLS_VERSION
CCACHE_VERSION
ZEPHYR_SDK_MINIMAL_SHA256
ZEPHYR_ARM_TOOLCHAIN_SHA256
CCACHE_SHA256
```

The Zephyr source revision must also be pinned in:

```text
west.yml
```

Do not replace a pinned revision with:

```text
main
```

or another moving branch unless explicitly requested.

Avoid:

```text
latest
```

for critical build dependencies.

The current compatible baseline is:

| Component | Version |
| --- | --- |
| Zephyr (`west.yml`) | `v4.5.0-rc1` |
| west | `1.4.0` |
| Zephyr SDK | `1.0.0` |
| Python | `3.12.15` |
| CMake | `3.30.5` |
| jsonschema | `4.26.0` |
| pyelftools | `0.33` |
| ccache | `4.12.3` |
| DynamixelSDK (host-side only) | `4.1.0`, commit `f838bc90f72fcf5b9c279432d6e12fc24969daa8` |
| Base image | `python:3.12.15-slim-bookworm`, digest-pinned, `linux/amd64` |
| Docker image tag (`compose.yaml`) | `zephyr-sf2:1.0.0` |

The Dockerfile builds the ROBOTIS DynamixelSDK C++ library from the pinned
tag into `/opt/dynamixel-sdk` and fails the build if the tag does not resolve
to `DYNAMIXEL_SDK_COMMIT`. It exists for native Linux reference tools and
protocol tests only; it cannot be linked into the ARM/Zephyr firmware.

The Dockerfile pins the Python base image by digest and verifies downloaded SDK
and ccache archives against their SHA-256 values. Keep the image platform and
downloaded toolchain architecture aligned (`linux/amd64` in this workspace).

The `m2s_hello_fpga_kit/m2s010` board was introduced in Zephyr 4.5. Keep the
manifest revision pinned to a Zephyr revision that contains this board. Zephyr
4.5's build scripts require Python 3.12 or newer and CMake 3.28 or newer;
Python 3.11 fails in `west build` because `pathlib.Path.relative_to()` does not
support `walk_up`. The `jsonschema` and `pyelftools` packages are also needed by
Zephyr's build scripts.

When updating a toolchain version:

1. update the version explicitly;
2. rebuild the Docker image;
3. build the firmware;
4. test the firmware;
5. verify the M2S Hello FPGA Kit;
6. document the change.

---

# 5. Docker Rules

The Dockerfile is the single source of truth for the firmware build environment.

VS Code Dev Containers must use the repository root Dockerfile.

Do not create a second independent toolchain installation inside:

```text
.devcontainer/
```

unless there is a specific reason.

The preferred architecture is:

```text
.devcontainer/devcontainer.json
        |
        v
../Dockerfile
```

This ensures that:

* local Docker builds,
* VS Code builds,
* CI builds

use the same environment.

Keep tool version defaults in the Dockerfile. Avoid duplicating them in
`devcontainer.json` under `build.args`; an override there can silently select an
incompatible SDK. If an override is necessary, keep it synchronized with the
Dockerfile. Changes to the Dockerfile or build arguments require rebuilding the
Dev Container; reopening it does not update the installed Python, CMake, or
SDK.

---

# 6. Docker Image Size

Keep the Docker image small.

Only install dependencies required for Zephyr firmware development.

Do not install:

* Libero SoC
* SoftConsole
* FPGA synthesis tools
* FPGA programming tools
* unrelated compiler toolchains
* GUI applications
* unnecessary development packages

The current base image is `python:3.12.15-slim-bookworm`, pinned by digest. It
is a slim Debian bookworm image that provides the Python 3.12 required by
Zephyr 4.5. Keep a digest-pinned, slim Debian-based image; do not switch to an
unpinned tag. The pinned DynamixelSDK (section 4) is the only non-Zephyr
library in the image.

Clean package-manager caches after installation.

---

# 7. Microchip Licenses

Microchip licenses must never be stored in:

* Git
* GitHub
* Docker images
* Dockerfiles
* CI artifacts
* `.devcontainer`
* project configuration
* public container registries

Do not add license server credentials to environment files committed to Git.

Do not attempt to install or configure Libero SoC inside the firmware container.

If a task requires Libero SoC, treat it as a host-side workflow.

---

# 8. ccache

The project uses:

```text
ccache
```

The cache directory is:

```text
/ccache
```

and should normally be persisted from the host:

```text
.ccache/
```

Do not commit `.ccache/`.

The cache is an optimization only.

Never rely on cached files for correctness.

If build behavior appears inconsistent, perform a pristine build before investigating further:

```bash
west build \
    -p always \
    -b m2s_hello_fpga_kit/m2s010 \
    -s apps/SmartManipulator_Controller \
    -d build
```

If necessary, clear the cache:

```bash
ccache --clear
```

---

# 9. Build Directory

Generated build output belongs in:

```text
build/
```

Do not commit the build directory.

A normal build is:

```bash
west build \
    -b m2s_hello_fpga_kit/m2s010 \
    -s apps/SmartManipulator_Controller \
    -d build
```

A pristine build is:

```bash
west build \
    -p always \
    -b m2s_hello_fpga_kit/m2s010 \
    -s apps/SmartManipulator_Controller \
    -d build
```

---

# 10. When to Use a Pristine Build

Recommend a pristine build after changes to:

* `prj.conf`
* Kconfig configuration
* DeviceTree overlays
* board configuration
* CMake configuration
* Zephyr version
* toolchain version

For ordinary C/C++ source changes, a normal incremental build is preferred.

---

# 11. DeviceTree

DeviceTree configuration is hardware-specific.

Before modifying a DeviceTree overlay:

1. inspect the existing board configuration;
2. identify the relevant peripheral;
3. preserve existing compatible nodes and aliases unless there is a reason to change them;
4. verify generated DeviceTree output after the build.

Do not invent peripheral addresses, interrupts, clocks, or pin mappings.

If hardware information is missing, ask for the relevant Libero/MSS configuration instead of guessing.

---

# 12. Kconfig

Application configuration belongs primarily in:

```text
prj.conf
```

Before adding a Kconfig option:

1. verify that the symbol exists in the selected Zephyr revision;
2. understand its dependencies;
3. avoid enabling unnecessary subsystems;
4. keep configuration minimal.

Do not copy large generic Zephyr configurations into `prj.conf`.

---

# 13. west

Use `west` for Zephyr workspace management.

Typical initialization:

```bash
west init -l .
west update
```

The VS Code **Zephyr: Workspace Menu** provides the same workflow:

* **Initialize + update** runs `west init -l .` only when no workspace exists,
    then runs `west update`.
* **Update dependencies** initializes the workspace if needed, then runs
    `west update`.
* **Build firmware** checks for a ready Zephyr checkout and fetches dependencies
    if needed before building.
* **Clean** removes `build/`, `build-sim/`, and `build-native/`.
* **Clean and Build** performs a pristine build with `west build -p always`.
* **Build simulation firmware** / **Clean and Build simulation firmware**
    build the simulation variant into `build-sim/` (`-- -DFILE_SUFFIX=sim`).
* **Run simulation on PC (native_sim)** builds the simulation variant for
    `native_sim/native/64` into `build-native/` and runs it (UART on a pty).

The menu logic is in `.vscode/workspace-menu.sh`; build preparation is in
`.vscode/ensure-west-workspace.sh`. Keep these scripts consistent with
`README.md` and `.vscode/tasks.json`.

The menu is OS-specific (`linux` / `windows` task properties with separate
`pickString` inputs). The West actions above appear only on Linux (Dev
Container); `zephyrAction` lists them. On a Windows host the menu offers only
**Create .venv**, **Run motor tester GUI**, and **Run motor tester GUI
(simulator)** (`hostAction`), implemented in `.vscode/host-menu.ps1`. That
script creates the repository `.venv` from the root `requirements.txt` and
starts `tools/dxl_test_gui`. Keep new West actions in `zephyrAction` and
`workspace-menu.sh`, and new host actions in `hostAction` and `host-menu.ps1`.

Use:

```bash
west build \
    -b m2s_hello_fpga_kit/m2s010 \
    -s apps/SmartManipulator_Controller \
    -d build
```

for firmware builds.

Do not replace the Zephyr build process with an unrelated CMake invocation unless required.

When changing Zephyr dependencies, update `west.yml` intentionally and verify the resulting dependency graph.

---

# 14. Build Artifacts

Important artifacts normally appear under:

```text
build/zephyr/
```

Expected artifacts include:

```text
zephyr.elf
zephyr.hex
zephyr.bin
```

Use:

```text
zephyr.elf
```

for debugging.

Use:

```text
zephyr.hex
zephyr.bin
```

when a programming workflow requires those formats.

Do not assume that HEX or BIN can be programmed directly into SmartFusion2 without considering the hardware/eNVM configuration.

---

# 15. Libero and Firmware Integration

Zephyr firmware and Libero hardware configuration are related but separate.

The firmware may depend on hardware assumptions such as:

* clock configuration
* peripheral availability
* memory layout
* MSS configuration
* interrupt routing
* pin configuration

If a firmware change requires hardware changes, clearly identify the dependency.

Do not silently modify Libero-related assumptions without evidence from the hardware design.

---

# 16. VS Code

The recommended development environment is:

```text
VS Code
    +
Dev Containers
    +
repository Dockerfile
```

The workspace should be mounted as:

```text
/workspace
```

The Zephyr SDK should already exist inside the container.

Do not install another Zephyr SDK through VS Code unless explicitly requested.

Keep shell logic in the scripts under `.vscode/` rather than embedding
multiline `bash -lc` commands in `tasks.json`. Use process tasks with separate
arguments to avoid shell-quoting errors and keep task output readable.

The **Zephyr: Build** and **Zephyr: Pristine Build** tasks must depend on
**Zephyr: Ensure workspace** so they prepare dependencies before calling
`west build`.

The defined tasks are: **Zephyr: Ensure workspace**, **Zephyr: Workspace
Menu**, **Zephyr: Build**, **Zephyr: Pristine Build**, **Zephyr: Clean**,
**Zephyr: Ccache Stats**, and **Zephyr: Ccache Clear**. The Dev Container sets
`BOARD=m2s_hello_fpga_kit/m2s010` and installs the Zephyr IDE, C/C++, CMake,
Cortex-Debug, and Serial Monitor extensions.

VS Code should use:

```text
build/compile_commands.json
```

for C/C++ IntelliSense when available.

---

# 17. CI/CD

CI should use the same Dockerfile as local development.

Preferred flow:

```text
Git
 |
 v
Docker image
 |
 v
west update
 |
 v
west build
 |
 +-- zephyr.elf
 +-- zephyr.hex
 +-- zephyr.bin
```

CI should not require Microchip Libero when the pipeline is only building Zephyr firmware.

Do not put Microchip license files into CI unless a separate hardware-generation pipeline explicitly requires them.

---

# 18. Safe Change Procedure

Before making significant changes:

1. inspect the existing repository structure;
2. inspect `Dockerfile`;
3. inspect `west.yml`;
4. inspect `prj.conf`;
5. inspect DeviceTree overlays;
6. determine whether the change affects only firmware or also hardware;
7. preserve version pinning;
8. make the smallest appropriate change;
9. perform a build;
10. perform a pristine build if configuration changed;
11. report any assumptions.

Do not rewrite configuration files unnecessarily.

---

# 19. Dependency Changes

When adding a dependency:

* prefer an existing system package;
* avoid unnecessary Python packages;
* pin Python dependencies where practical;
* avoid downloading arbitrary binaries;
* prefer official upstream release artifacts;
* verify checksums for critical downloaded toolchains;
* keep the Docker image reproducible.

Do not add network-dependent installation steps that are unnecessary at runtime.

---

# 20. Security

Never commit:

* passwords
* access tokens
* SSH private keys
* Microchip license files
* license server credentials
* proprietary binaries
* generated credentials

Use environment variables, secret managers, or host-side configuration when credentials are genuinely required.

Do not expose secrets through Docker image layers.

---

# 21. Troubleshooting Priority

When a build fails, use this order:

### 1. Check the board

```bash
west boards | grep m2s010
```

### 2. Check Zephyr

```bash
west --version
```

### 3. Check the compiler

```bash
arm-zephyr-eabi-gcc --version
```

### 4. Check the SDK

```bash
ls /opt/zephyr-sdk
```

### 5. Check the workspace

```bash
west list
```

### 6. Perform a pristine build

```bash
west build \
    -p always \
    -b m2s_hello_fpga_kit/m2s010 \
    -s apps/SmartManipulator_Controller \
    -d build
```

### 7. Inspect generated files

Check:

```text
build/zephyr/
build/compile_commands.json
```

Do not immediately change tool versions to solve a build problem.

---

# 22. Documentation

`README.md` is a short overview. Human documentation lives in `docs/`:

| Change | Update |
| --- | --- |
| Build environment, tools, VS Code tasks, `.venv`, tests | `docs/development/index.md` (and `docs/getting-started.md` when the steps change) |
| Modules, threads, queues, mutexes, start-up order, Control Table behavior | `docs/firmware/index.md` |
| Motor tester GUI | `docs/gui/index.md` |
| Pins, wiring, power | `docs/hardware/wiring.md`, `docs/hardware/images/hello-fpga-kit-wiring.svg`, `docs/hardware/images/system-wiring.png` (diagrams are drawn in Canva; the PNGs in the repo are exports or matching renders) |
| TMC5160 module setup, overlay values, TMC interface review, motor wiring | `docs/hardware/tmc5160.md`, `docs/hardware/images/tmc5160-axis-wiring.png`, `docs/hardware/images/motor-wiring.png` |
| Motor profiles, axis assignment (`include/motor/motor_profiles.h`, `motor_axes.h`) | current and axis tables in `docs/hardware/tmc5160.md` and `docs/hardware/wiring.md`; the GUI test `MotorConfigTest` |
| Manufacturer documents (new revision) | `docs/hardware/datasheets/` (unchanged PDFs) and the sources table in `docs/hardware/tmc5160.md` |
| New document | link it from `docs/index.md` |

When modifying agent/development rules, update:

```text
.agents/skills/zephyr-smartfusion2/SKILL.md
```

Keep `docs/` focused on human usage and this skill focused on engineering
rules and agent behavior. Do not duplicate the documentation here.

---

# 23. Definition of Done

A firmware change is considered complete when:

* the source compiles successfully;
* the host Protocol 2.0 tests (section 28) pass when `protocol2.c`,
  `protocol2.h`, or the tests changed;
* the correct board target is used;
* no unintended toolchain changes were introduced;
* `west` dependencies are consistent;
* configuration changes have been validated;
* a pristine build succeeds when required;
* generated artifacts are available;
* no secrets or licenses were added to the repository;
* documentation is updated when behavior or workflow changes.

For hardware-dependent changes, also validate the firmware on the M2S Hello FPGA Kit whenever hardware access is available.

---

# 24. Default Build Command

Unless the task explicitly requires another configuration, use:

```bash
west build \
    -b m2s_hello_fpga_kit/m2s010 \
    -s apps/SmartManipulator_Controller \
    -d build
```

The default architecture is:

```text
Microchip SmartFusion2 M2S010
        |
        v
ARM Cortex-M3
        |
        v
Zephyr RTOS
        |
        v
Zephyr SDK / arm-zephyr-eabi
```

The default development environment is:

```text
VS Code
   |
   v
Dev Container
   |
   v
Repository Dockerfile
```

The default hardware-development boundary is:

```text
Zephyr firmware -> Docker

Libero SoC       -> Host
Microchip license -> Host
```

Always preserve this separation unless the project requirements explicitly change.

---

# 25. Application Architecture

The product firmware is `apps/SmartManipulator_Controller`. Sources live in
`src/` with public headers in `include/<component>/`:

| Path | Responsibility |
| --- | --- |
| `src/main.c` | Starts the motor backend (`motor_init`), configures the virtual XW430 devices (IDs, scale and firmware version from Kconfig), and starts the host link. |
| `include/dynamixel/protocol2.h`, `src/protocol2.c` | Plain C11 Protocol 2.0 codec: CRC-16 (polynomial `0x8005`, initial value 0), incremental byte parser, and encoder with byte stuffing. |
| `include/dynamixel/communication.h`, `src/communication.c` | UART transport: RX interrupt, byte queue, `dxl_protocol2_rx` thread, packet callback, serialized TX, and diagnostic counters. |
| `include/dynamixel/x430.h`, `src/dynamixel_x430.c` | Virtual XW430-T333-R devices: Control Table, instruction handling, unit conversion, and status packets. |
| `include/motor/motor.h`, `src/motor_core.c` | Backend-independent motor API: six per-axis worker threads, bounded queues, one `motor_backend_mutex`. |
| `include/motor/motor_backend.h` | Backend interface (`motor_backend_init`, `motor_backend_execute`, `motor_backend_id`). |
| `include/motor/motor_profiles.h` | Motor data: one `MOTOR_<KEY>_<FIELD>` block per motor type (NAME, FRAME, RATED_MA, HOLDING_GCM, FULL_STEPS, IRUN, IHOLD, IHOLDDELAY, VSTART, A1, V1, AMAX, VMAX, DMAX, D1, VSTOP). Parsed by `tools/dxl_test_gui/dxl/motors.py`. |
| `include/motor/motor_axes.h` | `SMX_AXISn_MOTOR` / `_INVERT` / `_GEAR_NUM` / `_GEAR_DEN` (n = 0-5), `SMX_MICROSTEPS`, `SMX_AXIS_MOTOR_FIELD(n, FIELD)`. Included by the target overlay and `main.c`. |
| `src/motor_tmc5160.c` | Target backend: binds `tmc5160_axis<N>_driver/_controller` and calls Zephyr `stepper` / `stepper_ctrl`. Raw SPI helpers for IOIN (probe), DRV_STATUS.stst (Moving) and CHOPCONF (TOFF 3 after enable). Telemetry returns `-ENOTSUP`. |
| `src/motor_sim.c` | Simulation backend: ramp-generator model per axis plus telemetry (velocity, current, PWM, voltage, temperature). |
| `Kconfig` | `SMX_MOTOR_BACKEND` choice (TMC5160 / SIM), `SMX_FIRMWARE_VERSION` (1 / 129), `SMX_MICROSTEPS_PER_OUTPUT_REVOLUTION` (0 = per axis from `motor_axes.h` / 3200), `SMX_SIM_*`. |
| `prj.conf`, `boards/m2s_hello_fpga_kit_m2s010.overlay` | Target variant: SPI, stepper, six `adi,tmc51xx` devices on `spi0`; per-axis values from `motor_axes.h`, common `SMX_TMC5160_*` values. |
| `prj_sim.conf`, `boards/m2s_hello_fpga_kit_m2s010_sim.overlay` | Simulation variant (`-DFILE_SUFFIX=sim`): no SPI devices. |
| `tests/protocol2_test.c` | Host unit tests for the codec. |

`protocol2.c` must stay free of Zephyr headers so it can be compiled and tested
with plain `gcc` on the host.

The app `README.md` describes a target module
split (`transport/`, `protocol/`, `device/`, `motor/`, `fpga/`). The code does
not use those directories yet. The current mapping is:

| Target module | Current implementation |
| --- | --- |
| `transport` | `communication.c` |
| `protocol` | `protocol2.c` |
| `device` | `dynamixel_x430.c` |
| `motor` | `motor_core.c` + `motor_tmc5160.c` / `motor_sim.c` |
| `fpga` | Not implemented |

Add new files to the existing `src/` and `include/<component>/` layout and list
them in `CMakeLists.txt` (`target_sources`, or `target_sources_ifdef` for
backend-specific files). Do not restructure into module directories unless
that is requested.

## Firmware variants

There are two build variants of the same application. Keep them building:

| Variant | Command | Use |
| --- | --- | --- |
| Target | `west build -b m2s_hello_fpga_kit/m2s010 -s apps/SmartManipulator_Controller -d build` | Robot arm with six TMC5160 |
| Simulation | `west build -b m2s_hello_fpga_kit/m2s010 -s apps/SmartManipulator_Controller -d build-sim -- -DFILE_SUFFIX=sim` | Protocol test on the board without motors |
| Simulation on PC | `west build -b native_sim/native/64 -s apps/SmartManipulator_Controller -d build-native -- -DFILE_SUFFIX=sim` | End-to-end test; UART on `/dev/pts/N` |

Rules:

* Everything above the backend (transport, codec, Control Table, threads) is
  shared. Never add `#ifdef CONFIG_SMX_MOTOR_BACKEND_*` to
  `dynamixel_x430.c`. Express capability differences through backend return
  codes (for example `-ENOTSUP` → Access Error).
* A new motor operation needs an entry in `enum motor_operation`, the range
  check in `motor_submit_async`, and handling in **both** backends.
* After a change, build all three variants. Run
  `tools/dxl_test_gui/firmware_check.py` against the `native_sim` executable
  (it must stay at 33/33 or more), and keep `tools/dxl_test_gui/dxl/sim.py` in
  step with the firmware behavior.
* The simulation firmware reports Firmware Version 129 (bit 7). Do not reuse
  bit 7 for anything else.
* Detection: axes answer only while `MOTOR_OPERATION_PROBE` reports their
  driver as present. The controller device (`SMX_CONTROLLER_ID`, default 200)
  always answers. Keep both behaviors and the Model Information layout (driver
  / motor frame / current) in step with `tools/dxl_test_gui/dxl/sim.py` and
  `dxl/control_table.py`. `firmware_check.py` must stay at 33/33 on
  `native_sim`.
* Motor data lives **only** in `include/motor/motor_profiles.h`; axis
  assignment only in `motor_axes.h`. Keep the plain
  `#define MOTOR_<KEY>_<FIELD> value` and `#define SMX_AXISn_<FIELD> value`
  format (no expressions): the GUI parses it to name motors and to flag a
  mismatch with the Model Information the board reports. Run the GUI tests
  (`MotorConfigTest`) after a change.
* `motor_tmc5160.c` reads `IOIN` with its own `spi_dt_spec` under
  `motor_backend_mutex`. This is safe only while the upstream driver does no
  asynchronous SPI (no event callback, no DIAG0 interrupt). Revisit it if
  stepper event callbacks are enabled.

## Initialization order

`main()` runs these steps in order. Keep this order:

1. `motor_init()` runs `motor_backend_init()` under the backend mutex. The
   TMC5160 backend fails with `-ENODEV` if a DeviceTree stepper device is not
   ready; the simulation backend resets its models. `motor_init()` then starts
   the six workers.
2. `dynamixel_x430_init()` sets up the virtual devices. Its configuration must
   use `protocol_type == 2` and a `baud_rate` (`DXL_HOST_BAUDRATE`, from the
   devicetree `current-speed`) that has a Baud Rate code, and IDs must be unique
   and at most 252.
3. `dxl_comm_init()` runs last, so no packet is dispatched before the device
   model is ready.

Any failure returns the error code from `main()` without printing anything,
because the console UART is binary. Debug startup failures with a debugger and
`zephyr.elf`.

---

# 26. Concurrency Model

| Thread | Priority | Stack | Queue |
| --- | --- | --- | --- |
| `dxl_protocol2_rx` | `K_PRIO_PREEMPT(5)` | 2048 B | `rx_byte_queue`: 512 x 1 byte |
| `motor_axis_worker` (x6) | `K_PRIO_PREEMPT(6)` | 1536 B each | 8 commands per axis |

Rules:

* The UART ISR only copies FIFO bytes into `rx_byte_queue`. Bytes that do not
  fit are dropped and counted in `dxl_comm_rx_overruns()`. Do not parse or
  dispatch in the ISR.
* The packet handler (`dynamixel_x430_handle_packet`) runs in the
  `dxl_protocol2_rx` thread. The packet pointer is valid only during the
  callback.
* `dynamixel_x430` calls the motor layer synchronously: `x430_motor_call()` submits
  a command and waits on a semaphore with `K_FOREVER`. While it waits, incoming
  bytes accumulate in the 512-byte RX queue. Keep motor operations short. Do
  not add more blocking work to the packet path. Consider a bounded timeout if
  long operations are introduced.
* `motor_submit_async()` enqueues with `K_NO_WAIT`. A full per-axis queue
  returns a negative errno (`-ENOMSG` from `k_msgq_put`), and the caller must
  handle it.
* All six TMC5160 devices share `spi0`. `motor_backend_mutex`
  (`motor_core.c`) serializes every backend call, in both variants. Never call
  `stepper_*` or `stepper_ctrl_*` functions, or SPI directly, outside
  `motor_tmc5160.c`. Backends need no locks of their own.
* The simulation backend integrates its model lazily, up to 2000 substeps per
  call, under the backend mutex. Keep the per-call cost bounded.
* TX (`dxl_comm_send_packet`) encodes into a stack buffer and sends it with
  `uart_poll_out()` under `tx_mutex`. Before each status packet the device
  busy-waits `Return Delay Time x 2 us` (default 250, so 500 us) in the RX
  thread.
* Health counters: `dxl_comm_rx_overruns()` counts dropped RX bytes and
  `dxl_comm_invalid_packets()` counts CRC or framing rejects. Nothing reports
  them yet.

When changing priorities, stack sizes, or queue depths, verify the stack usage
(for example with `CONFIG_THREAD_ANALYZER` in a debug build) and document the
reason.

---

# 27. Kconfig and DeviceTree Specifics

`prj.conf` (target) and `prj_sim.conf` (simulation) are deliberately minimal:

| Option | Reason |
| --- | --- |
| `CONFIG_SERIAL=y`, `CONFIG_UART_INTERRUPT_DRIVEN=y` | Needed for the interrupt-driven RX path |
| `CONFIG_SPI=y`, `CONFIG_STEPPER=y` | Target only: needed for the upstream `adi,tmc51xx` driver and stepper API (`SMX_MOTOR_BACKEND_TMC5160` depends on them) |
| `CONFIG_SMX_MOTOR_BACKEND_TMC5160=y` / `CONFIG_SMX_MOTOR_BACKEND_SIM=y` | Selects the backend |
| `CONFIG_UART_CONSOLE=n`, `CONFIG_PRINTK=n`, `CONFIG_BOOT_BANNER=n`, `CONFIG_EARLY_CONSOLE=n` | The console UART carries binary Protocol 2.0. Any text corrupts framing. |

Do not enable logging, `printk`, or the shell on the host UART. If diagnostics
are needed, route them to another interface, such as the spare `uart1` from the
Libero contract (section 29), with an explicit DeviceTree and Kconfig change.

DeviceTree rules for this application:

* The host UART is `DT_CHOSEN(zephyr_console)`. A `BUILD_ASSERT` requires it
  to be `okay`. The board DTS selects `uart0` (MMUART_0). Do not hard-code
  `uart0`.
* Zephyr picks the board overlay from `boards/` automatically:
  `m2s_hello_fpga_kit_m2s010.overlay` (target), or
  `m2s_hello_fpga_kit_m2s010_sim.overlay` with `FILE_SUFFIX=sim`. Passing
  `-DDTC_OVERLAY_FILE=...` replaces it. Use `-DEXTRA_DTC_OVERLAY_FILE=...` to
  add one.
* `motor_tmc5160.c` references the node labels `tmc5160_axis<N>_driver` and
  `tmc5160_axis<N>_controller` (N = 0-5) through `DT_NODELABEL`. Renaming them
  requires updating that file.
* Each `adi,tmc51xx` node has `reg = <N>`, which is the SPI_0 chip select SSN.
  It has a `stepper-driver-N` child (`adi,tmc51xx-stepper-driver`) and a
  `motion-controller-N` child (`adi,tmc51xx-stepper-ctrl`).
* The overlay includes `../include/motor/motor_axes.h`. Per-axis `irun`,
  `ihold`, `iholddelay`, ramp (`vstart`, `a1`, `v1`, `amax`, `vmax`, `dmax`,
  `d1`, `vstop`), `micro-step-res` and `shaft` come from
  `SMX_AXIS_MOTOR_FIELD(n, FIELD)` / `SMX_AXISn_INVERT`. Ramp units at 12 MHz
  and 16 microsteps: 1 rev/s = VMAX 4474, 1 rev/s² = AMAX 49; V1 = 0 disables
  A1/D1 but D1 must be ≥ 1; VSTOP ≥ VSTART.
* `SMX_TMC5160_SPI_HZ` (2 MHz), `SMX_TMC5160_CLOCK_HZ` (12 MHz), and
  `SMX_TMC5160_TCOOLTHRS` (0) are set from the datasheets and verified by SPI
  detection on hardware. Values, from the manufacturer documents in
  `docs/hardware/datasheets/` (details: `docs/hardware/tmc5160.md`):
  * `spi-max-frequency = <2000000>`. The MSS SPI driver (`spi_mchp_mss.c`)
    searches CLK_GEN only from 1 to 15, so any request below PCLK/30 =
    1.67 MHz falls back to CLK_GEN = 0 and runs SCK at **25 MHz**. Valid
    range: 1.67-4 MHz (TMC5160 limit with the internal clock is 4 MHz).
  * `clock-frequency = <12000000>`: CLK is tied to GND, so the internal
    12 MHz oscillator (11.5-12.5 MHz) is used.
  * `tcoolthrs = <0>` until StallGuard2 is tuned: the pinned `adi,tmc51xx`
    driver sets `SW_MODE.sg_stop = 1` at init regardless of
    `activate-stallguard2`, and the firmware never clears it.
  * `irun`/`ihold` per axis: I_RMS = (CS + 1) x 0.0958 A with the BTT module's
    0.075 ohm sense resistor and GLOBALSCALER = 0 (3.06 A RMS full scale).
    Profile values (about 85 % / 50 % of rated): 17HS19-2504S 21/12,
    23HS2430 26/15, 17HS19-1684S-PG5 14/8 (gearbox 57/11 on axis 3),
    17HS13-0404S1 3/1, 14HS20-1504S 12/7.
  * `SMX_AXIS2_INVERT 1` (adds `shaft;` to `tmc5160_axis2`) once the mechanics
    confirm that A1b mirrors A1a.

  Make a pristine build afterwards.

---

# 28. Host Unit Tests

The Protocol 2.0 codec has host tests covering the ROBOTIS PING reference
packet, a byte-stuffing round trip, CRC rejection, and malformed-stuffing
rejection. Run them in the container from `apps/SmartManipulator_Controller`:

```sh
gcc -std=c11 -Wall -Wextra -Werror -I include src/protocol2.c tests/protocol2_test.c -o /tmp/protocol2_test
/tmp/protocol2_test
```

`tools/dxl_test_gui` is a host-side Python/Tkinter tester for the firmware
over the host UART (Protocol 2.0 master, register browser, raw packets,
motion tests, and a simulator of the six virtual devices). Its tests
(`python -m unittest discover -s tests` in that folder) compile `protocol2.c`
with gcc and cross-check both codecs. When the firmware's instruction set,
register rules, or error codes change, update `tools/dxl_test_gui/dxl/sim.py`
and `dxl/control_table.py` to match.

`tools/dxl_test_gui/firmware_check.py --port <port>` is the protocol
conformance test for the real firmware. Run it against the simulation firmware
on the board, or against the `native_sim` build (`build-native/zephyr/zephyr.exe`
prints its `/dev/pts/N`). It needs `pyserial`. On the target firmware it runs
protocol checks only, unless `--allow-motion` is given.

Add a test for every codec behavior change. `motor_tmc5160.c` has no automated
test and must be validated on hardware. Do not claim it is tested.

---

# 29. Libero Hardware Contract

The hardware contract is defined in the Libero repository
(`SmartManipulator-X-Libero/docs/firmware_interface.md`, stage 2 robot-arm
pinout). Status at the time of writing: built 2026-10-08, timing met, 19/19 I/Os
locked. On hardware (2026-10-10): MMUART_0 host link at 230400 bps and SPI_0
with SS0 to a TMC5160 work; CS1-CS5, CorePWM, and LEDs are not tested yet. The Libero design is the authority for
hardware facts. If this table and the Libero document disagree, re-read the
Libero document and resynchronize this table.

Last cross-check: 2026-10-09, Libero project vs. this firmware (clocks, pins, SPI chip
selects, CorePWM address, LEDs). Result: consistent. MSS clocks in Libero
(`component/work/zephyr_sb_MSS/sys_config_mss_clocks.h`: M3 100 MHz, APB_0/1 50 MHz,
FIC_0 100 MHz) must stay equal to the board DTS (`cpu` 100 MHz, `mss-peripheral` 50 MHz);
if either side changes, update the other and the MMUART fractional divisor in
`communication.c`.

| MSS peripheral | Use | Kit pins |
| --- | --- | --- |
| MMUART_0 (`uart0`) | Host link (DYNAMIXEL Protocol 2.0) via PIC32 and MCP2221A USB | H12 TX / H13 RX |
| MMUART_1 (`uart1`) | Spare UART, 3.3 V USB-UART cable | Arduino D1 TX (G3) / D0 RX (F3) |
| SPI_0 (`spi0`) | 6x TMC5160, SPI mode 3, max 2 MHz | SCK D13, MOSI D11, MISO D12 |
| SPI_0 SS0-SS5 | Chip selects, DeviceTree `reg = <0>`-`<5>` | D10, D8, D7, D6, D5, D4 |
| GPIO_0-2 | LED1-LED3 | T12, T13, G13 |
| I2C_0 | Reserved (encoders / INA226) | Arduino SDA/SCL |

CorePWM (gripper servo) in the FPGA fabric:

* Base address `0x5000_0000` (FIC_0, CoreAPB3 slot 0; System Builder also
  lists the alias `0x3000_0000`). CorePWM v4.1.106, 1 channel, 16-bit APB data,
  shadow registers enabled, PCLK = 100 MHz.
* Servo setup: `PRESCALE` (0x00) = 99 for a 1 us tick, `PERIOD` (0x04) = 19999
  for 20 ms / 50 Hz, `PWM_ENABLE_0_7` (0x08) bit 0 = 1, `PWM1_POSEDGE` (0x10)
  = 0, `PWM1_NEGEDGE` (0x14) = 1000-2000 for a 1-2 ms pulse. Write 1 to
  `SYNC_UPDATE` (0xE4) after updating edges.
* Output: PWM channel 1 on Arduino D3 (N7).

Firmware status for this contract:

* Used: `uart0` (host link), `spi0` with SS0-SS5 (TMC5160), and CorePWM
  channel 1 (gripper servo, raw MMIO in `src/servo_corepwm.c`; the pinned
  Zephyr has no CorePWM driver). The servo is a virtual DYNAMIXEL device on
  ID 7 (`src/dynamixel_servo.c`, Kconfig `SMX_SERVO_*`); its output is not
  tested on hardware yet.
* Not used yet: GPIO LEDs, `uart1`, and I2C_0.
* SPI mode 3 is set by the upstream `adi,tmc51xx` driver itself
  (`SPI_MODE_CPOL | SPI_MODE_CPHA` in `tmc51xx.c`), so the overlay does not
  need it.

Driver modules and kit, from the manufacturer documents
(`docs/hardware/datasheets/`, checked 2026-10-10; the PDFs are the authority
for these facts):

* Reference module (schematic and manual in `docs/hardware/datasheets/`):
  **BIGTREETECH TMC5160 V1.0** (TMC5160-WA, R_SENSE 0.075 ohm, VM 8-40 V,
  3.1 A RMS / 4.4 A peak). Headers: J3 = EN, SDI, SCK, CSN, SDO, CLK, STEP,
  DIR; J4 = VM, GND, A2, A1, B1, B2, VCC_IO, GND.
* Modules actually fitted: **BTT TMC5160T Pro** (VM 8-56 V, R_SENSE 0.075 ohm,
  same current table). Logic header identical; power header VM, GND, A2, A1,
  **B2, B1**, VIO, GND. First hardware SPI test passed 2026-10-10 (axis A0
  detected, VERSION 0x30) with SPI 2 MHz and CLK/EN/STEP/DIR tied off; a
  floating CLK or the old 1 MHz (= 25 MHz SCK) setting prevents detection.
* Motor 17HS19-2504S (datasheet): connector pin 1 BLK A+ -> A1, 2 GRN A- ->
  A2, 3 RED B+ -> B1, 4 BLU B- -> B2. Coil A = black/green, coil B =
  red/blue. Reverse direction with `shaft` or by swapping one coil's two
  wires, never by mixing coils. Never plug a motor while VM is on.
  Figure: `docs/hardware/images/motor-wiring.png`.
* V1.0 only: pad **SPI** (W2) closed and pad **SD** (W1) open, otherwise the
  chip does not answer on SPI or ignores ramp commands. On both modules EN,
  CLK, STEP and DIR must be tied to GND (no pull resistors; the TMC5160 has no
  pull-down on CLK).
* TMC5160 SPI: mode 3, 40-bit datagrams, MSB first, address bit 7 = write; a
  read returns the data of the previous datagram. SDO is tristate while CSN is
  high. `IOIN.VERSION` = 0x30 for TMC5160 and TMC5160A.
* The TMC5160 logic is supplied from VM (VCC_IO only sets the I/O level). If
  VM comes after the kit or drops, the chip restarts with reset values
  (GSTAT.reset = 1) and the overlay configuration is lost.
* Kit: 3V3 on J9-4 comes from an MCP1727 LDO fed by USB 5 V. The Arduino nets
  and balls in the table above match the Hello FPGA schematics Rev. 1. The
  MSS SPI_0 and MMUART_0 pads are wired to the PIC32, so SPI_0 must be routed
  through the fabric (as the Libero design does). Host link: USB -> MCP2221A ->
  PIC32 (UART2 -> UART4) -> SF2 H12/H13.
* Before writing raw MMIO for CorePWM, check whether the pinned Zephyr revision
  provides a CorePWM driver or binding. Any fabric address used in firmware must
  come from the Libero memory map, not from guesses.
* Building the Libero design on a new machine: the IP cores (CoreAPB3 4.1.100,
  CorePWM 4.1.106, CoreResetP 7.1.100) must be complete in the local Libero vault.
  An incomplete CoreAPB3 vault entry makes Libero record `"CoreAPB3::COREAPB3_LIB",""`
  in `Zephyr.prjx` and synthesis fails with `CG389 Reference to undefined module
  CoreAPB3`; fix it by re-downloading the core in the Catalog and rebuilding the
  hierarchy (Libero README, Troubleshooting). The eNVM client must use the
  repository-relative `firmware/zephyr.hex`, never a personal absolute path.

---

# 30. Known Gaps

Do not assume these features exist:

* In the target firmware, the position scale is per axis from `motor_axes.h`
  with gear 1:1 (3200 microsteps per motor revolution). Gear ratios, joint
  limits and homing are not entered yet.
* Control Table writes are volatile. Nothing persists across reset.
* Bulk Read/Write, Fast Sync/Bulk Read, Reboot, Clear, Factory Reset, and
  Backup are not implemented.
* `SYNC_WRITE` dispatches axes one after another. It is not
  hardware-synchronized motion.
* In the target firmware, telemetry (Hardware Error Status 70, Present PWM,
  Current, and Velocity, the Trajectories, Input Voltage, and Temperature) is
  not available through the public TMC API and returns Access Error. Only the
  simulation firmware provides it.
* There is no diagnostics channel. The health counters are not exported.
* `docs/architecture`, `docs/robot-pc`, `docs/operator-pc`, `docs/mechanical`,
  and `docs/dynamixel` describe the whole system and are
  shared with the Robot PC repository. For this workspace, `docs/getting-started.md`,
  `docs/development`, `docs/firmware`, `docs/gui`, `docs/hardware`, and the
  source code are authoritative.
* `SMX_AXIS2_INVERT` is still 0 (no `shaft` on axis 2). Never lower
  `SMX_TMC5160_SPI_HZ` below 1.67 MHz (section 27).
* Replies to READ 122 (Moving) through the driver's `stepper_ctrl_is_moving()`
  arrived only after the next host packet on the hardware (cause unknown).
  The backend now reads `DRV_STATUS.stst` over raw SPI instead; confirm on
  hardware.
* The firmware does not check GSTAT.reset and does not rewrite a driver's
  configuration after a VM power-up or dropout. Until it does, the 24 V
  supply must be switched on before the kit.
* `stepper_enable()` in the pinned driver sets CHOPCONF.TOFF = 15 (low chopper
  frequency, audible squeal). `tmc_enable()` in `motor_tmc5160.c` rewrites the
  chopper bits to `0x000100C3` (TOFF 3) right after it; keep that if the
  driver is updated.
* `mss_spi_disable_ints()` in the pinned MSS SPI driver inverts its mask; the
  SCK idle level between transfers is not guaranteed. Check it with a logic
  analyser during bring-up.
* SPI detection of one TMC5160T Pro is verified on hardware (2026-10-10). No
  motor motion test or host conformance test (DynamixelSDK /
  `dynamixel_hardware_interface`) has been performed.
