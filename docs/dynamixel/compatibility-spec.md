# SmartFusion2 DYNAMIXEL Compatibility Specification

**Status: unverified.** This is the shared contract for the Robot PC and the separate SmartFusion2 firmware. No register values, actuator identity, or drop-in compatibility claim is currently established. Keep unknowns explicit; do not infer XM430 behavior from the OpenMANIPULATOR-X product description.

## Scope

The target firmware is a virtual DYNAMIXEL device over USB CDC that controls stepper motors on the BCN3D Moveo mechanism. The preferred ROS path reuses ROBOTIS `dynamixel_hardware_interface` and DynamixelSDK if source analysis confirms compatibility. The SmartFusion2 is not intended to transparently forward USB packets to physical DYNAMIXEL actuators.

The ROBOTIS OpenMANIPULATOR-X source is a software-stack reference, not evidence that its stock actuator model, joint names, motion ranges, or register set fit the Moveo build.

## Sources to pin and inspect

For every finding, record the immutable commit or release, file path, and relevant symbol/line or documented section. Branch names such as `jazzy` can move and are not sufficient as reproducible evidence.

- [DynamixelSDK](https://github.com/ROBOTIS-GIT/DynamixelSDK)
- [dynamixel_hardware_interface](https://github.com/ROBOTIS-GIT/dynamixel_hardware_interface)
- [dynamixel_interfaces](https://github.com/ROBOTIS-GIT/dynamixel_interfaces)
- [OpenMANIPULATOR ROS 2](https://github.com/ROBOTIS-GIT/open_manipulator)
- Selected DYNAMIXEL model documentation and the actual SmartFusion2 USB/firmware implementation.

Inspect the host implementation rather than guessing from a model control-table PDF: identify the actual startup reads/writes, register widths and signedness, command/state interfaces, operating modes, packet instructions, status/error handling, retries, timeout behavior, and update loop. Confirm what behavior is meaningful for a stepper-driven Moveo joint.

## Evidence-backed device contract

Replace `Unverified` only when source or hardware evidence is recorded. If a requirement does not apply to the virtual stepper device, document why and how the host path handles it.

| Requirement | Verified value | Source revision and evidence |
| --- | --- | --- |
| Host package versions/commits | Unverified | Unverified |
| Host-requested actuator model and protocol | Unverified | Unverified |
| Device ID and discovery behavior | Unverified | Unverified |
| USB CDC framing, baud/line settings, and response timing | Unverified | Unverified |
| Protocol instructions actually used | Unverified | Unverified |
| Control Table addresses, widths, signedness, and access rules | Unverified | Unverified |
| Initialization and configuration sequence | Unverified | Unverified |
| Command interfaces and supported operating modes | Unverified | Unverified |
| State interfaces and measurement source | Unverified | Unverified |
| Torque/enable and fault behavior | Unverified | Unverified |
| Update rate, latency, retries, and timeouts | Unverified | Unverified |
| Moveo joint-to-device/motor mapping | Unverified | Unverified |
| Unmodified stock hardware-interface compatibility | Unverified | Unverified |

## Verification record

For each test, record hardware and firmware revisions, host OS/ROS distribution, exact source commits, configuration, command, expected result, and observed result. Distinguish protocol-level simulation from a physical stepper-axis test.

Minimum staged evidence:

1. Confirm the board enumerates as USB CDC and the Robot PC can open the device.
2. Verify Protocol 2.0 packet framing and status/error responses against the selected DynamixelSDK transport.
3. Test required device discovery and the precise read/write transactions observed in the hardware-interface source.
4. Verify initialization, state reporting, command updates, and timeout/failure behavior for one virtual actuator.
5. Validate one real stepper axis with its selected driver, scaling, limits, reference method, and stop behavior.

Do not claim full XM430 emulation or production readiness based only on successful packet exchange. A device model identifier, register behavior, mechanical mapping, and physical motion all require separate evidence.
