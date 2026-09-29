# SmartFusion2 Firmware

## Role and repository boundary

SmartFusion2 is intended to function as the motor controller and virtual DYNAMIXEL device for the Robot PC. It is not a transparent USB-to-DYNAMIXEL bridge. Firmware source is maintained in a separate repository and is not part of this ROS integration repository.

The intended data path is:

```text
Robot PC / DynamixelSDK
  -> USB CDC
  -> DYNAMIXEL Protocol 2.0 parser
  -> virtual-device Control Table
  -> motor-control logic
  -> stepper drivers
  -> BCN3D Moveo stepper motors
```

The actual USB behavior, control-table contract, driver hardware, and stepper interface remain to be implemented and tested.

## ARM and FPGA partition

The partition is a design hypothesis and must be confirmed against board resources, peripheral support, latency, throughput, and measured control requirements:

| Candidate responsibility | Candidate implementation | Status |
| --- | --- | --- |
| USB CDC and host packet handling | ARM | Proposed, board/peripheral verification required |
| Protocol parsing, register access, configuration, diagnostics | ARM | Proposed; protocol contract unverified |
| FPGA communication and supervisory logic | ARM | Proposed; interface not selected |
| Deterministic STEP/DIR generation and axis synchronization | FPGA | Candidate use; timing and architecture not measured |
| Encoder/input capture and high-rate loops | FPGA | Conditional on selected sensors and measured need |

Do not document this table as an implemented partition until the target board design and interfaces are known.

## Virtual DYNAMIXEL device

The firmware should implement only the Protocol 2.0 instructions, status responses, registers, modes, and state behavior actually required by the selected ROBOTIS host stack. Do not assume that exposing an XM430 model number or implementing its full Control Table is necessary or accurate.

Before firmware register behavior is fixed, analyze the exact Jazzy revisions of `dynamixel_hardware_interface`, DynamixelSDK, and the relevant OpenMANIPULATOR software. Record source revisions and verified findings in the [compatibility specification](../dynamixel/compatibility-spec.md). Keep unknown values explicitly marked as unknown and keep the firmware and ROS-side contract synchronized.

## Bring-up sequence

1. Confirm board USB CDC enumeration and host access.
2. Verify Protocol 2.0 framing and status/error behavior against the host implementation.
3. Test one virtual device with the required discovery and register operations.
4. Add only the verified command/state and torque behavior needed for a single axis.
5. Validate one stepper axis, including driver configuration, position scaling, limits, and any homing/feedback method.
6. Scale to the full Moveo only after one-axis behavior and stop/safety behavior are reviewed.

The firmware implementation and physical motor-control behavior are not validated by this repository's current ROS package scaffold.