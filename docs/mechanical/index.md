# BCN3D Moveo Mechanics

## Mechanical source

The target arm mechanics are based on the [BCN3D Moveo project](https://github.com/BCN3D/BCN3D-Moveo), not on the OpenMANIPULATOR-X geometry. The upstream repository provides CAD files, STL files, assembly/user documentation, a bill of materials, and original firmware. Its README describes an educational, additively manufactured arm controlled by Arduino-based electronics.

This project replaces/adapts the control electronics; it does not claim that the original Moveo firmware or electronics are part of the SmartFusion2 control path. Refer to the upstream repository and its license for the authoritative mechanical files, assembly details, and attribution requirements.

## ROS model integration

The intended home for the project-owned ROS model is:

```text
ros2_ws/src/smartmanipulator_x/smartmanipulator_x_description/
```

That package currently contains only empty placeholders. No Moveo URDF/Xacro, meshes, joint definitions, kinematic parameters, or ROS visualization configuration have been integrated or validated yet.

When integrating the model:

- Use BCN3D Moveo geometry and assembly as the mechanical source of truth.
- Record the source revision and any project-specific changes to CAD/STL-derived geometry.
- Establish the base frame, link frames, joint axes, zero positions, and units from the source design and assembled robot.
- Verify joint ranges and collision geometry against the physical arm; do not inherit OpenMANIPULATOR-X limits or joint names.
- Define and document each Moveo joint-to-stepper mapping, transmission, microstepping, homing/reference method, and position scaling only after the hardware is selected and measured.
- Keep MoveIt planning groups, `ros2_control` joints, Gazebo joints, and physical motor mapping consistent.
- Preserve upstream license and attribution notices for imported or adapted assets. Do not assume that the project repository's license changes third-party asset licensing.

The exact axis count, joint naming, dimensions, limits, stepper specifications, driver model, and sensing approach remain to be verified for the selected mechanical build. They are deliberately not inferred here from the project name.

## Acceptance checks

Before a model is treated as the canonical robot description, validate that it parses in URDF/Xacro tooling, has a connected link tree and correct joint types/axes, and produces a useful RViz visualization. Compare each joint range and frame placement with the assembled Moveo. Then check that the same joint contract can be loaded by both the physical `ros2_control` configuration and the selected Gazebo integration.