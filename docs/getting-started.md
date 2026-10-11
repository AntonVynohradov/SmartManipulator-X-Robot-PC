# Getting started

This guide takes you from a fresh clone to a built firmware image and a
running motor tester. The [development environment](development/index.md) page
has details and troubleshooting.

## Prerequisites

| Where | What |
| --- | --- |
| Host (Windows or Linux) | Git, Docker Desktop / Docker Engine with BuildKit, VS Code with the **Dev Containers** extension |
| Host, for the GUI | Python 3.9+ with Tkinter (the python.org installer on Windows; `python3-tk python3-venv` on Ubuntu) |
| Host, for the FPGA design | Microchip Libero SoC with its license, outside Docker |
| Hardware | M2S Hello FPGA Kit, USB Mini-B cable, and for motion: six TMC5160 modules, motors, and a 24 V supply ([wiring](hardware/wiring.md)) |

The firmware toolchain (Zephyr SDK, west, CMake, Ninja, ccache) comes from
the repository `Dockerfile`. Do not install it on the host.

## Clone

```bash
git clone <repository-url> SmartManipulator-X-Controller
cd SmartManipulator-X-Controller
```

The repository has a `.gitattributes` file, so shell scripts keep LF line
endings on Windows too. If you cloned before it was added, see
[Line endings](development/index.md#line-endings).

## Open the Dev Container

1. Open the folder in VS Code.
2. Press **F1** and run **Dev Containers: Reopen in Container**.

The first start builds the image `Dockerfile`, which takes several minutes. The
repository is mounted at `/workspace` and the compiler cache at `/ccache`.

## Fetch Zephyr and build

Press **Ctrl+Shift+B** to open the **Zephyr: Workspace Menu**:

1. **Initialize + update** runs `west init -l .` and `west update`. Do this
   once; it downloads Zephyr `v4.5.0-rc1`.
2. Pick the firmware variant:
   - **Build simulation firmware** builds into `build-sim/`. It needs no
     motors or drivers, and every axis is simulated in the firmware. **Start
     with this one** to check the board, the USB/UART link, and the protocol.
   - **Build firmware** builds the target firmware into `build/`. It drives the
     six TMC5160 modules over SPI.

The same steps from the container terminal:

```bash
west init -l .        # first time only
west update
west build -b m2s_hello_fpga_kit/m2s010 -s apps/SmartManipulator_Controller -d build-sim -- -DFILE_SUFFIX=sim
west build -b m2s_hello_fpga_kit/m2s010 -s apps/SmartManipulator_Controller -d build
```

The images are written to `build-sim/zephyr/` and `build/zephyr/`
(`zephyr.elf`, `zephyr.hex`, `zephyr.bin`). The
[firmware variants](firmware/index.md#firmware-variants) table compares the two.

## Program the board

The SmartFusion2 hardware design (MSS, clocks, fabric, pins) comes from the
Libero project, and the Libero tools program it on the host. Load the Zephyr
image into the configured design with your Microchip programming or debug
setup. Use `zephyr.elf` for debugging. This repository does not yet define a
scripted programming workflow.

## Test the axes with the GUI (on the host)

On **Windows** in VS Code, outside the container, press **Ctrl+Shift+B** and
choose:

- **Create .venv**: creates `.venv` and installs `requirements.txt`. Do this
  once.
- **Run motor tester GUI**: starts the GUI with the board.
- **Run motor tester GUI (simulator)**: starts it without hardware.

From a terminal instead:

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe tools\dxl_test_gui\dxl_gui.py          # add --sim without hardware
```

```bash
python3 -m venv .venv && .venv/bin/python -m pip install -r requirements.txt
.venv/bin/python tools/dxl_test_gui/dxl_gui.py
```

Select the kit's COM port (`/dev/ttyACM0` on Linux), keep 460800 bps (or choose
**Auto**) and **PIC32 bridge (&)** ticked (the kit's PIC32 forwards data only
after `&`, see [Host link](hardware/wiring.md#host-link-usb-pic32-smartfusion2)), and click
**Connect**. The tool pings IDs 1-6, the controller and the gripper servo (ID 7). With the simulation firmware, the device
list shows **SIM · <motor>** for every axis (for example `SIM · 17HS19-2504S`),
the axes move in the simulation, and the telemetry (velocity, current,
voltage, temperature) is filled in. See the
[GUI guide](gui/index.md) for a complete per-axis test.

To run the automated protocol check (49 checks with the simulation firmware;
protocol-only on the target firmware):

```powershell
.\.venv\Scripts\python.exe tools\dxl_test_gui\firmware_check.py --port COM5
```

> **Safety:** the motor currents and ramps come from the motor profiles
> (`include/motor/motor_profiles.h`), the motor of each axis from
> `include/motor/motor_axes.h`. Before you drive a motor, check that the
> profile on its axis matches the motor that is actually connected (see
> [Motor profiles and axis assignment](hardware/tmc5160.md#motor-profiles-and-axis-assignment)),
> and wire the motor with VM off as shown in
> [Motor connection](hardware/tmc5160.md#motor-connection-17hs19-2504s).

## Next steps

- Read the [firmware architecture](firmware/index.md) before changing code.
- Run the protocol unit tests after codec changes. The commands are in
  [Tests](development/index.md#tests).
- Agent and engineering rules for this workspace are in
  `.agents/skills/zephyr-smartfusion2/SKILL.md`.
