# Virtual Joystick 文档

`UI/Joystick` 是一套面向 Godot 4 的移动端触摸控件组件，包含虚拟摇杆、普通按钮、方向按钮、带冷却/充能显示的技能按钮，以及一键生成整套触控布局的管理器。

当前目录同时提供了 `C#` 和 `GDScript` 两套实现；如果你的场景使用 C#，优先参考本文中的 C# 示例即可。

## Features

这套虚拟摇杆组件支持以下能力：

- 支持 4 种摇杆模式：`Fixed`、`Dynamic`、`Following`、`DynamicFollowing`
- 支持 3 种显示策略：`Always`、`TouchOnly`、`FadeInOut`
- 支持将摇杆输出直接映射到 Godot 的 `Input Action`
- 支持直接读取摇杆 `Output / Strength / Angle`
- 支持多点触控，摇杆和按钮各自追踪自己的触摸索引
- 支持纯绘制样式，也支持自定义纹理贴图
- 支持普通按钮、方向按钮、技能冷却按钮
- 支持通过 `TouchInputManager` 一键生成移动端触控 UI
- 提供了完整 Demo，可直接参考场景搭建方式

## 目录结构

```text
UI/Joystick/
├── VirtualJoystick.cs              # 核心虚拟摇杆
├── VirtualButton.cs                # 普通虚拟按钮
├── VirtualDirectionButton.cs       # 方向按钮
├── VirtualProgressButton.cs        # 带冷却/充能显示的技能按钮
├── TouchInputManager.cs            # 一键创建触控布局
├── README.md                       # 本文档
└── Demo/
    ├── JoystickDemo.cs
    ├── JoystickCharacterExample.cs
    ├── PlatformerJoystickDemo.cs
    └── *.tscn
```

## 快速上手

### 1. 配置 Input Map

如果你希望摇杆和按钮直接驱动游戏输入，先在 `Project Settings > Input Map` 中配置动作，例如：

- `move_left`
- `move_right`
- `move_up`
- `move_down`
- `jump`
- `attack`
- `dash`

如果没有定义这些 `Action`，组件不会报错，但对应输入映射会被忽略。

### 2. 最简单的接入方式：TouchInputManager

`TouchInputManager` 适合快速接入，它会自动创建：

- 左侧摇杆区域
- 右侧按钮区域
- 跳跃/攻击/冲刺按钮

示例：

```csharp
using Godot;
using VirtualJoystickPlugin;

public partial class MobileHudBootstrap : Node
{
    public override void _Ready()
    {
        var touchManager = new TouchInputManager
        {
            MoveLeftAction = "move_left",
            MoveRightAction = "move_right",
            MoveUpAction = "jump",
            MoveDownAction = "move_down",
            JumpAction = "jump",
            AttackAction = "attack",
            DashAction = "dash",
            ShowJumpButton = true,
            ShowAttackButton = true,
            ShowDashButton = true,
            ControlScale = 1.0f
        };

        AddChild(touchManager);
    }
}
```

### 3. 手动创建摇杆

如果你想完全控制布局，可以直接实例化 `VirtualJoystick`：

```csharp
using Godot;
using VirtualJoystickPlugin;

public partial class ManualJoystickExample : CanvasLayer
{
    public override void _Ready()
    {
        var joystickArea = new Control();
        joystickArea.SetAnchorsPreset(Control.LayoutPreset.BottomLeft);
        joystickArea.Size = new Vector2(300, 300);
        joystickArea.Position = new Vector2(20, -320);
        joystickArea.MouseFilter = Control.MouseFilterEnum.Ignore;
        AddChild(joystickArea);

        var joystick = new VirtualJoystick
        {
            Mode = VirtualJoystick.JoystickMode.Fixed,
            Visibility = VirtualJoystick.VisibilityMode.FadeInOut,
            BaseRadius = 80f,
            HandleRadius = 35f,
            DeadZone = 0.15f,
            ClampZone = 1.0f,
            ActionLeft = "move_left",
            ActionRight = "move_right",
            ActionUp = "move_up",
            ActionDown = "move_down",
            Position = new Vector2(70, 70),
            Size = new Vector2(160, 160)
        };

        joystick.JoystickInput += output => GD.Print($"Joystick output: {output}");
        joystickArea.AddChild(joystick);
    }
}
```

### 4. 在角色控制中读取输入

推荐优先走 `Input Action` 方案，这样键盘、手柄、虚拟摇杆可以共用同一套输入逻辑。

示例参考 `Demo/JoystickCharacterExample.cs`：

```csharp
public override void _PhysicsProcess(double delta)
{
    float dt = (float)delta;
    var vel = Velocity;

    if (!IsOnFloor())
    {
        vel.Y += Gravity * dt;
    }

    float inputX = Input.GetAxis("move_left", "move_right");

    if (Mathf.Abs(inputX) > 0.01f)
    {
        vel.X = Mathf.MoveToward(vel.X, inputX * MoveSpeed, Acceleration * dt);
    }
    else
    {
        vel.X = Mathf.MoveToward(vel.X, 0, Friction * dt);
    }

    if (Input.IsActionJustPressed("jump") && IsOnFloor())
    {
        vel.Y = JumpVelocity;
    }

    Velocity = vel;
    MoveAndSlide();
}
```

如果你不想经过 `Input Map`，也可以直接读取摇杆输出：

```csharp
float inputX = Joystick?.Output.X ?? 0f;
float strength = Joystick?.Strength ?? 0f;
float angle = Joystick?.Angle ?? 0f;
```

## 核心组件详解

## 1. VirtualJoystick

### 作用

`VirtualJoystick` 是整个系统的核心，用来把触摸拖拽转换为二维方向输入。

它提供两种主要使用方式：

- 作为 `Input Action` 输入源，驱动 `move_left / move_right / jump` 等动作
- 作为直接数据源，读取 `Output`、`Strength`、`Angle`

### 工作机制

当用户触摸控件后，摇杆会：

1. 记录当前手指的触摸索引
2. 根据模式决定底座位置是否固定或动态生成
3. 计算手柄相对底座的位置
4. 按 `ClampZone` 限制最大位移
5. 按 `DeadZone` 过滤微小输入
6. 输出归一化 `Vector2`
7. 可选地同步到 `InputMap`

### 摇杆模式

#### `Fixed`

- 摇杆固定在场景中的初始位置
- 只有点中底座圆形区域才会激活
- 适合传统左下角固定摇杆

#### `Dynamic`

- 在可触发区域内任意位置触摸时生成摇杆中心
- 更适合大屏设备，容错更高

#### `Following`

- 初始触摸后，如果手指拖拽超过限制范围，底座会跟随手指移动
- 适合需要更大操作幅度的场景

#### `DynamicFollowing`

- 先像 `Dynamic` 一样在触点生成
- 再像 `Following` 一样在超出范围时跟随手指
- 是最灵活的一种模式

### 重要属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `Mode` | `JoystickMode` | 摇杆行为模式 |
| `Visibility` | `VisibilityMode` | 显示模式 |
| `DeadZone` | `float` | 死区，低于该强度时输出 `Vector2.Zero` |
| `ClampZone` | `float` | 手柄允许移动的最大比例 |
| `TouchAreaMargin` | `float` | 动态模式额外可触发边距 |
| `ActionLeft/Right/Up/Down` | `string` | 对应的 Godot 输入动作 |
| `BaseRadius` | `float` | 底座半径 |
| `HandleRadius` | `float` | 手柄半径 |
| `BaseTexture` | `Texture2D` | 底座纹理 |
| `HandleTexture` | `Texture2D` | 手柄纹理 |
| `BaseColor` | `Color` | 底座颜色或纹理染色 |
| `HandleColor` | `Color` | 默认手柄颜色 |
| `HandlePressedColor` | `Color` | 按下时手柄颜色 |
| `InactiveOpacity` | `float` | `FadeInOut` 下未按下透明度 |
| `ActiveOpacity` | `float` | `FadeInOut` 下按下透明度 |

### 常用只读属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `Output` | `Vector2` | 当前输出，范围通常为 `-1 ~ 1` |
| `Strength` | `float` | 当前力度，范围 `0 ~ 1` |
| `Angle` | `float` | 当前方向角，单位为弧度 |
| `IsPressed` | `bool` | 当前是否被按下 |
| `EffectiveBaseRadius` | `float` | 基于控件尺寸换算后的实际底座半径 |
| `EffectiveHandleRadius` | `float` | 基于控件尺寸换算后的实际手柄半径 |

### 信号

| 信号 | 参数 | 说明 |
|---|---|---|
| `JoystickInput` | `Vector2 output` | 摇杆输出变化时触发 |
| `JoystickPressed` | 无 | 手指开始控制摇杆时触发 |
| `JoystickReleased` | 无 | 手指离开时触发 |

### 使用案例 1：驱动角色移动

```csharp
using Godot;
using VirtualJoystickPlugin;

public partial class PlayerController : CharacterBody2D
{
    [Export] public VirtualJoystick Joystick { get; set; }
    [Export] public float MoveSpeed { get; set; } = 220f;

    public override void _PhysicsProcess(double delta)
    {
        float inputX = Joystick?.Output.X ?? Input.GetAxis("move_left", "move_right");
        Velocity = new Vector2(inputX * MoveSpeed, Velocity.Y);
        MoveAndSlide();
    }
}
```

### 使用案例 2：监听方向和力度

```csharp
public override void _Ready()
{
    var joystick = GetNode<VirtualJoystick>("CanvasLayer/Joystick");

    joystick.JoystickInput += output =>
    {
        GD.Print($"output={output}, strength={output.Length():F2}, angle={output.Angle():F2}");
    };
}
```

### 使用建议

- 角色移动优先用 `Input.GetAxis` 或 `Input.GetVector` 读取，这样桌面端和移动端逻辑统一
- `DeadZone` 建议从 `0.15 ~ 0.25` 之间调
- `Dynamic` 或 `Following` 模式下，建议适当增大 `TouchAreaMargin`
- 如果控件放在复杂 UI 上层，父节点建议设置 `MouseFilter = Ignore`

## 2. VirtualButton

### 作用

`VirtualButton` 是最基础的移动端虚拟按键，适合处理：

- 跳跃
- 攻击
- 交互
- 技能释放

按下时它会主动调用 `Input.ActionPress(Action)`，松开时调用 `Input.ActionRelease(Action)`。

### 重要属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `Action` | `string` | 要映射的输入动作名 |
| `ButtonRadius` | `float` | 按钮半径 |
| `Label` | `string` | 按钮中央文字 |
| `LabelFontSize` | `int` | 文字字号 |
| `NormalTexture` | `Texture2D` | 默认纹理 |
| `PressedTexture` | `Texture2D` | 按下纹理 |
| `NormalColor` | `Color` | 默认颜色 |
| `PressedColor` | `Color` | 按下颜色 |
| `IconColor` | `Color` | 文本颜色 |
| `PressedScale` | `float` | 按下时缩放比例 |

### 信号

| 信号 | 说明 |
|---|---|
| `ButtonDown` | 按下时触发 |
| `ButtonUp` | 松开时触发 |

### 使用案例：跳跃按钮

```csharp
using Godot;
using VirtualJoystickPlugin;

public partial class JumpButtonExample : CanvasLayer
{
    public override void _Ready()
    {
        var jumpButton = new VirtualButton
        {
            Name = "JumpButton",
            Action = "jump",
            Label = "J",
            ButtonRadius = 48f,
            PressedColor = new Color(0.3f, 0.6f, 0.9f, 0.9f),
            Size = new Vector2(96, 96),
            Position = new Vector2(900, 500)
        };

        jumpButton.ButtonDown += () => GD.Print("jump down");
        jumpButton.ButtonUp += () => GD.Print("jump up");

        AddChild(jumpButton);
    }
}
```

### 适用场景

- 单击触发型技能
- 需要和 Godot 输入系统保持一致的动作
- 只需要“按下/松开”状态，不需要方向信息

## 3. VirtualDirectionButton

### 作用

`VirtualDirectionButton` 适合“按住决定方向，松手触发”的交互，例如：

- 投掷
- 蓄力发射
- 指向施法
- 朝向型技能

它和普通按钮最大的区别是：它会记录拖拽方向，并通过 `DirectionActivated(float angle)` 把角度传出去。

### 工作方式

- 按下按钮时开始记录当前触点方向
- 拖动手指时更新 `_currentAngle`
- 当手指拖到按钮边缘，或松开按钮时，触发 `DirectionActivated`

### 重要属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `ButtonRadius` | `float` | 按钮半径 |
| `ArcColor` | `Color` | 方向弧线颜色 |
| `ArcWidth` | `float` | 方向弧线宽度 |
| `ArcSpread` | `float` | 方向弧显示张角 |
| `Label` | `string` | 按钮文字 |
| `PressedScale` | `float` | 按下时缩放比例 |

### 信号

| 信号 | 参数 | 说明 |
|---|---|---|
| `DirectionActivated` | `float angle` | 松手或拖出边界时触发 |
| `ButtonDown` | 无 | 按下时触发 |

### 使用案例：投掷方向按钮

`Demo/PlatformerJoystickDemo.cs` 中已经有真实接法：

```csharp
public override void _Ready()
{
    var throwButton = GetNode<VirtualDirectionButton>("TouchUI/TouchControls/ButtonArea/ThrowBtn");
    var player = GetNode<PlatformerCharacterController2D>("Playground/CharacterBody2D");

    throwButton.DirectionActivated += player.OnVirtualThrowActivated;
}
```

如果你想自己处理角度：

```csharp
throwButton.DirectionActivated += angle =>
{
    Vector2 dir = Vector2.Right.Rotated(angle);
    GD.Print($"Throw dir = {dir}, angle = {angle}");
};
```

### 适用场景

- 释放瞬间需要方向
- 需要一个“瞄准确认”的按钮，而不是持续移动输入
- 想避免额外再放一个右摇杆

## 4. VirtualProgressButton

### 作用

`VirtualProgressButton` 是一个“技能按钮 UI + 输入按钮”的组合体，适合：

- 有冷却时间的技能
- 有充能层数的技能
- 想在按钮本体上直接显示可用状态

### 它多做了什么

相比 `VirtualButton`，它增加了两类表现：

- 冷却环：`CooldownProgress`
- 充能点：`ChargeCount / MaxChargeCount`

当 `ChargeCount == 0` 且 `CooldownProgress > 0` 时，按钮会绘制冷却覆盖效果和进度环。

### 重要属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `Action` | `string` | 输入动作 |
| `CooldownProgress` | `float` | 冷却进度，`0` 表示可用，`1` 表示刚进入冷却 |
| `CooldownColor` | `Color` | 冷却环颜色 |
| `CooldownRingWidth` | `float` | 冷却环宽度 |
| `ChargeCount` | `int` | 当前可用层数 |
| `MaxChargeCount` | `int` | 最大层数 |
| `ChargeDotColor` | `Color` | 充能点颜色 |
| `ChargeDotRadius` | `float` | 充能点半径 |
| `ChargeDotSpacing` | `float` | 充能点间距 |
| `ChargeDotOffset` | `Vector2` | 充能点相对按钮偏移 |

### 信号

| 信号 | 说明 |
|---|---|
| `Pressed` | 完整点击后触发 |
| `ButtonDown` | 按下时触发 |
| `ButtonUp` | 松开时触发 |

### 使用案例：冲刺技能按钮

`Demo/PlatformerJoystickDemo.cs` 的更新方式如下：

```csharp
public override void _Process(double delta)
{
    if (_player != null && _dashButton != null)
    {
        _dashButton.ChargeCount = _player.DashCharges;
        _dashButton.MaxChargeCount = _player.MaxDashCharges;
        _dashButton.CooldownProgress = _player.DashRechargeProgress;
    }
}
```

你也可以单独使用：

```csharp
var dashButton = new VirtualProgressButton
{
    Action = "dash",
    Label = "D",
    ButtonRadius = 52f,
    MaxChargeCount = 3,
    ChargeCount = 2,
    CooldownProgress = 0.35f,
    Size = new Vector2(104, 104)
};

dashButton.Pressed += () => GD.Print("dash triggered");
```

### 适用场景

- MOBA / ARPG 技能按钮
- 冲刺、闪现、翻滚等有限次数技能
- 想把“输入”和“状态显示”做在同一个控件里

## 5. TouchInputManager

### 作用

`TouchInputManager` 是一个 `CanvasLayer`，用于快速生成一套可用的移动端触控布局。

它会自动创建：

- `TouchControls` 根容器
- 左下角 `JoystickArea`
- 右下角 `ButtonArea`
- 对应的摇杆和按钮实例

这意味着你不需要手动摆放多个控件，适合原型开发和通用项目模板。

### 重要属性

| 属性 | 类型 | 说明 |
|---|---|---|
| `AutoHideOnDesktop` | `bool` | 是否在非移动平台自动隐藏 |
| `ControlScale` | `float` | 整体 UI 缩放 |
| `JoystickMode` | `JoystickMode` | 摇杆模式 |
| `JoystickVisibility` | `VisibilityMode` | 摇杆可见性 |
| `MoveLeftAction` | `string` | 左移动作 |
| `MoveRightAction` | `string` | 右移动作 |
| `MoveUpAction` | `string` | 上方向动作，默认映射到 `jump` |
| `MoveDownAction` | `string` | 下方向动作 |
| `ShowJumpButton` | `bool` | 是否创建跳跃按钮 |
| `JumpAction` | `string` | 跳跃动作 |
| `ShowAttackButton` | `bool` | 是否创建攻击按钮 |
| `AttackAction` | `string` | 攻击动作 |
| `ShowDashButton` | `bool` | 是否创建冲刺按钮 |
| `DashAction` | `string` | 冲刺动作 |

### 公开 API

| 成员 | 说明 |
|---|---|
| `Joystick` | 直接访问内部创建的 `VirtualJoystick` |
| `JoystickOutput` | 读取当前摇杆输出 |
| `SetControlsVisible(bool)` | 运行时整体显示/隐藏触控控件 |

### 信号

| 信号 | 参数 | 说明 |
|---|---|---|
| `JoystickInputChanged` | `Vector2 output` | 内部摇杆输出变化时转发 |

### 使用案例：快速创建移动端 HUD

```csharp
using Godot;
using VirtualJoystickPlugin;

public partial class MainScene : Node2D
{
    private TouchInputManager _touchInput;

    public override void _Ready()
    {
        _touchInput = new TouchInputManager
        {
            AutoHideOnDesktop = false,
            ControlScale = 1.2f,
            JoystickMode = VirtualJoystick.JoystickMode.DynamicFollowing,
            JoystickVisibility = VirtualJoystick.VisibilityMode.FadeInOut,
            MoveLeftAction = "move_left",
            MoveRightAction = "move_right",
            MoveUpAction = "jump",
            JumpAction = "jump",
            ShowAttackButton = true,
            AttackAction = "attack",
            ShowDashButton = true,
            DashAction = "dash"
        };

        _touchInput.JoystickInputChanged += output =>
        {
            GD.Print($"Current joystick output: {output}");
        };

        AddChild(_touchInput);
    }
}
```

### 适用场景

- 快速做 Demo
- 临时给 PC 项目补一套移动端操作层
- 不想手动摆 UI，但又希望立刻可玩

## 组件之间如何配合

一套常见的移动端操作链路通常是：

1. `VirtualJoystick` 负责持续输出移动方向
2. `VirtualButton` 负责跳跃、攻击等离散输入
3. `VirtualDirectionButton` 负责投掷、瞄准施法
4. `VirtualProgressButton` 负责有冷却和充能的技能
5. `TouchInputManager` 负责把这些控件组织成一套布局

在项目里的实际示例可以参考：

- [VirtualJoystick.cs](Z:\Programming\Game\Godot\Learning\demos\UI\Joystick\VirtualJoystick.cs)
- [VirtualButton.cs](Z:\Programming\Game\Godot\Learning\demos\UI\Joystick\VirtualButton.cs)
- [VirtualDirectionButton.cs](Z:\Programming\Game\Godot\Learning\demos\UI\Joystick\VirtualDirectionButton.cs)
- [VirtualProgressButton.cs](Z:\Programming\Game\Godot\Learning\demos\UI\Joystick\VirtualProgressButton.cs)
- [TouchInputManager.cs](Z:\Programming\Game\Godot\Learning\demos\UI\Joystick\TouchInputManager.cs)
- [JoystickCharacterExample.cs](Z:\Programming\Game\Godot\Learning\demos\UI\Joystick\Demo\JoystickCharacterExample.cs)
- [PlatformerJoystickDemo.cs](Z:\Programming\Game\Godot\Learning\demos\UI\Joystick\Demo\PlatformerJoystickDemo.cs)

## 推荐接入方式

### 方案 A：项目已经基于 Input Map 开发

推荐直接把摇杆和按钮映射到已有的 `Action`：

- 优点是键盘、手柄、触屏逻辑统一
- 角色脚本几乎不用改
- 更适合跨平台项目

### 方案 B：你希望 UI 逻辑和输入逻辑分离

直接读取组件状态：

- `VirtualJoystick.Output`
- `VirtualButton.IsPressed`
- `VirtualProgressButton.Pressed`
- `VirtualDirectionButton.DirectionActivated`

这种方式更适合特殊技能或复杂战斗系统。

## 调试与注意事项

### 1. PC 上测试触摸

在 Godot 中可以开启：

- `Project Settings > Input Devices > Pointing > Emulate Touch From Mouse`

这样在桌面端也能模拟触摸操作。

### 2. Input Action 没反应

优先检查：

- `Project Settings > Input Map` 是否存在对应动作
- 传入的动作名是否拼写一致
- 是否有别的脚本在同一帧覆盖输入状态

### 3. Dynamic / Following 模式不好按

调大 `TouchAreaMargin`。

该值会把 `GetGlobalRect()` 向外扩展，让动态摇杆拥有更大的可触发区域。

### 4. 控件层级问题

建议把这些控件放在 `CanvasLayer` 或 HUD 层，并确保父级 `Control` 不会吞掉触摸事件。项目中的示例普遍使用：

```csharp
control.MouseFilter = Control.MouseFilterEnum.Ignore;
```

### 5. 组件销毁时输入释放

`VirtualJoystick`、`VirtualButton`、`VirtualProgressButton` 都做了基础清理逻辑，节点删除时会尽量释放已经按下的输入动作，避免残留“卡住按键”的问题。

## Demo 参考

建议优先看下面两个示例：

- [JoystickCharacterExample.cs](Z:\Programming\Game\Godot\Learning\demos\UI\Joystick\Demo\JoystickCharacterExample.cs)
  说明如何把摇杆接入 `CharacterBody2D`
- [PlatformerJoystickDemo.cs](Z:\Programming\Game\Godot\Learning\demos\UI\Joystick\Demo\PlatformerJoystickDemo.cs)
  说明如何把摇杆、普通按钮、方向按钮、技能按钮组合成完整玩法

如果你后面愿意，我还可以继续帮你补两部分内容：

- 一份“Inspector 参数对照表”，适合给策划/美术直接配
- 一份“GDScript 版本示例文档”，对应当前目录下的 `.gd` 实现
