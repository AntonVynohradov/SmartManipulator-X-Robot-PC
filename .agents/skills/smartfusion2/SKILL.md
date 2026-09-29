---
name: smartfusion2
description: "Use when working on the separate SmartFusion2 firmware repository, ARM/FPGA partitioning, USB CDC, DYNAMIXEL Protocol 2.0 emulation, or the virtual actuator Control Table."
---

# SmartFusion2 Firmware

## Governing Architecture

This file extends the [main SmartManipulator-X architecture](../smartfusion2-openmanipulator/SKILL.md). Read and follow that architecture before changing firmware contracts; this ROS repository's compatibility specification is shared across the repository boundary.

SmartFusion2 firmware is maintained in a separate repository. Do not create firmware implementation files in the SmartManipulator-X ROS repository. This repository owns ROS integration and the shared compatibility specification at `docs/dynamixel/compatibility-spec.md`.

## Firmware responsibilities

The SmartFusion2 functionally replaces the DYNAMIXEL controllers/actuators used by OpenMANIPULATOR-X. It is a controller implementing virtual DYNAMIXEL device behavior, not a USB-to-DYNAMIXEL bridge.

The intended firmware data path is:

```text
USB CDC
  -> DYNAMIXEL Protocol 2.0 parser
  -> virtual DYNAMIXEL Control Table
  -> motor control
  -> stepper motors
```

The device should enumerate to the Robot PC as a USB CDC interface, typically `/dev/ttyACM0`, and receive packets from the ROS/DynamixelSDK host over that connection.

## ARM and FPGA partition

The exact partition is to be designed from board capabilities and measured timing requirements. As a starting point:

- ARM: USB CDC, protocol processing, configuration, diagnostics, FPGA communication, and higher-level control logic.
- FPGA: deterministic STEP/DIR generation, encoder interfaces, high-rate control loops, and axis synchronization where needed.

Do not commit to this partition until device peripherals, throughput, latency, and control-loop requirements are verified.

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

## Bring-up sequence

1. Validate Protocol 2.0 framing, checksums, and status responses against the verified host implementation.
2. Test `PING`, `READ`, and `WRITE` with one virtual actuator.
3. Add only the verified torque and goal/present state behavior needed for one motor.
4. Validate one stepper axis, then scale to the full robot.
