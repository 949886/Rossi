using Godot;
using System;

public partial class PlatformerCharacterController2D : CharacterBody2D
{
    #region Exports

    [Export] private AnimatedSprite2D animatedSprite;
    [Export] private AnimationPlayer animationPlayer;
    [Export] private AnimationTree animationTree;

    #endregion

    #region Movement Parameters

    [ExportGroup("Movement")]
    [Export] private float moveSpeed = 200f;
    [Export] private float acceleration = 1200f;
    [Export] private float friction = 1000f;
    [Export] private float airAcceleration = 600f;
    [Export] private float airFriction = 200f;

    #endregion

    #region Jump Parameters

    [ExportGroup("Jump")]
    [Export] private bool enableDoubleJump = true;
    [Export] private float jumpVelocity = -400f;
    [Export] private float doubleJumpVelocity = -350f;
    [Export] private float gravity = 980f;
    [Export] private float maxFallSpeed = 600f;
    [Export] private float jumpCutMultiplier = 0.5f;

    #endregion

    #region Dash Parameters

    [ExportGroup("Dash")]
    [Export] private float dashSpeed = 1000f;
    [Export] private float dashDuration = 0.15f;
    [Export] private float dashCooldown = 0.8f;
    [Export] private int maxDashCharges = 2;
    [Export] private float afterimageFadeDuration = 0.3f;
    [Export] private Color afterimageColor = new Color(0.4f, 0.8f, 1.0f, 0.6f);

    #endregion

    #region Wall Jump Parameters

    [ExportGroup("Wall Jump")]
    [Export] private bool enableWallJump = true;
    [Export] private float wallSlideGravity = 150f;
    [Export] private float wallJumpHorizontalSpeed = 300f;
    [Export] private float wallJumpVerticalSpeed = -380f;

    #endregion

    #region Attack Parameters

    [ExportGroup("Attack")]
    [Export] private float heavyAttackHoldTime = 0.3f;
    [Export] private float jumpAttackLift = 150f;
    [Export] private PackedScene shurikenScene;
    [Export] private Vector2 shurikenSpawnOffset = new Vector2(10f, -15f);

    [ExportGroup("Flying Thunder God")]
    [Export] private int teleportAfterimageCount = 6;
    [Export] private float teleportAfterimageFadeDuration = 0.16f;
    [Export] private Color teleportAfterimageColor = new Color(1.0f, 0.35f, 0.35f, 0.72f);
    [Export] private Color teleportFlashColor = new Color(1.0f, 0.18f, 0.18f, 0.95f);
    [Export] private Color teleportFlashCoreColor = new Color(1.0f, 1.0f, 1.0f, 0.98f);
    [Export] private float teleportFlashWidth = 14f;
    [Export] private float teleportFlashDuration = 0.05f;
    [Export] private int teleportSparkCount = 18;
    [Export] private float teleportSparkScatter = 18f;
    [Export] private float teleportSparkDuration = 0.16f;
    [Export] private float teleportArrivalOffset = 12f;

    #endregion

    #region State Machine

    private enum State
    {
        Idle,
        IdleToRun,
        Run,
        RunToIdle,
        Jump,
        JumpToFall,
        DoubleJump,
        Fall,
        Landing,
        FallToIdle,
        Attack1,
        Attack2,
        Attack3,
        HeavyAttack,
        Dash,
        WallSlide,
        JumpAttack,
        Throw,
        AirThrow,
        Die
    }

    private State _currentState = State.Idle;
    private int _facingDirection = 1; // 1 = right, -1 = left
    private bool _hasDoubleJump = true;
    private bool _hasJumpAttack = true;

    // Dash tracking
    private int _dashCharges;
    private float _dashRechargeTimer;
    private float _dashTimer;

    // Public API for UI to display dash cooldown and charges
    public int DashCharges => _dashCharges;
    public int MaxDashCharges => maxDashCharges;
    public float DashRechargeProgress => _dashCharges < maxDashCharges ? (_dashRechargeTimer / dashCooldown) : 0f;

    // Attack tracking
    private float _attackPressTime = 0f;
    private bool _attackButtonHeld = false;
    private bool _comboRequested = false;
    private bool _heavyAttackTriggered = false;

    // Wall slide tracking
    private int _wallDirection = 0; // -1 = wall on left, 1 = wall on right

    // Animations that should loop (all others play once)
    private static readonly string[] LoopingAnimations = { "idle", "run", "fall" };
    
    private float? _pendingThrowAngle = null;
    private Shuriken _activeShuriken = null;
    private readonly RandomNumberGenerator _rng = new();

    #endregion

    public override void _Ready()
    {
        // Auto-find nodes by relative path if not assigned via export
        animatedSprite ??= GetNode<AnimatedSprite2D>("AnimatedSprite2D");
        animationPlayer ??= GetNode<AnimationPlayer>("AnimationPlayer");
        animationTree = GetNodeOrNull<AnimationTree>("AnimationTree");

        // Disable AnimationTree — it overrides AnimationPlayer.Play() calls.
        // We drive animations entirely from code via AnimationPlayer.
        if (animationTree != null)
            animationTree.Active = false;

        animationPlayer.AnimationFinished += OnAnimationFinished;

        _dashCharges = maxDashCharges;
        _rng.Randomize();

        // Start in idle
        ChangeState(State.Idle);
    }

    public override void _PhysicsProcess(double delta)
    {
        float dt = (float)delta;

        // Recharge dash charges
        if (_dashCharges < maxDashCharges)
        {
            _dashRechargeTimer -= dt;
            if (_dashRechargeTimer <= 0f)
            {
                _dashCharges++;
                _dashRechargeTimer = dashCooldown;
            }
        }

        // Press throw again while a shuriken exists to teleport to it.
        if (Input.IsActionJustPressed("throw") && TryFlyingThunderGodTeleport())
            return;

        // Handle state-specific logic
        GD.Print($"Current State: {_currentState}");
        switch (_currentState)
        {
            case State.Idle:
                ProcessIdle(dt);
                break;
            case State.IdleToRun:
                ProcessIdleToRun(dt);
                break;
            case State.Run:
                ProcessRun(dt);
                break;
            case State.RunToIdle:
                ProcessRunToIdle(dt);
                break;
            case State.Jump:
                ProcessJump(dt);
                break;
            case State.JumpToFall:
                ProcessJumpToFall(dt);
                break;
            case State.DoubleJump:
                ProcessDoubleJump(dt);
                break;
            case State.Fall:
                ProcessFall(dt);
                break;
            case State.Landing:
                ProcessLanding(dt);
                break;
            // case State.FallToIdle:
            //     ProcessFallToIdle(dt);
            //     break;
            case State.WallSlide:
                ProcessWallSlide(dt);
                break;
            case State.JumpAttack:
                ProcessJumpAttack(dt);
                break;
            case State.Throw:
                ProcessThrow(dt);
                break;
            case State.AirThrow:
                ProcessAirThrow(dt);
                break;
            case State.Attack1:
            case State.Attack2:
            case State.Attack3:
                ProcessAttack(dt);
                break;
            case State.HeavyAttack:
                ProcessHeavyAttack(dt);
                break;
            case State.Dash:
                ProcessDash(dt);
                break;
        }

        this.MoveAndSlide();
    }

    public override void _Input(InputEvent @event)
    {
        // Track attack button press/release for heavy attack detection
        if (@event.IsActionPressed("attack"))
        {
            _attackPressTime = 0f;
            _attackButtonHeld = true;
            _heavyAttackTriggered = false;
        }
        else if (@event.IsActionReleased("attack"))
        {
            _attackButtonHeld = false;
        }
    }

    #region State Processors

    private void ProcessIdle(float dt)
    {
        ApplyGravity(dt);
        ApplyFriction(dt, true);

        // Heavy attack detection (hold mouse)
        if (_attackButtonHeld)
        {
            _attackPressTime += dt;
            if (_attackPressTime >= heavyAttackHoldTime && !_heavyAttackTriggered)
            {
                _heavyAttackTriggered = true;
                ChangeState(State.HeavyAttack);
                return;
            }
        }

        // Short press attack — trigger on button release
        if (Input.IsActionJustReleased("attack") && !_heavyAttackTriggered)
        {
            ChangeState(State.Attack1);
            return;
        }

        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            ChangeState(State.Dash);
            return;
        }

        if (Input.IsActionJustPressed("throw"))
        {
            ChangeState(State.Throw);
            return;
        }

        if (Input.IsActionJustPressed("jump") && this.IsOnFloor())
        {
            // Drop through one-way platform: S + Space
            if (Input.IsActionPressed("move_down") && TryDropThroughPlatform())
            {
                ChangeState(State.Fall);
                return;
            }
            ChangeState(State.Jump);
            return;
        }

        // Fall off edge
        if (!this.IsOnFloor())
        {
            ChangeState(State.Fall);
            return;
        }

        float inputDir = GetMoveInput();
        if (Mathf.Abs(inputDir) > 0.1f)
        {
            UpdateFacing(inputDir);
            ChangeState(State.IdleToRun);
        }
    }

    private void ProcessIdleToRun(float dt)
    {
        ApplyGravity(dt);
        ApplyMovement(dt, true);

        if (!this.IsOnFloor())
        {
            ChangeState(State.Fall);
            return;
        }

        if (Input.IsActionJustPressed("jump"))
        {
            ChangeState(State.Jump);
            return;
        }

        // AnimationFinished callback sets state to Run when transition completes
    }

    private void ProcessRun(float dt)
    {
        ApplyGravity(dt);
        ApplyMovement(dt, true);

        // Heavy attack detection
        if (_attackButtonHeld)
        {
            _attackPressTime += dt;
            if (_attackPressTime >= heavyAttackHoldTime && !_heavyAttackTriggered)
            {
                _heavyAttackTriggered = true;
                ChangeState(State.HeavyAttack);
                return;
            }
        }

        if (Input.IsActionJustReleased("attack") && !_heavyAttackTriggered)
        {
            ChangeState(State.Attack1);
            return;
        }

        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            ChangeState(State.Dash);
            return;
        }

        if (Input.IsActionJustPressed("throw"))
        {
            ChangeState(State.Throw);
            return;
        }

        if (!this.IsOnFloor())
        {
            ChangeState(State.Fall);
            return;
        }

        if (Input.IsActionJustPressed("jump"))
        {
            // Drop through one-way platform: S + Space
            if (Input.IsActionPressed("move_down") && TryDropThroughPlatform())
            {
                ChangeState(State.Fall);
                return;
            }
            ChangeState(State.Jump);
            return;
        }

        float inputDir = GetMoveInput();
        if (Mathf.Abs(inputDir) < 0.1f)
        {
            ChangeState(State.RunToIdle);
            return;
        }

        UpdateFacing(inputDir);
    }

    private void ProcessRunToIdle(float dt)
    {
        ApplyGravity(dt);
        ApplyFriction(dt, true);

        if (!this.IsOnFloor())
        {
            ChangeState(State.Fall);
            return;
        }

        if (Input.IsActionJustPressed("jump"))
        {
            ChangeState(State.Jump);
            return;
        }

        float inputDir = GetMoveInput();
        if (Mathf.Abs(inputDir) > 0.1f)
        {
            UpdateFacing(inputDir);
            ChangeState(State.IdleToRun);
            return;
        }

        // AnimationFinished callback handles transition to Idle
    }

    private void ProcessJump(float dt)
    {
        ApplyGravity(dt);
        ApplyMovement(dt, false);

        // Variable jump height
        if (Input.IsActionJustReleased("jump") && this.Velocity.Y < 0)
        {
            var vel = this.Velocity;
            vel.Y *= jumpCutMultiplier;
            this.Velocity = vel;
        }

        if (Input.IsActionJustPressed("jump") && _hasDoubleJump && enableDoubleJump)
        {
            ChangeState(State.DoubleJump);
            return;
        }

        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            ChangeState(State.Dash);
            return;
        }

        if (Input.IsActionJustPressed("throw"))
        {
            ChangeState(State.AirThrow);
            return;
        }

        if (Input.IsActionJustPressed("attack") && _hasJumpAttack)
        {
            ChangeState(State.JumpAttack);
            return;
        }

        // Transition to fall when starting to descend
        if (this.Velocity.Y > 0)
        {
            ChangeState(State.JumpToFall);
            return;
        }

        if (this.IsOnFloor())
        {
            ChangeState(State.Landing);
        }
    }

    private void ProcessJumpToFall(float dt)
    {
        ApplyGravity(dt);
        ApplyMovement(dt, false);

        if (Input.IsActionJustPressed("jump") && _hasDoubleJump && enableDoubleJump)
        {
            ChangeState(State.DoubleJump);
            return;
        }

        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            ChangeState(State.Dash);
            return;
        }

        if (Input.IsActionJustPressed("throw"))
        {
            ChangeState(State.AirThrow);
            return;
        }

        if (Input.IsActionJustPressed("attack") && _hasJumpAttack)
        {
            ChangeState(State.JumpAttack);
            return;
        }

        if (this.IsOnFloor())
        {
            ChangeState(State.Landing);
            return;
        }

        DetectWallSlide();

        // AnimationFinished callback handles transition to Fall
    }

    private void ProcessDoubleJump(float dt)
    {
        ApplyGravity(dt);
        ApplyMovement(dt, false);

        if (Input.IsActionJustReleased("jump") && this.Velocity.Y < 0)
        {
            var vel = this.Velocity;
            vel.Y *= jumpCutMultiplier;
            this.Velocity = vel;
        }

        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            ChangeState(State.Dash);
            return;
        }

        if (Input.IsActionJustPressed("throw"))
        {
            ChangeState(State.AirThrow);
            return;
        }

        if (Input.IsActionJustPressed("attack") && _hasJumpAttack)
        {
            ChangeState(State.JumpAttack);
            return;
        }

        if (this.Velocity.Y > 0)
        {
            ChangeState(State.Fall);
            return;
        }

        if (this.IsOnFloor())
        {
            ChangeState(State.Landing);
        }
    }

    private void ProcessFall(float dt)
    {
        ApplyGravity(dt);
        ApplyMovement(dt, false);

        if (Input.IsActionJustPressed("jump") && _hasDoubleJump && enableDoubleJump)
        {
            ChangeState(State.DoubleJump);
            return;
        }

        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            ChangeState(State.Dash);
            return;
        }

        if (Input.IsActionJustPressed("throw"))
        {
            ChangeState(State.AirThrow);
            return;
        }

        if (Input.IsActionJustPressed("attack") && _hasJumpAttack)
        {
            ChangeState(State.JumpAttack);
            return;
        }

        if (this.IsOnFloor())
        {
            ChangeState(State.Landing);
            return;
        }

        // Wall slide detection
        DetectWallSlide();
    }

    private void ProcessWallSlide(float dt)
    {
        // Slow gravity while on wall
        var vel = this.Velocity;
        vel.Y = Mathf.Min(vel.Y + wallSlideGravity * dt, wallSlideGravity);
        vel.X = 0;
        this.Velocity = vel;

        // Face away from wall
        UpdateFacing(-_wallDirection);

        // Wall jump
        if (Input.IsActionJustPressed("jump"))
        {
            var wjVel = this.Velocity;
            wjVel.X = -_wallDirection * wallJumpHorizontalSpeed;
            wjVel.Y = wallJumpVerticalSpeed;
            this.Velocity = wjVel;
            _hasDoubleJump = true; // Restore double jump
            UpdateFacing(-_wallDirection);
            ChangeState(State.Jump);
            return;
        }

        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            ChangeState(State.Dash);
            return;
        }

        if (Input.IsActionJustPressed("throw"))
        {
            ChangeState(State.AirThrow);
            return;
        }

        // Let go of wall
        float inputDir = GetMoveInput();
        var wallNormal = this.IsOnWall() ? this.GetWallNormal() : Vector2.Zero;
        bool stillOnWall = this.IsOnWall() &&
            ((_wallDirection == -1 && inputDir < -0.1f) || (_wallDirection == 1 && inputDir > 0.1f));

        if (!stillOnWall)
        {
            ChangeState(State.Fall);
            return;
        }

        if (this.IsOnFloor())
        {
            ChangeState(State.Landing);
        }
    }

    private void ProcessLanding(float dt)
    {
        ApplyGravity(dt);
        ApplyFriction(dt, true);

        // Allow player to cancel landing animation with movement or jump
        if (Input.IsActionJustPressed("jump") && this.IsOnFloor())
        {
            ChangeState(State.Jump);
            return;
        }

        float inputDir = GetMoveInput();
        if (Mathf.Abs(inputDir) > 0.1f)
        {
            UpdateFacing(inputDir);
            ChangeState(State.IdleToRun);
            return;
        }

        // AnimationFinished callback handles transition to Idle
    }

    private void ProcessAttack(float dt)
    {
        ApplyGravity(dt);
        ApplyFriction(dt, this.IsOnFloor());

        // Dash cancels attack — leave afterimage
        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            SpawnAfterimage();
            ChangeState(State.Dash);
            return;
        }

        // Jump cancels attack — leave afterimage
        if (Input.IsActionJustPressed("jump") && this.IsOnFloor())
        {
            SpawnAfterimage();
            ChangeState(State.Jump);
            return;
        }

        // Buffer combo input during attack animation
        if (Input.IsActionJustReleased("attack") && !_heavyAttackTriggered)
        {
            _comboRequested = true;
        }

        // AnimationFinished callback handles combo chain / return to Idle
    }

    private void ProcessHeavyAttack(float dt)
    {
        ApplyGravity(dt);
        ApplyFriction(dt, this.IsOnFloor());

        // Dash cancels heavy attack — leave afterimage
        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            SpawnAfterimage();
            ChangeState(State.Dash);
            return;
        }

        // Jump cancels heavy attack — leave afterimage
        if (Input.IsActionJustPressed("jump") && this.IsOnFloor())
        {
            SpawnAfterimage();
            ChangeState(State.Jump);
            return;
        }

        // AnimationFinished callback handles return to Idle
    }

    private void ProcessJumpAttack(float dt)
    {
        ApplyGravity(dt);
        ApplyMovement(dt, false);

        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            SpawnAfterimage();
            ChangeState(State.Dash);
            return;
        }

        if (this.IsOnFloor())
        {
            ChangeState(State.Landing);
            return;
        }
        
        // AnimationFinished callback handles transition back to Fall
    }

    private void ProcessThrow(float dt)
    {
        ApplyGravity(dt);
        ApplyFriction(dt, this.IsOnFloor());

        // Dash cancels throw
        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            SpawnAfterimage();
            ChangeState(State.Dash);
            return;
        }

        if (!this.IsOnFloor())
        {
            ChangeState(State.AirThrow);
            return;
        }
    }

    private void ProcessAirThrow(float dt)
    {
        ApplyGravity(dt);
        ApplyMovement(dt, false);

        // Dash cancels air throw
        if (Input.IsActionJustPressed("dash") && _dashCharges > 0)
        {
            SpawnAfterimage();
            ChangeState(State.Dash);
            return;
        }

        if (this.IsOnFloor())
        {
            ChangeState(State.Landing);
            return;
        }
    }

    private void InstantiateShuriken(float? overrideAngle = null)
    {
        if (shurikenScene == null)
        {
            GD.PrintErr("Shuriken Scene is null! You need to drag 'Shuriken.tscn' into the 'Shuriken Scene' property in the Inspector on your character!");
            return;
        }

        if (GodotObject.IsInstanceValid(_activeShuriken))
            _activeShuriken.QueueFree();

        var shuriken = shurikenScene.Instantiate<Shuriken>();
        GetTree().CurrentScene.AddChild(shuriken);
        
        var flipOffset = new Vector2(shurikenSpawnOffset.X * _facingDirection, shurikenSpawnOffset.Y);
        shuriken.GlobalPosition = this.GlobalPosition + flipOffset;
        
        if (overrideAngle.HasValue)
        {
            shuriken.Direction = Vector2.Right.Rotated(overrideAngle.Value);
        }
        else
        {
            Vector2 mousePos = GetGlobalMousePosition();
            shuriken.Direction = (mousePos - shuriken.GlobalPosition).Normalized();
        }
        
        shuriken.Rotation = shuriken.Direction.Angle();
        _activeShuriken = shuriken;
        shuriken.TreeExiting += () =>
        {
            if (_activeShuriken == shuriken)
                _activeShuriken = null;
        };
    }

    private void ProcessDash(float dt)
    {
        _dashTimer -= dt;

        // Override velocity during dash (no gravity)
        var vel = this.Velocity;
        vel.X = _facingDirection * dashSpeed;
        vel.Y = 0;
        this.Velocity = vel;

        if (_dashTimer <= 0f)
        {
            // Kill dash momentum so the character doesn't slide
            this.Velocity = Vector2.Zero;

            if (this.IsOnFloor())
                ChangeState(State.Idle);
            else
                ChangeState(State.Fall);
        }
    }

    #endregion

    #region State Transitions

    private void ChangeState(State newState)
    {
        var previousState = _currentState;
        _currentState = newState;

        switch (newState)
        {
            case State.Idle:
                PlayAnimation("idle");
                _hasDoubleJump = true;
                _hasJumpAttack = true;
                break;

            case State.IdleToRun:
                PlayAnimation("idle_to_run");
                break;

            case State.Run:
                PlayAnimation("run");
                break;

            case State.RunToIdle:
                PlayAnimation("run_to_idle");
                break;

            case State.Jump:
                // Wall jump already sets velocity, only set jump velocity for ground jumps
                if (previousState != State.WallSlide)
                {
                    var jumpVel = this.Velocity;
                    jumpVel.Y = jumpVelocity;
                    this.Velocity = jumpVel;
                }
                PlayAnimation("jump");
                break;

            case State.JumpToFall:
                PlayAnimation("jump_to_fall");
                break;

            case State.DoubleJump:
                _hasDoubleJump = false;
                var djVel = this.Velocity;
                djVel.Y = doubleJumpVelocity;
                this.Velocity = djVel;
                PlayAnimation("double_jump");
                break;

            case State.Fall:
                PlayAnimation("fall");
                break;

            case State.Landing:
                _hasDoubleJump = true;
                _hasJumpAttack = true;
                PlayAnimation("landing");
                break;

            case State.FallToIdle:
                PlayAnimation("fall_to_idle");
                break;

            case State.Attack1:
                _comboRequested = false;
                PlayAnimation("attack1");
                break;

            case State.Attack2:
                _comboRequested = false;
                PlayAnimation("attack2");
                break;

            case State.Attack3:
                _comboRequested = false;
                PlayAnimation("attack3");
                break;

            case State.HeavyAttack:
                PlayAnimation("heavy_attack");
                break;

            case State.Dash:
                _dashCharges--;
                _dashRechargeTimer = dashCooldown;
                _dashTimer = dashDuration;
                PlayAnimation("dash");
                break;

            case State.JumpAttack:
                _hasJumpAttack = false;
                var jaVel = this.Velocity;
                jaVel.Y = -jumpAttackLift;
                this.Velocity = jaVel;
                PlayAnimation("jump_attack");
                break;

            case State.Throw:
                if (_pendingThrowAngle.HasValue)
                {
                    UpdateFacing(Mathf.Cos(_pendingThrowAngle.Value));
                    PlayAnimation("shuriken");
                    InstantiateShuriken(_pendingThrowAngle);
                    _pendingThrowAngle = null;
                }
                else
                {
                    var mousePosThrow = GetGlobalMousePosition();
                    UpdateFacing(mousePosThrow.X - this.GlobalPosition.X);
                    PlayAnimation("shuriken");
                    InstantiateShuriken();
                }
                break;
            case State.AirThrow:
                if (_pendingThrowAngle.HasValue)
                {
                    UpdateFacing(Mathf.Cos(_pendingThrowAngle.Value));
                    PlayAnimation("shuriken_air");
                    InstantiateShuriken(_pendingThrowAngle);
                    _pendingThrowAngle = null;
                }
                else
                {
                    var mousePosAirThrow = GetGlobalMousePosition();
                    UpdateFacing(mousePosAirThrow.X - this.GlobalPosition.X);
                    PlayAnimation("shuriken_air");
                    InstantiateShuriken();
                }
                break;

            case State.WallSlide:
                _hasJumpAttack = true;
                PlayAnimation("fall"); // Reuse fall animation for wall slide
                break;
        }
    }

    #endregion

    #region Flying Thunder God

    private bool TryFlyingThunderGodTeleport()
    {
        if (!GodotObject.IsInstanceValid(_activeShuriken))
            return false;

        Vector2 startPos = GlobalPosition;
        Vector2 targetPos = _activeShuriken.GlobalPosition;

        if (_activeShuriken.IsStuck)
            targetPos += _activeShuriken.StickNormal * teleportArrivalOffset;

        SpawnTeleportTrail(startPos, targetPos);
        SpawnTeleportFlash(startPos, targetPos);

        GlobalPosition = targetPos;
        Velocity = Vector2.Zero;

        float deltaX = targetPos.X - startPos.X;
        if (Mathf.Abs(deltaX) > 0.01f)
            UpdateFacing(deltaX);

        if (GodotObject.IsInstanceValid(_activeShuriken))
            _activeShuriken.QueueFree();

        ChangeState(IsOnFloor() ? State.Idle : State.Fall);
        return true;
    }

    private void SpawnTeleportTrail(Vector2 from, Vector2 to)
    {
        if (animatedSprite?.SpriteFrames == null)
            return;

        var texture = animatedSprite.SpriteFrames.GetFrameTexture(animatedSprite.Animation, animatedSprite.Frame);
        if (texture == null)
            return;

        int count = Mathf.Max(2, teleportAfterimageCount);
        for (int i = 0; i < count; i++)
        {
            float t = count == 1 ? 1f : (float)i / (count - 1);
            var ghostColor = teleportAfterimageColor;
            ghostColor.A *= (1f - t * 0.6f);

            var ghost = new Sprite2D
            {
                Texture = texture,
                FlipH = animatedSprite.FlipH,
                TextureFilter = CanvasItem.TextureFilterEnum.Nearest,
                GlobalPosition = from.Lerp(to, t),
                Modulate = ghostColor
            };

            GetTree().CurrentScene.AddChild(ghost);

            var tween = ghost.CreateTween();
            tween.TweenProperty(ghost, "modulate:a", 0.0f, teleportAfterimageFadeDuration);
            tween.TweenCallback(Callable.From(() => ghost.QueueFree()));
        }
    }

    private void SpawnTeleportFlash(Vector2 from, Vector2 to)
    {
        Vector2 diff = to - from;
        if (diff.LengthSquared() < 0.0001f)
            return;

        Vector2 dir = diff.Normalized();
        Vector2 normal = dir.Orthogonal();
        var flashRoot = new Node2D();
        GetTree().CurrentScene.AddChild(flashRoot);

        // Outer glow layers for impact.
        var glowWideColor = teleportFlashColor;
        glowWideColor.A = 0.35f;
        var glowMidColor = teleportFlashColor;
        glowMidColor.A = 0.72f;

        var glowWideStart = glowWideColor;
        glowWideStart.A = 0.03f;
        var glowWideEnd = glowWideColor;
        glowWideEnd.A = 0.78f;

        var glowMidStart = glowMidColor;
        glowMidStart.A = 0.05f;
        var glowMidEnd = glowMidColor;
        glowMidEnd.A = 0.92f;

        var coreStart = teleportFlashCoreColor;
        coreStart.A = 0.08f;
        var coreEnd = new Color(1f, 1f, 1f, 1f);

        var hotStart = new Color(1f, 0.96f, 0.96f, 0.02f);
        var hotEnd = new Color(1f, 1f, 1f, 1f);

        // Sharp wedge profile: needle-like start and much thicker destination.
        var glowWide = CreateFlashLine(from + normal * 2f, to + normal * 2f, teleportFlashWidth * 2.9f, glowWideColor, 0.04f, 2.1f, glowWideStart, glowWideEnd);
        var glowMid = CreateFlashLine(from - normal * 1.5f, to - normal * 1.5f, teleportFlashWidth * 2.0f, glowMidColor, 0.045f, 2.25f, glowMidStart, glowMidEnd);
        var core = CreateFlashLine(from, to, teleportFlashWidth * 0.21f, teleportFlashCoreColor, 0.03f, 3.8f, coreStart, coreEnd);
        var coreHot = CreateFlashLine(from, to, teleportFlashWidth * 0.11f, new Color(1f, 1f, 1f, 1f), 0.02f, 4.2f, hotStart, hotEnd);

        flashRoot.AddChild(glowWide);
        flashRoot.AddChild(glowMid);
        flashRoot.AddChild(core);
        flashRoot.AddChild(coreHot);

        SpawnTeleportSparks(flashRoot, from, to, dir, normal);

        var tween = flashRoot.CreateTween();
        tween.SetParallel(true);
        tween.TweenProperty(flashRoot, "modulate:a", 0.0f, teleportFlashDuration);
        tween.TweenProperty(glowWide, "width", 0.0f, teleportFlashDuration);
        tween.TweenProperty(glowMid, "width", 0.0f, teleportFlashDuration);
        tween.TweenProperty(core, "width", 0.0f, teleportFlashDuration);
        tween.TweenProperty(coreHot, "width", 0.0f, teleportFlashDuration);
        tween.SetParallel(false);
        tween.TweenCallback(Callable.From(() => flashRoot.QueueFree()));
    }

    private Line2D CreateFlashLine(
        Vector2 from,
        Vector2 to,
        float width,
        Color color,
        float startWidthScale = 1f,
        float endWidthScale = 1f,
        Color? startColor = null,
        Color? endColor = null)
    {
        var line = new Line2D
        {
            Width = width,
            DefaultColor = color,
            Antialiased = true
        };

        // Make the beam thinner at the origin and thicker at the destination.
        var widthCurve = new Curve();
        widthCurve.AddPoint(new Vector2(0f, Mathf.Max(0.01f, startWidthScale)));
        widthCurve.AddPoint(new Vector2(1f, Mathf.Max(0.01f, endWidthScale)));
        line.WidthCurve = widthCurve;

        var gradient = new Gradient();
        gradient.AddPoint(0f, startColor ?? color);
        gradient.AddPoint(1f, endColor ?? color);
        line.Gradient = gradient;

        line.AddPoint(from);
        line.AddPoint(to);
        return line;
    }

    private void SpawnTeleportSparks(Node2D parent, Vector2 from, Vector2 to, Vector2 dir, Vector2 normal)
    {
        int sparkCount = Mathf.Max(0, teleportSparkCount);
        for (int i = 0; i < sparkCount; i++)
        {
            float t = _rng.RandfRange(0f, 1f);
            float side = _rng.RandfRange(-teleportSparkScatter, teleportSparkScatter);
            Vector2 center = from.Lerp(to, t) + normal * side;

            float length = _rng.RandfRange(8f, 20f);
            float angle = _rng.RandfRange(-0.9f, 0.9f);
            Vector2 sparkDir = dir.Rotated(angle);
            Vector2 p1 = center - sparkDir * (length * 0.5f);
            Vector2 p2 = center + sparkDir * (length * 0.5f);

            var sparkColor = teleportFlashCoreColor;
            sparkColor.A = _rng.RandfRange(0.6f, 1f);
            var spark = CreateFlashLine(p1, p2, _rng.RandfRange(1.3f, 3f), sparkColor);
            parent.AddChild(spark);

            var tw = spark.CreateTween();
            tw.SetParallel(true);
            tw.TweenProperty(spark, "modulate:a", 0.0f, teleportSparkDuration);
            tw.TweenProperty(spark, "width", 0.0f, teleportSparkDuration);
        }
    }

    #endregion

    #region Afterimage Effect

    private void SpawnAfterimage()
    {
        // Create a ghost sprite at the current position
        var ghost = new Sprite2D();
        ghost.Texture = animatedSprite.SpriteFrames.GetFrameTexture(
            animatedSprite.Animation, animatedSprite.Frame);
        ghost.FlipH = animatedSprite.FlipH;
        ghost.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;

        // Position the ghost in world space
        ghost.GlobalPosition = animatedSprite.GlobalPosition;
        ghost.Modulate = afterimageColor;

        // Add to the scene tree (as sibling of root, so it doesn't move with character)
        GetTree().CurrentScene.AddChild(ghost);

        // Fade out and remove
        var tween = ghost.CreateTween();
        tween.TweenProperty(ghost, "modulate:a", 0.0f, afterimageFadeDuration);
        tween.TweenCallback(Callable.From(() => ghost.QueueFree()));
    }

    #endregion

    #region Animation Handling

    private void PlayAnimation(string animName)
    {
        // Set correct loop mode before playing:
        // Only idle, run, fall should loop. Everything else plays once.
        if (animationPlayer.HasAnimation(animName))
        {
            var anim = animationPlayer.GetAnimation(animName);
            bool shouldLoop = Array.Exists(LoopingAnimations, a => a == animName);
            anim.LoopMode = shouldLoop
                ? Animation.LoopModeEnum.Linear
                : Animation.LoopModeEnum.None;
        }

        animationPlayer.Play(animName);
    }

    private void OnAnimationFinished(StringName animName)
    {
        string name = animName.ToString();

         switch (name)
        {
            // Transition animations → advance to next state
            case "idle_to_run":
                if (_currentState == State.IdleToRun)
                    ChangeState(State.Run);
                break;

            case "run_to_idle":
                if (_currentState == State.RunToIdle)
                    ChangeState(State.Idle);
                break;

            case "jump_to_fall":
                if (_currentState == State.JumpToFall)
                    ChangeState(State.Fall);
                break;

            case "landing":
            case "fall_to_idle":
                if (_currentState == State.Landing || _currentState == State.FallToIdle)
                    ChangeState(State.Idle);
                break;

            // Jump finishes → transition to fall if descending
            case "jump":
                if (_currentState == State.Jump)
                {
                    if (this.Velocity.Y >= 0)
                        ChangeState(State.JumpToFall);
                }
                break;

            case "double_jump":
                if (_currentState == State.DoubleJump)
                {
                    if (this.Velocity.Y >= 0)
                        ChangeState(State.Fall);
                }
                break;

            // Attack combo chain
            case "attack1":
                if (_currentState == State.Attack1)
                {
                    if (_comboRequested)
                        ChangeState(State.Attack2);
                    else
                        ChangeState(State.Idle);
                }
                break;

            case "attack2":
                if (_currentState == State.Attack2)
                {
                    if (_comboRequested)
                        ChangeState(State.Attack3);
                    else
                        ChangeState(State.Idle);
                }
                break;

            case "attack3":
            case "heavy_attack":
                ChangeState(State.Idle);
                break;

            case "shuriken":
                if (_currentState == State.Throw)
                {
                    ChangeState(State.Idle);
                }
                break;
                
            case "shuriken_air":
                if (_currentState == State.AirThrow)
                {
                    ChangeState(State.Fall);
                }
                break;

            case "jump_attack":
                if (_currentState == State.JumpAttack)
                {
                    ChangeState(State.Fall);
                }
                break;

            case "dash":
                if (_currentState == State.Dash)
                {
                    this.Velocity = Vector2.Zero;
                    if (this.IsOnFloor())
                        ChangeState(State.Idle);
                    else
                        ChangeState(State.Fall);
                }
                break;
        }
    }

    #endregion

    #region Physics Helpers

    private float GetMoveInput()
    {
        return Input.GetAxis("move_left", "move_right");
    }

    private void ApplyGravity(float dt)
    {
        if (!this.IsOnFloor())
        {
            var vel = this.Velocity;
            vel.Y = Mathf.Min(vel.Y + gravity * dt, maxFallSpeed);
            this.Velocity = vel;
        }
    }

    private void ApplyMovement(float dt, bool grounded)
    {
        float inputDir = GetMoveInput();
        float accel = grounded ? acceleration : airAcceleration;
        float fric = grounded ? friction : airFriction;

        var vel = this.Velocity;

        if (Mathf.Abs(inputDir) > 0.1f)
        {
            vel.X = Mathf.MoveToward(vel.X, inputDir * moveSpeed, accel * dt);
            if (grounded) UpdateFacing(inputDir);
        }
        else
        {
            vel.X = Mathf.MoveToward(vel.X, 0, fric * dt);
        }

        this.Velocity = vel;
    }

    private void ApplyFriction(float dt, bool grounded)
    {
        float fric = grounded ? friction : airFriction;
        var vel = this.Velocity;
        vel.X = Mathf.MoveToward(vel.X, 0, fric * dt);
        this.Velocity = vel;
    }

    private void UpdateFacing(float direction)
    {
        if (direction > 0.1f)
            _facingDirection = 1;
        else if (direction < -0.1f)
            _facingDirection = -1;

        animatedSprite.FlipH = _facingDirection < 0;
    }
    
    private void DetectWallSlide()
    {
        if (enableWallJump && this.IsOnWall() && !this.IsOnFloor())
        {
            float inputDir = GetMoveInput();
            var wallNormal = this.GetWallNormal();
            
            // Only wall slide if player is pressing toward the wall
            if ((wallNormal.X > 0 && inputDir < -0.1f) || (wallNormal.X < 0 && inputDir > 0.1f))
            {
                _wallDirection = wallNormal.X > 0 ? -1 : 1;
                ChangeState(State.WallSlide);
            }
        }
    }

    private bool TryDropThroughPlatform()
    {
        // Check if standing on a one-way collision platform
        for (int i = 0; i < this.GetSlideCollisionCount(); i++)
        {
            var collision = this.GetSlideCollision(i);
            var collider = collision.GetCollider();
            bool isOneWay = false;

            // StaticBody2D: check children for OneWayCollision shapes
            if (collider is StaticBody2D staticBody)
            {
                foreach (var child in staticBody.GetChildren())
                {
                    if (child is CollisionShape2D shape && shape.OneWayCollision)
                    {
                        isOneWay = true;
                        break;
                    }
                }
            }
            // TileMapLayer / TileMap: assume one-way if player intentionally presses down+jump
            else if (collider is TileMap tileMap)
            {
                var mapPos = tileMap.LocalToMap(collision.GetPosition());
                var tileData = tileMap.GetCellTileData(0, mapPos);
                
                if (tileData != null)
                {
                    int polygonCount = tileData.GetCollisionPolygonsCount(0);
                    for (int j = 0; j < polygonCount; j++) 
                        isOneWay = tileData.IsCollisionPolygonOneWay(0, j);
                }
                
                // isOneWay = true;
            }
            else if (collider is TileMapLayer tileMapLayer)
            {
                var mapPos = tileMapLayer.LocalToMap(collision.GetPosition());
                var tileData = tileMapLayer.GetCellTileData(mapPos);
                
                if (tileData != null)
                {
                    int polygonCount = tileData.GetCollisionPolygonsCount(0);
                    for (int j = 0; j < polygonCount; j++) 
                        isOneWay = tileData.IsCollisionPolygonOneWay(0, j);
                }
            }

            if (isOneWay)
            {
                // Disable floor snap to prevent snapping back onto the platform
                float prevSnap = this.FloorSnapLength;
                this.FloorSnapLength = 0;
                this.Position += new Vector2(0, 4);
                this.Velocity = new Vector2(this.Velocity.X, 50);

                // Restore floor snap after passing through
                GetTree().CreateTimer(0.15).Timeout += () =>
                {
                    if (IsInstanceValid(this))
                        this.FloorSnapLength = prevSnap;
                };
                return true;
            }
        }
        return false;
    }

    /// <summary>
    /// Handles throw event triggered directly by the on-screen Virtual Direction Button.
    /// Needs an angle in Radians from the button.
    /// </summary>
    public void OnVirtualThrowActivated(float aimAngle)
    {
        if (TryFlyingThunderGodTeleport())
            return;

        // Don't throw if already throwing
        if (_currentState == State.Throw || _currentState == State.AirThrow)
            return;

        _pendingThrowAngle = aimAngle;
        
        if (this.IsOnFloor())
        {
            ChangeState(State.Throw);
        }
        else
        {
            ChangeState(State.AirThrow);
        }
    }

    #endregion
}
