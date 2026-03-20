// Platformer + Virtual Joystick demo with scene-defined touch controls.
// Unlike PlatformerJoystickDemo.cs, this script does NOT create UI programmatically.
// All touch controls (joystick, buttons, info panel) are defined in PlatformerTouchDemo.tscn.

using Godot;
using System;
using VirtualJoystickPlugin;

public partial class PlatformerJoystickDemo : Node2D
{
    // Node references – resolved from the scene tree
    private VirtualJoystick _joystick;
    private VirtualButton _jumpButton;
    private VirtualDirectionButton _attackButton;
    private VirtualProgressButton _dashButton;
    private VirtualDirectionButton _throwButton;
    private Label _infoLabel;
    private Control _touchControls;
    private CanvasLayer _touchUi;
    
    // Player reference for querying state
    private PlatformerCharacter2D _player;

    private bool _showInfo = true;

    public override void _Ready()
    {
        // Resolve nodes placed in the .tscn scene
        _joystick = GetNodeOrNull<VirtualJoystick>("TouchUI/TouchControls/JoystickArea/Joystick");
        _jumpButton = GetNodeOrNull<VirtualButton>("TouchUI/TouchControls/ButtonArea/JumpBtn");
        _attackButton = GetNodeOrNull<VirtualDirectionButton>("TouchUI/TouchControls/ButtonArea/AttackBtn");
        _dashButton = GetNodeOrNull<VirtualProgressButton>("TouchUI/TouchControls/ButtonArea/DashBtn");
        _throwButton = GetNodeOrNull<VirtualDirectionButton>("TouchUI/TouchControls/ButtonArea/ThrowBtn");
        _infoLabel = GetNodeOrNull<Label>("TouchUI/InfoPanel/InfoLabel");
        _touchControls = GetNodeOrNull<Control>("TouchUI/TouchControls");
        _touchUi = GetNodeOrNull<CanvasLayer>("TouchUI");

        if (_touchUi != null)
        {
            _touchUi.Visible = ShouldShowTouchUi();
        }

        // Apply a semi-transparent panel style to InfoPanel
        var infoPanel = GetNodeOrNull<PanelContainer>("TouchUI/InfoPanel");
        if (infoPanel != null)
        {
            var styleBox = new StyleBoxFlat();
            styleBox.BgColor = new Color(0, 0, 0, 0.5f);
            styleBox.SetCornerRadiusAll(6);
            styleBox.SetContentMarginAll(8);
            infoPanel.AddThemeStyleboxOverride("panel", styleBox);
        }

        _player = GetNodeOrNull<PlatformerCharacter2D>("Playground/CharacterBody2D");

        if (_attackButton != null && _player != null)
        {
            _attackButton.DirectionActivated += _player.OnVirtualAttackActivated;
        }

        // Connect the directional throw button directly to the Player controller.
        if (_throwButton != null && _player != null)
        {
            _throwButton.DirectionActivated += _player.OnVirtualThrowActivated;
        }
    }

    private static bool ShouldShowTouchUi()
    {
        if (OS.HasFeature("mobile") || OS.HasFeature("android") || OS.HasFeature("ios"))
        {
            return true;
        }

        if (OS.HasFeature("web"))
        {
            return IsMobileWebBrowser();
        }

        return false;
    }

    private static bool IsMobileWebBrowser()
    {
        var result = JavaScriptBridge.Eval(
            """
            (() => {
                const ua = navigator.userAgent || "";
                const mobileUa = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini|Mobile/i.test(ua);
                const touchPoints = navigator.maxTouchPoints || 0;
                const shortSide = Math.min(window.screen.width || 0, window.screen.height || 0);
                return mobileUa || (touchPoints > 1 && shortSide > 0 && shortSide <= 1024);
            })()
            """,
            true
        );

        return result.VariantType == Variant.Type.Bool && result.AsBool();
    }

    public override void _Process(double delta)
    {
        // Update Skill Button UI
        if (_player != null && _dashButton != null)
        {
            _dashButton.ChargeCount = _player.DashCharges;
            _dashButton.MaxChargeCount = _player.MaxDashCharges;
            _dashButton.CooldownProgress = _player.DashRechargeProgress;
        }

        if (_infoLabel != null && _showInfo)
        {
            var output = _joystick?.Output ?? Vector2.Zero;
            _infoLabel.Text =
                $"Joystick: ({output.X:F2}, {output.Y:F2})\n" +
                $"Jump: {(_jumpButton?.IsPressed == true ? "ON" : "off")}  " +
                $"Attack: {(_attackButton?.IsPressed == true ? "ON" : "off")}  " +
                $"Dash: {(_dashButton?.IsPressed == true ? "ON" : "off")}  " +
                $"Throw: {(_throwButton?.IsPressed == true ? "ON" : "off")}";
        }
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        // Toggle info panel with F1
        if (@event is InputEventKey key && key.Pressed && key.Keycode == Key.F1)
        {
            _showInfo = !_showInfo;
            if (_infoLabel != null)
                _infoLabel.Visible = _showInfo;
        }

        // Toggle touch controls with F2
        if (@event is InputEventKey key2 && key2.Pressed && key2.Keycode == Key.F2)
        {
            if (_touchControls != null)
                _touchControls.Visible = !_touchControls.Visible;
        }
    }
}
