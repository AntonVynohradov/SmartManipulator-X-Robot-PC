---
name: smartfusion2
description: "Use when working on the SmartFusion2 Zephyr firmware, ARM/FPGA partitioning, host UART/USB transport, DYNAMIXEL Protocol 2.0 emulation, or the virtual actuator Control Table."
---

# SmartFusion2 Firmware

## Governing Architecture

This file extends the [main SmartManipulator-X architecture](../smartfusion2-openmanipulator/SKILL.md). Read and follow that architecture before changing firmware contracts. This Zephyr workspace is the firmware implementation; the ROS integration and shared compatibility specification are maintained separately and must stay synchronized with it.

Keep firmware implementation in this Zephyr workspace, not in the SmartManipulator-X ROS integration repository. The ROS-side compatibility specification is maintained at `docs/dynamixel/compatibility-spec.md` in that repository.

Use the [Zephyr SmartFusion2 development skill](../zephyr-smartfusion2/SKILL.md) as the source of truth for this workspace's board target, application source path, toolchain versions, SDK installation, and container rebuild requirements.

## Firmware responsibilities

The SmartFusion2 functionally replaces the DYNAMIXEL controllers/actuators used by OpenMANIPULATOR-X. It is a controller implementing virtual DYNAMIXEL device behavior, not a USB-to-DYNAMIXEL bridge.

The firmware data path is:

```text
Host serial transport (UART for board bring-up; USB CDC if selected for deployment)
  -> DYNAMIXEL Protocol 2.0 parser
  -> virtual DYNAMIXEL Control Table
  -> motor control
  -> stepper motors
```

Use the board's `zephyr,console` chosen node for UART bring-up rather than hardcoding a UART node label. A UART connected through a USB-to-UART adapter is not necessarily USB CDC and may enumerate under a different host device name. Confirm the physical interface and host driver before documenting deployment behavior.

The console UART may also carry shell commands, logs, and `printk` output. Do not send binary DYNAMIXEL packets over that same stream until those outputs are disabled or moved to another interface; otherwise diagnostic text corrupts protocol framing.

Transport as currently built: the firmware uses `uart0` (MMUART_0, the board's `zephyr,console`) at 230400 bps for binary traffic only (the PC port runs at 460800 bps to the kit's PIC32, which forwards to MMUART_0 at 230400 bps once the host has sent `&`). The rate is the devicetree `current-speed` of `uart0` in both application overlays (`include/dynamixel/host_link.h` reads it); because the ns16550 driver sets only the integer divisor (-3.1 % at 50 MHz PCLK), `communication.c` reprograms the SmartFusion2 MMUART fractional divisor (DLR/DMR + DFR/64, MM0.EFBR) to 13 + 36/64 at 230400 (+0.006 %) before RX is enabled, and a `BUILD_ASSERT` rejects any rate with more than 0.5 % error. Console, `printk`, boot banner, and early console are disabled in `prj.conf`. Per the Libero contract, MMUART_0 reaches the host through the kit's PIC32 and MCP2221A USB bridge. The host therefore sees a USB serial device, but the SmartFusion2 itself does not implement USB CDC. Confirm the host device name (for example `/dev/ttyACM*`) on the Robot PC before documenting it. The spare `uart1` is the candidate diagnostics port.

## ARM and FPGA partition

The exact partition is to be designed from board capabilities and measured timing requirements. As a starting point:

- ARM: host serial transport, protocol processing, configuration, diagnostics, FPGA communication, and higher-level control logic.
- FPGA: deterministic STEP/DIR generation, encoder interfaces, high-rate control loops, and axis synchronization where needed.

Do not commit to this partition until device peripherals, throughput, latency, and control-loop requirements are verified.

As built today (Libero stage 2, wiring Rev. D, checked 2026-10-09): the TMC5160 drivers run in motion-controller mode over SPI, so the fabric contains no STEP/DIR or encoder logic. It only routes the MSS peripherals (MMUART_0/1, SPI_0 SS0-SS5, GPIO_0-2, I2C_0) to the kit pins and hosts CorePWM for the gripper servo at `0x5000_0000`. Pins and addresses: Libero `docs/firmware_interface.md` and the zephyr-smartfusion2 skill, section 29.

## DYNAMIXEL compatibility

Implement functional compatibility with the verified OpenMANIPULATOR-X, `ros2_control`, DynamixelSDK, and ROBOTIS hardware-interface requirements. Do not attempt to reproduce the entire XM430 Control Table by default.

Before implementing register behavior, use current upstream source and documentation to verify:

- Required model identifiers and Control Table addresses, widths, access rules, and defaults.
- Operating modes and torque behavior.
- Required Protocol 2.0 instructions and status/error responses.
- Position, velocity, and current command/state behavior.
- Update frequencies, latency limits, and timeouts.
- Whether the unmodified ROBOTIS hardware interface supports the virtual device.

Keep the compatibility specification synchronized with firmware behavior. Unknown values must remain explicitly unverified; do not invent register addresses or advertise untested XM430 compatibility.

## Current implementation: virtual XW430-T333-R

The firmware currently emulates six ROBOTIS XW430-T333-R devices (model number 1270). This is an implementation choice that has not yet been verified against the host stack. Record it in the compatibility specification together with its evidence; do not describe it as drop-in compatibility. Details live in `apps/SmartManipulator_Controller/src/dynamixel_x430.c` and the app `README.md`.

Identity and defaults:

| Item | Value |
| --- | --- |
| IDs | 1-6 (default), mapped to TMC axes 0-5; 7 = gripper servo (`SMX_SERVO_ID`, model 0x5356); unique, at most 252; broadcast ID `0xFE` |
| Firmware version / Protocol Type / Baud Rate code | 1 target, 129 simulation (bit 7) / 2 / 23 (230400 bps, the firmware UART; project code, the ROBOTIS X table has none for 230400 or 460800 = 46; only the current code is accepted on write) |
| Operating Mode default | 3 (position). Modes 1 (velocity), 3, and 4 (extended position) are accepted, and only with torque off. Current and PWM modes are rejected. |
| Status Return Level default | 2. Broadcast requests are answered only for `PING` and `SYNC_READ`. |
| Return Delay Time default | 250 (500 us busy-wait before each status packet) |
| Moving Threshold default | 10 |

Instructions: `PING`, `READ`, `WRITE`, `REG_WRITE` (at most 4 data bytes), `ACTION`, `SYNC_READ`, and `SYNC_WRITE`. Any other instruction returns Instruction Error (0x02).

Writable registers (a write must start at the register address and match its width exactly): ID 7, Baud Rate 8, Return Delay Time 9, Drive Mode 10 (bits 0 and 3 only), Operating Mode 11, Homing Offset 20, Moving Threshold 24, Current Limit 38 (motor run current = TMC5160 IRUN, 2.69 mA units, up to the rated current, read back rounded to the driver's 1/32 steps), Velocity Limit 44 (0-1023, default MAX_RPM of the motor profile), Torque Enable 64, LED 65, Status Return Level 68, Goal Velocity 104 (mode 1 only, |v| <= Velocity Limit), Profile Acceleration 108 (<= 32767, 0 = motor profile AMAX), Profile Velocity 112 (<= Velocity Limit, 0 = Velocity Limit), and Goal Position 116 (0-4095 in mode 3, +/-1048575 in mode 4). Drive Mode, Operating Mode, Homing Offset, Current Limit and Velocity Limit are written with torque off only (Access Error otherwise).

Readable registers also include Model Number 0, Firmware Version 6, Secondary ID 12, Protocol Type 13, the limit registers 31-52, Startup Configuration 60, Shutdown 63, Registered Instruction 69, Goal Velocity 104, Realtime Tick 120 (milliseconds, wraps at 32767), Moving 122, Moving Status 123, and Present Position 132.

Telemetry registers come from the backend's `MOTOR_OPERATION_GET_TELEMETRY`: Hardware Error Status 70, Present PWM 124 (885 = 100 %), Present Current 126 (2.69 mA), Present Velocity 128, Velocity Trajectory 136, Position Trajectory 140, Present Input Voltage 144 (0.1 V), and Present Temperature 146. The simulation firmware models them. The TMC5160 target firmware reads them over SPI: VACTUAL, XTARGET/VMAX, CS_ACTUAL (current setting in use, not a measurement), DRV_STATUS and GSTAT error flags; PWM is 0, supply voltage (`CONFIG_SMX_MOTOR_SUPPLY_MV`) and temperature (25 °C, 120/150 °C on otpw/ot) are nominal. Hardware Error Status is latched until the next Torque Enable = 1; bit 0 also reports a TMC5160 reset after a VM interruption (the firmware rewrites the configuration, switches torque off and the position restarts at 0).

Detection (DYNAMIXEL-conformant: a missing device does not answer):

- Each axis is probed with `MOTOR_OPERATION_PROBE` at start-up, on every PING, and on a READ of controller register 2. TMC5160: `IOIN.VERSION == 0x30` over SPI. Simulation: `SMX_SIM_ABSENT_AXIS_MASK`.
- An axis without a detected driver sends no status packets at all. It is also skipped in SYNC and broadcast instructions.
- Model Information (address 2–5) of each axis holds: detected driver (0x30 TMC5160, 0xFE simulated), configured motor frame (14/17/23, bit 7 = gearbox), and configured rated current in 10 mA units. The motor values come from the profile assigned to the axis in `apps/SmartManipulator_Controller/include/motor/motor_axes.h` (data in `motor_profiles.h`); the GUI names the motor from the same headers and warns on a mismatch.
- The controller device on `SMX_CONTROLLER_ID` (default 200, model 0x5358) always answers PING and READ 0–7. Register 2 holds the detected-axis mask, 3 the axis count, 4 the backend, 6 the firmware version, 7 the ID. Writes return Access Error. An axis ID may not be set to the controller ID.
- The TMC5160 logic is powered from VM, so no driver is detected without the 24 V supply.

Firmware variants: the **target** firmware (`motor_tmc5160.c`) and the **simulation** firmware (`motor_sim.c`, `-DFILE_SUFFIX=sim`) share this whole device model; only the motor backend differs. Validate protocol changes on the simulation firmware with `tools/dxl_test_gui/firmware_check.py` first.

Error mapping from Zephyr errno to the status error byte: `-EINVAL` gives Data Range (0x04), `-EMSGSIZE` gives Data Length (0x05), `-ENOTSUP`/`-ENODEV`/`-EACCES` give Access (0x07), and anything else gives Result Fail (0x01).

Motion semantics:

- Position scale: `motor = (dxl - homing_offset) x microsteps_per_rev / 4096`, rounded to the nearest step and negated when Drive Mode bit 0 is set. `microsteps_per_rev` comes from `CONFIG_SMX_MICROSTEPS_PER_OUTPUT_REVOLUTION`: 0 in the target firmware, which means per axis from `include/motor/motor_axes.h` (full steps x 16 x gear, 3200 at 1:1); 3200 in the simulation firmware. Before torque on in mode 3 the counter is shifted by whole output revolutions so that the unwrapped Present Position lies in 0-4095 (no unwinding of earlier turns). Torque off stops the ramp generator at once before the power stage is switched off.
- Velocity unit 0.229 rpm: `speed = v x 229 x microsteps_per_rev / 60000` microsteps/s. Acceleration unit 214.577 rev/min^2: `accel = a x 214577 x microsteps_per_rev / 3600000`. A ramp is applied only when Profile Acceleration and Profile Velocity are non-zero.
- Torque Enable 0 stops the axis, then disables the driver. Torque Enable 1 enables the driver and re-applies the stored goal. A Goal write with torque off is stored only, unless Drive Mode bit 3 (torque on by goal update) is set.
- `SYNC_WRITE` is sequential, not synchronized.

When changing any of these behaviors, update this section, the app `README.md`, and the compatibility specification together.

## Bring-up sequence

Current status: steps 1-3 are verified against the simulation firmware running as `native_sim` (`firmware_check.py`, 49/49 checks, including the gripper servo on ID 7). On the board, the target firmware answers PING/READ over the host link at 230400 bps. Steps 2-4 are implemented in firmware but not validated on hardware. On hardware, one TMC5160T Pro (axis A0) is detected over SPI (2026-10-10); no motor has been driven yet. Currents and ramps come from the motor profiles; SPI 2 MHz, clock 12 MHz and TCOOLTHRS 0 are set from the datasheets (see the zephyr-smartfusion2 skill, section 27).

Hardware prerequisites before step 4 (from the manufacturer documents in `docs/hardware/datasheets/`; checklist in `docs/hardware/tmc5160.md`):

- BTT TMC5160T Pro modules (or BTT TMC5160 V1.0: pad SPI closed, pad SD open): EN, CLK, STEP, DIR tied to GND; VIO/VCC_IO from kit J9-4 (3.3 V). SPI detection on axis A0 verified on hardware 2026-10-10.
- Motor wiring by pin name, not position (TMC5160T Pro power header is A2, A1, B2, B1): 17HS19-2504S black A+ → A1, green A− → A2, red B+ → B1, blue B− → B2. Never plug a motor while VM is on.
- An electrolytic capacitor at VM/GND of every module (datasheet: at least 100 uF per ampere of coil current).
- Overlay: SPI 2 MHz, clock 12 MHz, `tcoolthrs = 0`, per-axis `irun`/`ihold` and ramps from `motor_axes.h` (done); `SMX_AXIS2_INVERT` for axis 2 (open).
- Switch on 24 V before the kit; restart the kit after any VM interruption. Then every axis must report driver 0x30 (Detect motors in the GUI) before Torque ON.


1. Validate Protocol 2.0 framing, checksums, and status responses against the verified host implementation.
2. Test `PING`, `READ`, and `WRITE` with one virtual actuator.
3. Add only the verified torque and goal/present state behavior needed for one motor.
4. Validate one stepper axis, then scale to the full robot.
