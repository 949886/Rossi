# Virtual Joystick Plugin for Godot 4.x (C#)

一个为 Godot 4.x + C# 设计的移动端虚拟摇杆插件，支持触摸屏操作。

## 功能特性

### VirtualJoystick 虚拟摇杆
- **三种模式**：
  - `Fixed` - 固定位置，摇杆始终在同一位置
  - `Dynamic` - 动态出现，在触摸位置生成摇杆
  - `Following` - 跟随模式，摇杆底座会跟随拇指移动
- **死区（Dead Zone）**：防止微小触摸误操作
- **钳制区（Clamp Zone）**：限制摇杆手柄的最大活动范围
- **输入动作映射**：直接映射到 Godot Input Action（如 `move_left`, `move_right`）
- **自定义外观**：支持自定义纹理或使用内置绘制样式
- **可见性模式**：始终显示 / 仅触摸时显示 / 淡入淡出

### VirtualButton 虚拟按钮
- **输入动作映射**：映射到 Godot Input Action
- **触摸反馈**：按下时缩放和颜色变化
- **自定义外观**：支持自定义纹理，内置绘制
- **标签文本**：可显示按钮文字

### TouchInputManager 触摸控制管理器
- **一键布局**：自动创建摇杆 + 按钮布局
- **桌面端自动隐藏**：可选在非移动端隐藏
- **可缩放**：通过 Scale 属性统一缩放所有控件

## 快速开始

### 方式一：使用 TouchInputManager（推荐）

最简单的方式，自动创建完整的移动控制界面：

```csharp
// 在你的场景脚本中
var touchManager = new TouchInputManager();
touchManager.MoveLeftAction = "move_left";
touchManager.MoveRightAction = "move_right";
touchManager.MoveUpAction = "move_up";
touchManager.MoveDownAction = "move_down";
touchManager.JumpAction = "jump";
touchManager.AttackAction = "attack";
touchManager.ShowJumpButton = true;
touchManager.ShowAttackButton = true;
AddChild(touchManager);
```

或者在编辑器中直接添加 `TouchInputManager` 节点并在 Inspector 中配置。

### 方式二：手动创建摇杆

```csharp
using VirtualJoystickPlugin;

// 创建摇杆
var joystick = new VirtualJoystick();
joystick.Mode = VirtualJoystick.JoystickMode.Fixed;
joystick.BaseRadius = 80f;
joystick.HandleRadius = 35f;
joystick.DeadZone = 0.2f;

// 映射到 Input Action（可选）
joystick.ActionLeft = "move_left";
joystick.ActionRight = "move_right";
joystick.ActionUp = "move_up";
joystick.ActionDown = "move_down";

// 或者通过信号手动获取输入
joystick.JoystickInput += (output) => {
    GD.Print($"Joystick: {output}");
};

// 设置位置和大小
joystick.Position = new Vector2(50, 400);
joystick.Size = new Vector2(160, 160);

AddChild(joystick);
```

### 方式三：通过信号读取输入

```csharp
// 连接信号
joystick.JoystickInput += OnJoystickInput;
joystick.JoystickPressed += OnJoystickPressed;
joystick.JoystickReleased += OnJoystickReleased;

private void OnJoystickInput(Vector2 output)
{
    // output.X: -1 (左) 到 1 (右)
    // output.Y: -1 (上) 到 1 (下)
    player.Velocity = output * MoveSpeed;
}
```

### 在 _PhysicsProcess 中直接读取

```csharp
public override void _PhysicsProcess(double delta)
{
    // 如果配置了 Input Action 映射，直接用 Godot 标准 API
    var inputDir = Input.GetVector("move_left", "move_right", "move_up", "move_down");
    Velocity = inputDir * MoveSpeed;
    MoveAndSlide();
    
    // 或者直接读取摇杆输出
    var output = joystick.Output;
    var strength = joystick.Strength;  // 0~1
    var angle = joystick.Angle;        // 弧度
}
```

## API 参考

### VirtualJoystick

| 属性 | 类型 | 说明 |
|------|------|------|
| `Mode` | `JoystickMode` | 摇杆模式 (Fixed/Dynamic/Following) |
| `Visibility` | `VisibilityMode` | 可见性模式 |
| `DeadZone` | `float` | 死区 0~1 |
| `ClampZone` | `float` | 钳制区 -1~1 |
| `TouchAreaMargin` | `float` | Dynamic/Following 模式下额外扩大的触摸响应边距（像素），默认 100 |
| `ActionLeft/Right/Up/Down` | `string` | 映射的 Input Action 名 |
| `BaseRadius` | `float` | 底座半径 |
| `HandleRadius` | `float` | 手柄半径 |
| `BaseTexture` | `Texture2D` | 自定义底座纹理 |
| `HandleTexture` | `Texture2D` | 自定义手柄纹理 |
| `Output` | `Vector2` | 【只读】当前输出向量 |
| `Strength` | `float` | 【只读】当前力度 0~1 |
| `Angle` | `float` | 【只读】当前角度（弧度） |
| `IsPressed` | `bool` | 【只读】是否按下 |

| 信号 | 参数 | 说明 |
|------|------|------|
| `JoystickInput` | `Vector2 output` | 摇杆输出变化时触发 |
| `JoystickPressed` | - | 摇杆按下 |
| `JoystickReleased` | - | 摇杆释放 |

### VirtualButton

| 属性 | 类型 | 说明 |
|------|------|------|
| `Action` | `string` | 映射的 Input Action 名 |
| `ButtonRadius` | `float` | 按钮半径 |
| `Label` | `string` | 显示文字 |
| `NormalTexture` | `Texture2D` | 常态纹理 |
| `PressedTexture` | `Texture2D` | 按下纹理 |
| `NormalColor` | `Color` | 常态颜色 |
| `PressedColor` | `Color` | 按下颜色 |

| 信号 | 说明 |
|------|------|
| `ButtonDown` | 按钮按下 |
| `ButtonUp` | 按钮释放 |

## 文件结构

```
UI/Joystick/
├── VirtualJoystick.cs              # 核心摇杆控件
├── VirtualButton.cs                # 虚拟按钮控件
├── TouchInputManager.cs            # 统一触控管理器
├── README.md                       # 本文档
└── Demo/
    ├── JoystickDemo.cs             # 演示脚本
    ├── JoystickDemo.tscn           # 演示场景
    └── JoystickCharacterExample.cs # CharacterBody2D 集成示例

addons/joystick/
├── plugin.cfg                      # Godot 插件配置
└── plugin.gd                       # 插件入口（占位）
```

## 注意事项

1. **确保启用触摸模拟**：在 Godot 编辑器中，`Project > Project Settings > Input Devices > Pointing` 下启用 `Emulate Touch From Mouse`，才能在桌面端用鼠标测试触摸。

2. **Input Action**：摇杆映射的 Action 名必须在 `Project Settings > Input Map` 中已定义，否则映射会被忽略。

3. **多点触控**：插件天然支持多指触控，摇杆和每个按钮分别追踪自己的触摸索引。

4. **性能**：所有绘制使用 Godot 的 `_Draw()` API，无额外节点开销，适合移动端。


## 改动说明 

Dynamic/Following 模式触摸区域扩大（VirtualJoystick.cs）

新增 TouchAreaMargin 属性（默认 100px），在 Inspector 中可自由设置（0~1000）
Dynamic/Following 模式的触摸检测从 GetGlobalRect() 改为 GetGlobalRect().Grow(_touchAreaMargin)，在 Control 四周各扩大指定像素的响应范围