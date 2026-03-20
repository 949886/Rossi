// Created by Copilot on 2026-03-10.
// Example: Integrating VirtualJoystick with a 2D CharacterBody2D.

using Godot;
using VirtualJoystickPlugin;

/// <summary>
/// Example showing how to integrate the VirtualJoystick with a CharacterBody2D.
/// This demonstrates two approaches:
///   1. Input Action mapping (recommended) - joystick feeds into Godot Input system
///   2. Direct Output reading - read joystick.Output directly
/// </summary>
public partial class JoystickCharacterExample : CharacterBody2D
{
    [Export] public float MoveSpeed { get; set; } = 200f;
    [Export] public float Acceleration { get; set; } = 1000f;
    [Export] public float Friction { get; set; } = 800f;
    [Export] public float JumpVelocity { get; set; } = -350f;
    [Export] public float Gravity { get; set; } = 980f;

    /// <summary>
    /// Optional: Direct reference to a VirtualJoystick node.
    /// If null, the character uses standard Input actions (which the joystick can feed into).
    /// </summary>
    [Export] public VirtualJoystick Joystick { get; set; }

    public override void _PhysicsProcess(double delta)
    {
        float dt = (float)delta;
        var vel = Velocity;

        // --- Gravity ---
        if (!IsOnFloor())
        {
            vel.Y += Gravity * dt;
        }

        // --- Horizontal Movement ---
        // Approach 1: Use standard Input API (works with both keyboard AND joystick via Action mapping)
        float inputX = Input.GetAxis("move_left", "move_right");

        // Approach 2 (alternative): Read directly from joystick
        // Uncomment the following line and comment out the above if you prefer direct reading:
        // float inputX = Joystick?.Output.X ?? Input.GetAxis("move_left", "move_right");

        if (Mathf.Abs(inputX) > 0.01f)
        {
            vel.X = Mathf.MoveToward(vel.X, inputX * MoveSpeed, Acceleration * dt);
        }
        else
        {
            vel.X = Mathf.MoveToward(vel.X, 0, Friction * dt);
        }

        // --- Jump ---
        if (Input.IsActionJustPressed("jump") && IsOnFloor())
        {
            vel.Y = JumpVelocity;
        }

        Velocity = vel;
        MoveAndSlide();
    }
}
