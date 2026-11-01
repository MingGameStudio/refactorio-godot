# 转弯传送带回归检查

在项目根目录运行（把 godot 替换为本机 Godot 可执行文件路径）：

    godot --headless --path . --script tests/test_corners.gd

检查八种有向 90° 转弯、入口/出口位置、货物跨格连续性、相向传送带、
顺时针旋转，以及修改/删除上游后的可视节点刷新。失败时返回退出码 1。

渲染八种弯道并保存 tests/corners-preview.png：

    godot --path . --rendering-method gl_compatibility --resolution 900x600 --script tests/test_corners.gd -- --preview

游戏内：左键拖动铺设 L 形路径，松开后自动生成弯道；单击控制人物移动，不放置或旋转传送带，
右键删除。多个上游汇入时，优先保留正后方的直线输入，否则选择一个侧向输入；
当前尚未实现专门的合流建筑。

实现使用原始 BeltRing.png：遮罩固定在圆心朝向格子内部的象限，
仅旋转纹理采样；逆时针转弯镜像箭头。径向映射让环的中心线和宽度匹配直线带。

## 人物移动

Worker.tscn 可在场景编辑器中调整初始位置，Worker.gd 的 move_speed 可在 Inspector 中调整。
人物使用 WorkerWalk.png 的四帧行走动画，静止时切换至 WorkerIdle.png。
WASD 控制八方向连续移动，斜向等速，松手可停在任意位置；按 WASD 会取消原先点击路线及待执行拾取/投料。
鼠标点击仍使用 AStarGrid2D，从当前任意位置寻路到目标格中心。
两种控制均通过 CharacterBody2D 的 MOTION_MODE_FLOATING 和 move_and_slide() 移动，沿障碍边缘滑动。
人物脚底圆形碰撞体在 Worker.tscn 配置。设施为物理层 1，人物为层 2、检测层 1；碰撞体不接管鼠标点击。
GridCollision.gd 从统一占用表同步设施碰撞和地图边界，机器、输入带、普通传送带不可通行，油污及警戒线等装饰不阻挡。
新增或移动设施时禁止与人物脚底碰撞体重叠（包括人物跨格边缘的情况）。

    godot --headless --path . --script tests/test_worker.gd

检查点击与拖拽分流、地图外释放、移动、转向和到达后切换 Idle、静止时不重置动画进度。
添加 -- --preview 可在有图形渲染的运行中输出 tests/worker-preview.png。
## 箱子拾取

Main 场景的 Box 节点是可点击箱子，可以在编辑器中调整位置。
单击箱子后，人物走到箱子左右较近的一侧，距离 32 像素时拾取；
途中点击其他地面会取消拾取。拖动箱子不会触发拾取或铺设。
拾取后地面箱子隐藏，人物手边显示箱子，使用 hold_idle / hold_walk。
WASD 走到箱子附近（48 像素内且未被设施隔开）时显示 E 拾取箱子，可直接按 E 拾取。
持箱走到 S1 输入带左侧格、距离输入带中心不超过 72 像素时显示 E 投料；按 E 自动朝右并投放，无需对齐格心。
从其他方向或远处按 E 不投放，也不自动寻路。鼠标点击拾取和投料仍保留；空手靠近点焊机仍用 E 操作。
WorkerHoldIdle.png 为单帧姿势，WorkerHoldWalk.png 为四帧动画。
搬箱后点击上料台输入带，工人寻路到输入带左侧并朝右投放，箱子进入机器后增加 10 点容量。
test_worker.gd 同时检查拾取距离、取消拾取、持箱动画和左右朝向。

## 点焊机

Main.tscn 中的 WeldingMachine 位于 (6, 4)，替换原有一格传送带。
机器显示高度与其他机器一致，为 1.95 格，逻辑占用一格。左侧接收朝右输送的电芯，缓存最多两个。
工人空手靠近机器（距格心不超过 68 像素）显示按住 E 操作；按下并保持 E 两秒完成加工。
松开 E、失去窗口焦点或离开范围取消并保留原料；返回不会自动重启。完成后消耗两个电芯，生成一个电池组件。
右侧必须有传送带且出口无物品才能输出；否则成品留在机器内，禁止再次开工。

- 编辑器：移动或复制 WeldingMachine.tscn 实例，放在 BuildingLayer 下并对齐 64 像素网格。
- 游戏中：鼠标指向空格按 B 放置；指向点焊机按 M，再点击空格移动，Esc 取消。W 用于人物移动。
- 右键拆除空机器；有原料、成品或正在加工时不允许拆除，以免丢失物品。移动会取消加工，但库存随机器保留。
- WeldingMachine.gd 管理加工和库存，WeldingInteraction.gd 单独管理玩家距离、提示和按键。未来 AI 可调用 begin_operation/advance_operation 接口。

    godot --headless --path . --script tests/test_welding.gd

测试覆盖输入方向和种类、满载阻塞、E 重复按键、两秒加工、离开取消、出口堵塞、库存保护、移动/拆除以及整条生产线的原料守恒（10 电芯 → 5 电池组件）。
test_machine_feeding.gd 临时把点焊机位置恢复为传送带，只验证原有上料台产出十个电芯的功能。

## 自由移动与碰撞回归

    godot --headless --path . --script tests/test_free_movement.gd

检查八方向等速、任意坐标停留、设施阻挡、沿边滑动、地图边界、点击/手动切换、动态增删/移动碰撞体、禁止在人身上建造及搬箱动画。
人物相关测试使用 physics_steps.gd 等待真实物理帧，以验证 move_and_slide，而非用一次大 delta 跳到终点。

    godot --headless --path . --script tests/test_e_interaction.gd

检查 E 就近拾取、隔墙拒绝、任意坐标左侧投放、自动朝右、重复按键不重复上料，以及 E 点焊兼容。

## 点焊火花

WeldingMachine.tscn 的 SparkOrigin 对齐焊接窗口中心，其下 WeldingSparks 和 CompletionSparks 是固定的 GPUParticles2D 节点。
普通火花每次 8 粒，大小 6–9 像素，寿命约 0.224–0.28 秒；完成火花 18 粒，大小 6–10.5 像素，寿命约 0.28–0.4 秒。
内置 6×6 白色 GradientTexture2D 和 ParticleProcessMaterial 生成白→黄→橙红→透明的小方块；无外部粒子图片。
Inspector 可调整两个发射器的 amount、lifetime、速度、尺寸和颜色梯度，以及机器的 spark_interval（默认 0.30 秒）。
火花直接由 begin_operation、advance_operation 的真实加工状态触发，不使用独立输入检测或加工 Timer；取消后不再触发，但已发射粒子自然消失。
机器 Sprite 本身有烘焙火花；动态粒子提高飞散速度并延长明亮阶段，使普通爆发覆盖约 30–75 像素半径，完成爆发可达约 112 像素，不增加光晕。

    godot --headless --path . --script tests/test_welding_sparks.gd

可选 GPU 渲染预览（保存普通/完成两张 PNG）：

    godot --path . --rendering-method gl_compatibility --resolution 1152x768 --script tests/test_welding_sparks.gd -- --preview

## 操作音效

五个 WAV 通过场景内固定 AudioStreamPlayer 播放，统一送入 SFX 总线；背景音乐仍使用 Master。
Worker/PickupSound 与 Main/BuildingLayer/SourceMachine/InsertSound 在成功拾箱、投料时播放（-6 dB）。
WeldingMachine/PulseSound（-10 dB）与普通火花共用触发函数，CompleteSound（-6 dB）仅在加工完成时播放。
Main/ShipmentSound（-10 dB）在 score 增加的结算分支播放，进入发货格时不播放。
所有节点的 Volume dB、Pitch Scale 和 Bus 可在 Inspector 调整；Max Polyphony 为 1，防止重复脉冲叠加。

    godot --headless --path . --script tests/test_sfx.gd

检查失败操作静音、成功操作播放、重复调用不重播、火花间隔/取消/完成/下一轮加工，以及发货进入与实际结算的区别。
手动试听：拾箱投料、按住 E 点焊并中途松开、完成下一轮加工、等待产品结算；确认音效与事件同步、相对背景音乐音量适中。
