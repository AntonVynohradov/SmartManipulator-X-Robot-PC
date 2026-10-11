# Development environment

The repository uses two separate environments:

| Environment | Runs where | Contains |
| --- | --- | --- |
| **Firmware** | Docker image (Dev Container, Compose, or CI) | Zephyr, west, Zephyr SDK with `arm-zephyr-eabi`, CMake, Ninja, ccache, and the DynamixelSDK host library |
| **Host tools** | Repository `.venv` on Windows or Linux | Python dependencies of `tools/dxl_test_gui` and of the documentation build (`requirements.txt`) |
| **FPGA / hardware** | Host only | Microchip Libero SoC and licenses: MSS, clocks, fabric, pins, programming |

Libero and Microchip licenses are never installed in the image or committed to
the repository.

## Repository layout

```text
.
├── apps/SmartManipulator_Controller/   Zephyr application (product firmware)
│   ├── boards/                         target overlay, _sim overlay, board .conf
│   ├── include/{dynamixel,motor,servo}/ public module headers
│   ├── src/                            main, transport, codec, XW430 and servo models,
│   │                                   motor workers and backends, servo output
│   ├── tests/protocol2_test.c          host unit tests for the codec
│   ├── prj.conf, prj_sim.conf, Kconfig, CMakeLists.txt
├── tools/dxl_test_gui/                 Protocol 2.0 motor tester (Python/Tkinter)
├── docs/                               this documentation (Markdown, built with MkDocs)
├── tools/docs/                         PDF build script, cover page, MkDocs hooks
├── mkdocs.yml                          documentation site and PDF configuration
├── .agents/skills/                     engineering rules for coding agents
├── .devcontainer/devcontainer.json     Dev Container (uses ../Dockerfile)
├── .vscode/                            tasks, workspace menu scripts, settings
├── Dockerfile, compose.yaml            firmware build image
├── west.yml                            Zephyr manifest (pinned revision)
├── requirements.txt                    host Python dependencies (.venv): GUI and documentation build
└── .gitattributes                      line-ending rules (LF; CRLF for .bat/.ps1)
```

Generated directories (`build/`, `.west/`, `.ccache/`, `.venv/`, `site/`, `zephyr/`
checkouts) are ignored and must not be committed.

## Pinned tool versions

| Component | Version |
| --- | --- |
| Zephyr (`west.yml`) | `v4.5.0-rc1` (first release with `m2s_hello_fpga_kit/m2s010`) |
| Base image | `python:3.12.15-slim-bookworm`, digest-pinned, `linux/amd64` |
| west | 1.4.0 |
| Zephyr SDK | 1.0.0 (ARM toolchain in `/opt/zephyr-sdk/gnu/arm-zephyr-eabi`) |
| CMake | 3.30.5 |
| ccache | 4.12.3 |
| jsonschema / pyelftools | 4.26.0 / 0.33 |
| DynamixelSDK (host library only) | 4.1.0, commit `f838bc90f72fcf5b9c279432d6e12fc24969daa8` |
| pyserial (`.venv`) | 3.5 |
| Image tag (`compose.yaml`) | `zephyr-sf2:1.0.0` |

Versions are `ARG`s in the `Dockerfile`. The SDK, ARM toolchain, and ccache
archives are verified by SHA-256. Do not use `latest` or a moving branch for
build-critical dependencies.

## Dev Container

1. Install Docker (with BuildKit) and the VS Code **Dev Containers**
   extension.
2. Open the repository and run **F1 → Dev Containers: Reopen in Container**.

`.devcontainer/devcontainer.json` builds the repository `Dockerfile` (the
single source of truth for tool versions). It mounts the repository at
`/workspace` and `.ccache/` at `/ccache`, sets `BOARD=m2s_hello_fpga_kit/m2s010`,
and installs the Zephyr IDE, C/C++, CMake, Cortex-Debug, and Serial Monitor
extensions. After you change the `Dockerfile` or build arguments, run
**Dev Containers: Rebuild Container**. Reopening the container does not update
the tools.

Check the toolchain inside the container:

```bash
west --version
arm-zephyr-eabi-gcc --version
cmake --version && ninja --version
```

## VS Code tasks

**Ctrl+Shift+B** opens **Zephyr: Workspace Menu**. Its options depend on the
operating system:

| OS | Action | Implementation |
| --- | --- | --- |
| Linux (Dev Container) | **Initialize + update**: `west init -l .` if needed, then `west update` | `.vscode/workspace-menu.sh` |
| | **Update dependencies**: initializes if needed, then `west update` | |
| | **Build firmware**: checks the workspace (`ensure-west-workspace.sh`), then `west build` | |
| | **Clean**: removes `build/`, `build-sim/`, `build-native/` | |
| | **Clean and Build**: pristine build (`-p always`) | |
| | **Build simulation firmware** / **Clean and Build simulation firmware**: `-d build-sim -- -DFILE_SUFFIX=sim` | |
| | **Run simulation on PC (native_sim)**: builds the simulation for `native_sim/native/64` and runs it; the UART is a `/dev/pts/N` | |
| Windows host | **Create .venv**: creates `.venv`, upgrades pip, installs `requirements.txt`, checks Tkinter | `.vscode/host-menu.ps1` |
| | **Run motor tester GUI** / **(simulator)**: creates `.venv` if needed, then starts `tools/dxl_test_gui` | |
| Linux and Windows | **Build PDF documentation**: sets up the docs tools if needed, then runs `tools/docs/build_pdf.py` (on Linux in a separate `.venv-linux` when `.venv` is a Windows environment) | both scripts |

Individual tasks are available under **Tasks: Run Task**: *Zephyr: Build*,
*Zephyr: Pristine Build*, *Zephyr: Build (simulation)* (all depend on *Zephyr: Ensure workspace*),
*Zephyr: Clean*, *Zephyr: Ccache Stats*, *Zephyr: Ccache Clear*, and
*Docs: Build PDF* (also under **Tasks: Run Build Task**). Keep shell
logic in the scripts under `.vscode/`, not inline in `tasks.json`.

## Building

```bash
# target firmware (TMC5160 over SPI)
west build -b m2s_hello_fpga_kit/m2s010 -s apps/SmartManipulator_Controller -d build
# simulation firmware (no motor hardware; prj_sim.conf + _sim overlay)
west build -b m2s_hello_fpga_kit/m2s010 -s apps/SmartManipulator_Controller -d build-sim -- -DFILE_SUFFIX=sim
# simulation firmware as a Linux executable (UART on a pseudo-terminal)
west build -b native_sim/native/64 -s apps/SmartManipulator_Controller -d build-native -- -DFILE_SUFFIX=sim
```

Use a separate build directory per variant. The variants are described in
[Firmware variants](../firmware/index.md#firmware-variants). Run these
commands from the workspace root. The root is a west workspace, and `-s`
selects the application. Make a **pristine build** after changes to
`prj.conf`, Kconfig, DeviceTree overlays, CMake files, the Zephyr version, or
the toolchain:

```bash
west build -p always -b m2s_hello_fpga_kit/m2s010 -s apps/SmartManipulator_Controller -d build
```

Zephyr picks the board overlay from `boards/` automatically:
`m2s_hello_fpga_kit_m2s010.overlay` for the target, and
`m2s_hello_fpga_kit_m2s010_sim.overlay` with `FILE_SUFFIX=sim`. Passing
`-DDTC_OVERLAY_FILE=...` replaces it; use `-DEXTRA_DTC_OVERLAY_FILE=...` to add
one.

### Build artifacts

| File | Use |
| --- | --- |
| `build/zephyr/zephyr.elf` | Debugging (symbols) |
| `build/zephyr/zephyr.hex` / `zephyr.bin` | Programming tools. Check the eNVM and hardware configuration first. |
| `build/compile_commands.json` | IntelliSense (`C_Cpp.default.compileCommands`) |

### ccache

The cache lives in `.ccache/` on the host and is mounted at `/ccache`, so it
survives container rebuilds. Use `ccache --show-stats` and `ccache --clear`,
or the matching VS Code tasks. The cache is only an optimization. If a build
behaves strangely, make a pristine build first.

## West and Zephyr

`west.yml` pins Zephyr `v4.5.0-rc1` and imports its modules. Run `west update`
after changing the manifest. Keep the revision pinned; never use `main`. A
change of the Zephyr version must be verified with a build, a pristine build,
the host tests, and a test on the kit.

## Host Python environment (.venv)

`requirements.txt` in the repository root lists the host dependencies:
`pyserial==3.5` for the GUI, and MkDocs, mkdocs-material,
mkdocs-print-site-plugin, Playwright and pypdf for the documentation. Tkinter
comes with Python and cannot be installed with pip.

```powershell
# Windows (PowerShell, repository root)
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

```bash
# Linux (repository root); first: sudo apt install python3-tk python3-venv
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
```

On Windows, the **Create .venv** menu action does the same.
`tools/dxl_test_gui/run_gui.bat` creates the environment on first use.

## Tests

| Test | Command | Where |
| --- | --- | --- |
| Firmware codec (C) | `gcc -std=c11 -Wall -Wextra -Werror -I include src/protocol2.c tests/protocol2_test.c -o /tmp/protocol2_test && /tmp/protocol2_test` in `apps/SmartManipulator_Controller` | Container or any gcc host |
| GUI codec, bus, simulator, and **firmware cross-check** | `python -m unittest discover -s tests -v` in `tools/dxl_test_gui` | `.venv` or the container |
| **Protocol conformance of the real firmware** | `python tools/dxl_test_gui/firmware_check.py --port <COMx or /dev/pts/N>` | Board with the simulation (or target) firmware; or `native_sim` in the container |

The cross-check compiles `src/protocol2.c` into a shared library. It verifies
that the firmware and the Python codec produce identical packets and that the
firmware parser accepts the Python packets. It is skipped when `gcc` is not
available.

`firmware_check.py` sends a fixed sequence of transactions and reports PASS or
FAIL per check:
- PING and broadcast PING, identity registers, and Realtime Tick;
- every error code;
- SYNC_READ, SYNC_WRITE, REG_WRITE, and ACTION;
- CRC and stuffing robustness;
- the gripper servo device, if the controller reports one (protocol, limits,
  ramp, SYNC_WRITE);
- on the simulation firmware only: position and velocity motion and telemetry.

It never moves motors on the target firmware unless `--allow-motion` is given.
To test the complete firmware stack without a board, inside the container:

```bash
west build -b native_sim/native/64 -s apps/SmartManipulator_Controller -d build-native -- -DFILE_SUFFIX=sim
build-native/zephyr/zephyr.exe &          # note the /dev/pts/N it prints
python3 tools/dxl_test_gui/firmware_check.py --port /dev/pts/N
```

This needs `pyserial` in the container Python; the image does not include it
(`pip install pyserial==3.5`). The motor backends have no
unit tests; `motor_tmc5160.c` must be tested on hardware.

## Documentation and PDF manual

The documentation is the Markdown in `docs/`. `mkdocs.yml` turns it into a
website and into a printable A4 manual with a cover page, a table of contents
with page numbers, numbered chapters, headings and figures, a running header,
and page numbers. The `print-site` plugin combines all pages into
`site/print_page/`, and `tools/docs/build_pdf.py` prints that page with
Chromium (through Playwright) and adds PDF bookmarks.

The docs tools are in `requirements.txt`, so the repository `.venv` of the
GUI has them. The **Build PDF documentation** menu action (or the
*Docs: Build PDF* task) does the steps below. By hand:

```powershell
# Windows (PowerShell, repository root)
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe tools\docs\build_pdf.py
```

```sh
# Linux (repository root)
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m playwright install chromium     # once; Windows uses Edge instead
.venv/bin/python tools/docs/build_pdf.py
```

The result is `site/SmartManipulator-X-Controller.pdf`. The cover shows the
`git describe` version and the build date.

| Command | Result |
| --- | --- |
| `python -m mkdocs serve` | Live HTML preview at <http://127.0.0.1:8000>; the combined print view is at `/print_page/` |
| `python -m mkdocs build` | Static website in `site/` (strict mode: a broken link or missing file fails the build) |
| `python tools/docs/build_pdf.py` | Runs `mkdocs build`, then writes the PDF |
| `... build_pdf.py --output manual.pdf` | Writes the PDF elsewhere |
| `... build_pdf.py --browser msedge` | Uses a specific browser: `chromium` (Playwright), `msedge`, or `chrome`. The default `auto` tries them in that order. |
| `... build_pdf.py --mermaid-js mermaid.min.js` | Offline build: serves a local Mermaid 11 script instead of loading it from unpkg.com |

Writing rules that keep the PDF correct:

- Start every page with exactly one `# Title`. Chapter and heading numbers are
  added automatically, so do not number headings by hand.
- A new page must also be added to `nav` in `mkdocs.yml`, otherwise it is
  missing from the site and the PDF.
- An image on a line of its own, `![Caption](images/file.png)`, becomes a
  numbered figure, and its alt text becomes the caption (`tools/docs/hooks.py`).
- Link to other pages with relative `.md` paths (`../gui/index.md#starting`);
  strict mode then checks them.
- Mermaid diagrams (` ```mermaid `) are rendered in the browser. Tall diagrams
  are scaled down to fit on one page.
- Print styling lives in `docs/assets/stylesheets/print.css`, and the cover page
  in `tools/docs/cover_page.tpl`.

MkDocs is pinned below 2.0, because MkDocs 2.0 removes the plugin system that
the theme and the PDF build depend on.

## Code style

`clang-format.txt` holds the formatting configuration (LLVM-based, with
embedded-systems customizations). clang-format looks for a file named `.clang-format`, so
either pass the file explicitly (`clang-format --style=file:clang-format.txt`)
or copy it to `.clang-format`.

## Line endings

`.gitattributes` makes every text file LF in the working tree, including on
Windows. The exceptions are `*.bat`, `*.cmd`, and `*.ps1`, which use CRLF. Bash
in the container fails on CRLF scripts (`$'\r': command not found`). If an old
clone still has CRLF files, commit your work and then run:

```bash
git rm -r --cached -q . && git reset --hard
```

## Docker without VS Code

```bash
docker build -t zephyr-sf2:1.0.0 .
docker run --rm -it -v "$PWD:/workspace" -v "$PWD/.ccache:/ccache" -w /workspace zephyr-sf2:1.0.0
# or, using compose.yaml (runs the default build):
docker compose run --rm zephyr
```

## Debugging

Debug with `zephyr.elf` through VS Code, Cortex-Debug, GDB, and a
SmartFusion2-compatible debug probe. The probe configuration depends on the
board setup and is not yet defined here. The host UART carries binary Protocol
2.0 traffic, so there is no text console. Use a debugger, or route diagnostics
to the spare `uart1` with an explicit DeviceTree and Kconfig change.

## Updating tool versions

1. Change the `ARG` in the `Dockerfile` (and its SHA-256 for downloaded
   archives).
2. Rebuild the image (`docker build --no-cache ...` or **Rebuild Container**).
3. Build, make a pristine build, and run the host tests.
4. Test on the M2S Hello FPGA Kit.
5. Bump the image tag and update the version tables (this page and the
   `zephyr-smartfusion2` skill).

## CI

CI should use the same `Dockerfile`: build the image, run `west update`, build
both variants (`build` and `build-sim`), and archive `zephyr.elf/.hex/.bin`.
Run the codec tests as well. Run the `native_sim` build together with
`firmware_check.py` as an end-to-end protocol test.
Persist `/ccache` through the CI cache. A firmware-only pipeline needs no
Libero and no Microchip licenses.

## Licenses and secrets

Never commit or bake into images: Microchip license files, license server
credentials, tokens, keys, or proprietary binaries. Keep Libero on the host.

## Troubleshooting

| Symptom | Fix |
| --- | --- |
| `$'\r': command not found` in a `.vscode/*.sh` task | CRLF line endings; see [Line endings](#line-endings) |
| `west: command not found` | Not inside the container; `which west` should print `/opt/venv/bin/west` |
| `source directory "." does not contain a CMakeLists.txt` | Add `-s apps/SmartManipulator_Controller`, or use the menu |
| `arm-zephyr-eabi-gcc: command not found` | `PATH` must contain `/opt/zephyr-sdk/gnu/arm-zephyr-eabi/bin`; rebuild the container |
| Strange build after `prj.conf` / overlay changes | Pristine build (`-p always`) |
| IntelliSense errors | Build once so `build/compile_commands.json` exists |
| ccache shows no hits | `echo $CCACHE_DIR` should print `/ccache`; check that `.ccache/` exists on the host |
| GUI: `No module named serial` | Use the `.venv` interpreter, or run **Create .venv** |
| GUI: `No module named tkinter` | Reinstall Python from python.org with Tcl/Tk, or `apt install python3-tk` |
| GUI: timeouts on every ID | Wrong COM port or baud rate (kit USB port: 460800; choose **Auto** to detect it), PIC32 not switched to UART (`&`, checkbox **PIC32 bridge**), board not powered, firmware not running, or the UART still has a text console |
