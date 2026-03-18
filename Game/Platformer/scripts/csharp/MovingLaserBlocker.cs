using Godot;
using System;

public partial class MovingLaserBlocker : AnimatableBody2D
{
    [Export] private Vector2 travelOffset = new(0f, -120f);
    [Export(PropertyHint.Range, "0.1,8,0.1")] private float cycleDuration = 2.2f;
    [Export] private Vector2 blockerSize = new(28f, 84f);
    [Export] private Color blockerColor = new(0.18f, 0.82f, 1f, 1f);

    private Vector2 _startPosition;

    public override void _Ready()
    {
        _startPosition = GlobalPosition;
        QueueRedraw();
    }

    public override void _PhysicsProcess(double delta)
    {
        if (cycleDuration <= 0.01f)
            return;

        double t = Time.GetTicksMsec() / 1000.0;
        float phase = Mathf.PingPong((float)(t / cycleDuration), 1f);
        GlobalPosition = _startPosition + travelOffset * phase;
    }

    public override void _Draw()
    {
        Rect2 rect = new Rect2(-blockerSize * 0.5f, blockerSize);
        DrawRect(rect, blockerColor);
        DrawRect(new Rect2(rect.Position + new Vector2(4f, 4f), rect.Size - new Vector2(8f, 8f)), blockerColor.Darkened(0.35f));
    }
}
