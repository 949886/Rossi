using Godot;
using System;

public partial class Shuriken : Area2D
{
    [Export] public float Speed { get; set; } = 1000f;
    [Export] public float Lifespan { get; set; } = 5.0f;
    [Export] public float AfterimageInterval { get; set; } = 0.033334f;
    [Export] public float AfterimageDuration { get; set; } = 0.25f;
    [Export] public Color AfterimageColor { get; set; } = new Color(0.1f, 0.5f, 1f, 0.6f);

    public Vector2 Direction { get; set; } = Vector2.Right;
    public bool IsStuck => _stuck;
    public Vector2 StickNormal => _stickNormal;

    private bool _stuck = false;
    private Vector2 _stickNormal = Vector2.Zero;
    private float _afterimageTimer = 0f;
    private Sprite2D _sprite;

    public override void _Ready()
    {
        _sprite = GetNode<Sprite2D>("Sprite2D");

        // Face the correct direction based on throw direction
        Rotation = Direction.Angle();
    }

    public override void _PhysicsProcess(double delta)
    {
        if (_stuck)
            return;

        float dt = (float)delta;
        Vector2 movement = Direction * Speed * dt;
        
        // Raycast ahead to see if we hit a wall this frame
        var spaceState = GetWorld2D().DirectSpaceState;
        var query = PhysicsRayQueryParameters2D.Create(GlobalPosition, GlobalPosition + movement, CollisionMask);
        query.CollideWithAreas = false;
        query.CollideWithBodies = true;
        
        var result = spaceState.IntersectRay(query);
        
        if (result.Count > 0)
        {
            var collider = (Node2D)result["collider"];
            if (collider is StaticBody2D || collider is TileMapLayer || collider is TileMap)
            {
                // Move exactly to the hit point and stick
                GlobalPosition = (Vector2)result["position"];
                _stickNormal = (Vector2)result["normal"];
                StickToSurface();
                return;
            }
        }
        
        // Move normally
        Position += movement;

        // Spawn afterimages
        _afterimageTimer -= dt;
        if (_afterimageTimer <= 0f)
        {
            SpawnAfterimage();
            _afterimageTimer = AfterimageInterval;
        }
    }

    private void StickToSurface()
    {
        _stuck = true;

        // Disable further collisions
        SetDeferred(Area2D.PropertyName.Monitoring, false);
        SetDeferred(Area2D.PropertyName.Monitorable, false);

        // Start stick lifespan timer
        GetTree().CreateTimer(Lifespan).Timeout += () =>
        {
            if (IsInstanceValid(this))
                QueueFree();
        };
    }

    private void SpawnAfterimage()
    {
        if (_sprite == null || _sprite.Texture == null) return;

        var ghost = new Sprite2D
        {
            Texture = _sprite.Texture,
            GlobalPosition = _sprite.GlobalPosition,
            Rotation = this.Rotation,
            Modulate = AfterimageColor,
            TextureFilter = CanvasItem.TextureFilterEnum.Nearest
        };

        // Add to main scene tree so it stays behind when shuriken moves/dies
        GetTree().CurrentScene.AddChild(ghost);

        var tween = ghost.CreateTween();
        tween.TweenProperty(ghost, "modulate:a", 0.0f, AfterimageDuration);
        tween.TweenCallback(Callable.From(() => ghost.QueueFree()));
    }
}
