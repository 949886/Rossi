using Godot;
using System;
using System.Collections.Generic;

[GlobalClass]
public partial class LaserBeam : Node2D
{
    [ExportGroup("Beam")]
    [Export] private Vector2 direction = Vector2.Right;
    [Export(PropertyHint.Range, "1,4000,1")] private float maxLength = 320f;
    [Export(PropertyHint.Range, "1,64,0.5")] private float beamWidth = 8f;
    [Export(PropertyHint.Range, "0.01,1,0.01")] private float hitPadding = 2f;
    [Export] private bool startsEnabled = true;

    [ExportGroup("Collision")]
    [Export(PropertyHint.Layers2DPhysics)] private uint blockerCollisionMask = 1;
    [Export(PropertyHint.Layers2DPhysics)] private uint damageCollisionMask = 1;
    [Export] private bool collideWithAreas = false;
    [Export] private bool collideWithBodies = true;

    [ExportGroup("Visuals")]
    [Export] private Color[] activeColors =
    {
        new Color(1f, 0.2f, 0.2f, 0.96f),
        new Color(1f, 0.85f, 0.2f, 0.96f),
        new Color(0.2f, 1f, 0.8f, 0.96f),
        new Color(0.45f, 0.65f, 1f, 0.96f)
    };
    [Export] private Color disabledColor = new(1f, 0.15f, 0.15f, 0.95f);
    [Export(PropertyHint.Range, "0.1,20,0.1")] private float colorCycleSpeed = 4f;
    [Export(PropertyHint.Range, "2,64,1")] private float dashLength = 18f;
    [Export(PropertyHint.Range, "2,64,1")] private float dashGap = 10f;

    private Area2D _damageArea = null!;
    private CollisionShape2D _damageShape = null!;
    private float _currentLength;
    private bool _isEnabled;

    public bool IsEnabled => _isEnabled;

    public override void _Ready()
    {
        _damageArea = GetNode<Area2D>("DamageArea");
        _damageShape = GetNode<CollisionShape2D>("DamageArea/CollisionShape2D");
        
        _isEnabled = startsEnabled;
        SetPhysicsProcess(true);
        UpdateBeam();
    }

    public override void _PhysicsProcess(double delta)
    {
        UpdateBeam();

        if (!_isEnabled || !_damageArea.Monitoring)
            return;

        foreach (Node body in _damageArea.GetOverlappingBodies())
            if (body is CharacterBody2D character)
                (character as dynamic).InteractWith(this);
    }

    public override void _Draw()
    {
        if (_currentLength <= 0.1f)
            return;

        Vector2 beamVector = GetNormalizedDirection() * _currentLength;
        Color beamColor = _isEnabled ? GetAnimatedActiveColor() : disabledColor;

        if (_isEnabled)
        {
            DrawLine(Vector2.Zero, beamVector, beamColor, beamWidth, true);
            DrawCircle(Vector2.Zero, beamWidth * 0.45f, beamColor);
            DrawCircle(beamVector, beamWidth * 0.35f, beamColor);
            return;
        }

        Vector2 beamDir = GetNormalizedDirection();
        float distance = 0f;
        while (distance < _currentLength)
        {
            float segmentStart = distance;
            float segmentEnd = Mathf.Min(distance + dashLength, _currentLength);
            Vector2 start = beamDir * segmentStart;
            Vector2 end = beamDir * segmentEnd;
            DrawLine(start, end, beamColor, beamWidth * 0.75f, true);
            distance += dashLength + dashGap;
        }
    }

    public void SetEnabled(bool enabled)
    {
        if (_isEnabled == enabled)
            return;

        _isEnabled = enabled;
        UpdateBeam();
    }

    public void Toggle()
    {
        SetEnabled(!_isEnabled);
    }

    private void UpdateBeam()
    {
        _currentLength = ComputeVisibleLength();
        // ComputeVisibleLength();
        // _currentLength++;
        UpdateDamageShape();
        QueueRedraw();
    }

    private float ComputeVisibleLength()
    {
        Vector2 normalizedDirection = GetNormalizedDirection();
        Vector2 start = GlobalPosition;
        Vector2 end = start + normalizedDirection * maxLength;
        PhysicsDirectSpaceState2D state = GetWorld2D().DirectSpaceState;
        Godot.Collections.Array<Rid> excludes = new() { _damageArea.GetRid() };

        for (int attempt = 0; attempt < 8; attempt++)
        {
            PhysicsRayQueryParameters2D query = PhysicsRayQueryParameters2D.Create(start, end, blockerCollisionMask, excludes);
            query.CollideWithAreas = collideWithAreas;
            query.CollideWithBodies = collideWithBodies;

            var result = state.IntersectRay(query);
            if (result.Count == 0)
                return maxLength;
            
            Variant colliderVariant = result["collider"];
            if (colliderVariant.Obj is CollisionObject2D collider)
            {
                if (collider.IsInGroup("Player"))
                {
                    excludes.Add(collider.GetRid());
                    continue;
                }
            }
            
            Vector2 hitPoint = result["position"].AsVector2();
            float length = start.DistanceTo(hitPoint) - hitPadding;
            return length;
        }

        return maxLength;
    }

    private void UpdateDamageShape()
    {
        _damageArea.Monitoring = _isEnabled;
        _damageArea.Monitorable = _damageArea.Monitoring;

        if (_damageShape.Shape is RectangleShape2D rectangleShape)
        {
            if (_currentLength <= 0.1f)
            {
                rectangleShape.Size = new Vector2(0.01f, beamWidth);
                _damageShape.Position = Vector2.Zero;
                return;
            }

            _damageArea.Rotation = GetNormalizedDirection().Angle();
            rectangleShape.Size = new Vector2(_currentLength, beamWidth + 6f);
            _damageShape.Position = new Vector2(_currentLength * 0.5f, 0f);
        }
    }

    private Vector2 GetNormalizedDirection()
    {
        if (direction == Vector2.Zero)
            return Vector2.Right;

        return direction.Normalized();
    }

    private Color GetAnimatedActiveColor()
    {
        if (activeColors == null || activeColors.Length == 0)
            return Colors.White;

        if (activeColors.Length == 1)
            return activeColors[0];

        double time = Time.GetTicksMsec() / 1000.0;
        float cycle = (float)(time * colorCycleSpeed);
        int fromIndex = Mathf.PosMod(Mathf.FloorToInt(cycle), activeColors.Length);
        int toIndex = (fromIndex + 1) % activeColors.Length;
        float weight = cycle - Mathf.Floor(cycle);
        return activeColors[fromIndex].Lerp(activeColors[toIndex], weight);
    }
}
