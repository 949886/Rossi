// Created by Copilot on 2026-03-10.
// Demo scene for the Virtual Joystick plugin.

using Godot;
using VirtualJoystickPlugin;

/// <summary>
/// A demo that shows all features of the VirtualJoystick plugin.
/// Includes a character that moves based on joystick input, and action buttons.
/// </summary>
public partial class JoystickDemo : Node2D
{
    private VirtualJoystick _joystick;
    private VirtualButton _jumpButton;
    private VirtualButton _attackButton;
    private ColorRect _player;
    private Label _infoLabel;

    private Vector2 _playerVelocity = Vector2.Zero;
    private const float MoveSpeed = 300f;
    private const float Friction = 8f;
    private bool _isJumping;
    private float _jumpTimer;
    private Vector2 _originalScale;

    public override void _Ready()
    {
        _CreateUI();
        _CreatePlayer();
    }

    public override void _Process(double delta)
    {
        float dt = (float)delta;

        // Move player based on joystick output
        if (_joystick != null)
        {
            var input = _joystick.Output;
            _playerVelocity = _playerVelocity.Lerp(input * MoveSpeed, Friction * dt);
            _player.Position += _playerVelocity * dt;

            // Keep player in screen bounds
            var screenSize = GetViewportRect().Size;
            _player.Position = new Vector2(
                Mathf.Clamp(_player.Position.X, 0, screenSize.X - _player.Size.X),
                Mathf.Clamp(_player.Position.Y, 0, screenSize.Y - _player.Size.Y)
            );

            // Update info label
            _infoLabel.Text = $"Output: ({input.X:F2}, {input.Y:F2})\n" +
                              $"Strength: {_joystick.Strength:F2}\n" +
                              $"Angle: {Mathf.RadToDeg(_joystick.Angle):F1}°\n" +
                              $"Pressed: {_joystick.IsPressed}";
        }

        // Jump animation
        if (_isJumping)
        {
            _jumpTimer += dt * 6f;
            float jumpHeight = Mathf.Sin(_jumpTimer * Mathf.Pi) * 30f;
            _player.Scale = _originalScale * (1f + jumpHeight / 100f);
            if (_jumpTimer >= 1f)
            {
                _isJumping = false;
                _player.Scale = _originalScale;
            }
        }
    }

    private void _CreateUI()
    {
        // Background
        var bg = new ColorRect();
        bg.Color = new Color(0.12f, 0.14f, 0.18f, 1f);
        bg.SetAnchorsPreset(Control.LayoutPreset.FullRect);
        var canvasLayer = new CanvasLayer();
        canvasLayer.Layer = -1;
        canvasLayer.AddChild(bg);
        AddChild(canvasLayer);

        // UI Layer
        var uiLayer = new CanvasLayer();
        uiLayer.Layer = 10;
        AddChild(uiLayer);

        // Info Label
        _infoLabel = new Label();
        _infoLabel.Position = new Vector2(20, 20);
        _infoLabel.AddThemeColorOverride("font_color", Colors.White);
        _infoLabel.AddThemeFontSizeOverride("font_size", 16);
        _infoLabel.Text = "Touch the joystick to start";
        uiLayer.AddChild(_infoLabel);

        // Title
        var title = new Label();
        title.Text = "Virtual Joystick Demo";
        title.Position = new Vector2(20, 0);
        title.AddThemeColorOverride("font_color", new Color(0.7f, 0.8f, 1f));
        title.AddThemeFontSizeOverride("font_size", 14);
        uiLayer.AddChild(title);

        // === LEFT SIDE: Joystick ===
        var joystickContainer = new Control();
        joystickContainer.SetAnchorsPreset(Control.LayoutPreset.BottomLeft);
        joystickContainer.Size = new Vector2(300, 300);
        joystickContainer.Position = new Vector2(20, -320);
        joystickContainer.MouseFilter = Control.MouseFilterEnum.Ignore;
        uiLayer.AddChild(joystickContainer);

        _joystick = new VirtualJoystick();
        _joystick.Mode = VirtualJoystick.JoystickMode.Fixed;
        _joystick.Visibility = VirtualJoystick.VisibilityMode.FadeInOut;
        _joystick.BaseRadius = 80f;
        _joystick.HandleRadius = 35f;
        _joystick.DeadZone = 0.15f;
        _joystick.BaseColor = new Color(0.2f, 0.25f, 0.35f, 0.7f);
        _joystick.HandleColor = new Color(0.6f, 0.7f, 0.9f, 0.8f);
        _joystick.HandlePressedColor = new Color(0.8f, 0.9f, 1f, 1f);
        _joystick.Position = new Vector2(70, 70);
        _joystick.Size = new Vector2(160, 160);
        joystickContainer.AddChild(_joystick);        // === RIGHT SIDE: Buttons ===
        // Jump button
        _jumpButton = new VirtualButton();
        _jumpButton.Label = "B";
        _jumpButton.ButtonRadius = 40f;
        _jumpButton.NormalColor = new Color(0.2f, 0.35f, 0.5f, 0.7f);
        _jumpButton.PressedColor = new Color(0.3f, 0.6f, 0.9f, 0.95f);
        _jumpButton.SetAnchorsPreset(Control.LayoutPreset.BottomRight);
        _jumpButton.Size = new Vector2(80, 80);
        _jumpButton.Position = new Vector2(-200, -220);
        _jumpButton.ButtonDown += OnJumpPressed;
        uiLayer.AddChild(_jumpButton);

        // Attack button
        _attackButton = new VirtualButton();
        _attackButton.Label = "A";
        _attackButton.ButtonRadius = 40f;
        _attackButton.NormalColor = new Color(0.5f, 0.2f, 0.2f, 0.7f);
        _attackButton.PressedColor = new Color(0.9f, 0.3f, 0.3f, 0.95f);
        _attackButton.SetAnchorsPreset(Control.LayoutPreset.BottomRight);
        _attackButton.Size = new Vector2(80, 80);
        _attackButton.Position = new Vector2(-110, -130);
        _attackButton.ButtonDown += OnAttackPressed;
        uiLayer.AddChild(_attackButton);

        // Mode Switch Button
        var modeBtn = new Button();
        modeBtn.Text = "Switch Mode";
        modeBtn.Position = new Vector2(20, 110);
        modeBtn.CustomMinimumSize = new Vector2(120, 35);
        modeBtn.Pressed += OnModeSwitchPressed;
        uiLayer.AddChild(modeBtn);
    }

    private void _CreatePlayer()
    {
        // Simple square "player"
        _player = new ColorRect();
        _player.Size = new Vector2(50, 50);
        _player.Color = new Color(0.4f, 0.7f, 1f);
        _player.Position = GetViewportRect().Size / 2f - _player.Size / 2f;
        _player.PivotOffset = _player.Size / 2f;
        _originalScale = Vector2.One;
        AddChild(_player);

        // Direction indicator
        var indicator = new ColorRect();
        indicator.Size = new Vector2(10, 10);
        indicator.Color = Colors.White;
        indicator.Position = new Vector2(20, 5);
        _player.AddChild(indicator);
    }

    private void OnJumpPressed()
    {
        if (!_isJumping)
        {
            _isJumping = true;
            _jumpTimer = 0f;
        }
    }

    private void OnAttackPressed()
    {
        // Flash player color
        var originalColor = _player.Color;
        _player.Color = new Color(1f, 0.3f, 0.3f);
        var tween = CreateTween();
        tween.TweenProperty(_player, "color", originalColor, 0.3);
    }

    private int _currentMode = 0;
    private void OnModeSwitchPressed()
    {
        _currentMode = (_currentMode + 1) % 3;
        _joystick.Mode = (VirtualJoystick.JoystickMode)_currentMode;
        GD.Print($"Joystick Mode: {_joystick.Mode}");
    }
}
