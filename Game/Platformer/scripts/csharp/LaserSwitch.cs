using Godot;
using System.Collections.Generic;

public partial class LaserSwitch : Node2D
{
    [Export] private NodePath interactionAreaPath = "InteractionArea";
    [Export] private NodePath[] targetLaserPaths = new NodePath[0];
    [Export] private string interactAction = "interact";
    [Export] private string promptText = "Press F";
    [Export] private Vector2 promptOffset = new(0f, -42f);
    [Export] private Vector2 switchSize = new(20f, 30f);
    [Export] private Color activeColor = new(0.3f, 1f, 0.5f, 1f);
    [Export] private Color inactiveColor = new(0.9f, 0.25f, 0.25f, 1f);

    private readonly List<LaserBeam> _targetLasers = new();
    private Area2D _interactionArea = null!;
    private Label _promptLabel = null!;
    private bool _playerInRange;

    public override void _Ready()
    {
        _interactionArea = GetNode<Area2D>(interactionAreaPath);
        _promptLabel = GetNode<Label>("PromptLabel");
        _promptLabel.Text = promptText;
        _promptLabel.Position = promptOffset;
        ResolveTargets();
        UpdatePrompt();
        QueueRedraw();
    }

    public override void _Process(double delta)
    {
        _playerInRange = HasPlayerInRange();
        UpdatePrompt();

        if (_playerInRange && Input.IsActionJustPressed(interactAction))
        {
            foreach (LaserBeam laser in _targetLasers)
                laser.Toggle();

            QueueRedraw();
        }
    }

    public override void _Draw()
    {
        Color bodyColor = HasAnyLaserEnabled() ? activeColor : inactiveColor;
        Rect2 bodyRect = new Rect2(new Vector2(-switchSize.X * 0.5f, -switchSize.Y), switchSize);
        DrawRect(bodyRect, bodyColor);
        DrawRect(new Rect2(bodyRect.Position + new Vector2(4f, 4f), bodyRect.Size - new Vector2(8f, 8f)), bodyColor.Darkened(0.4f));
    }

    private void ResolveTargets()
    {
        _targetLasers.Clear();

        foreach (NodePath targetPath in targetLaserPaths)
        {
            if (targetPath.IsEmpty)
                continue;

            LaserBeam laser = GetNodeOrNull<LaserBeam>(targetPath);
            if (laser != null)
                _targetLasers.Add(laser);
        }
    }

    private bool HasPlayerInRange()
    {
        foreach (Node body in _interactionArea.GetOverlappingBodies())
        {
            if (body is PlatformerCharacterController2D)
                return true;
        }

        return false;
    }

    private void UpdatePrompt()
    {
        _promptLabel.Visible = _playerInRange;
    }

    private bool HasAnyLaserEnabled()
    {
        if (_targetLasers.Count == 0)
            return false;

        foreach (LaserBeam laser in _targetLasers)
        {
            if (laser.IsEnabled)
                return true;
        }

        return false;
    }
}
