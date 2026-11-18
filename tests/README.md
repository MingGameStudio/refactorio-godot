# 发货机装箱

Main/BuildingLayer/SinkMachine 使用 PackingMachine.gd。电池组沿现有传送带进入发货格，到达后调用 accept_battery，battery_count 每个只加一，PackingProgress 显示 0/5～5/5。满五个后由 try_pack 请求在右侧 (10, 4) 输出格创建一个 PackedBox；成功才扣除五个。输出格必须有传送带，且没有散件、可见箱子或人物；堵塞时保留 5/5，后续电池组等待，不重复计数。每次生产 Tick 重试，解除堵塞后仅生成一箱。

成品箱复用 BoxFront.png、Worker 的持箱动画、拾取音效和 E/鼠标拾取；PackedBox.gd 提供从可达邻格拾取带面箱子的接口。Main 统一查找原料箱和成品箱。按 Q 放到面前相邻空地（或未占用的装箱输出带），复用同一箱子节点，箱内五个电池组及类型元数据不变。对话锁定、格子占用或出界时拒绝放下。成品箱不会自动随传送带移动；右侧出货口接入 E 发货，见下文。SourceMachine 拒绝 battery_crate，避免把成品箱重新变成原料。

**仅将装箱机生成的成品箱交到右侧出货口时加 1 分。** 电池组进入机器、装箱、拾取及普通地面放下均不计分。携带成品箱站在出货口内侧 (11, 4) 格、面向右侧按 E，显示“E 发货（+1）”。校验 packed_boxes 注册、PackedBox 脚本、battery_crate 类型及五个电池组内容；原料箱或未注册箱子拒绝发货并保留在手中。成功后先清除持箱和注册状态，再从场景移除箱子，更新 ScoreLabel 并播放 ShipmentSound；重复按键不会重复计分。

    godot --headless --path . --script tests/test_packing.gd
    godot --path . --rendering-method gl_compatibility --resolution 1152x648 --script tests/test_packing.gd -- --preview

覆盖五个装一箱、输出堵塞连续重试、后续原料等待、解堵后单次输出、点击/E 拾取、Q 放下再拾取、禁止重复放下、禁止成品投料和分数不重复增加。预览 tests/packing-preview.png 展示已输出一箱、下一批 5/5 堵塞等待的状态。

# 模块化车间墙壁

Main.tscn 实例化 WorkshopWalls.tscn；编辑器与运行时均由 WorkshopWalls.gd 按网格生成三面墙，下方不生成墙壁。Inspector 可设置 Grid Size、Cell Size、Inlet Row、Outlet Row；Main 启动时使用实际地板尺寸及现有输入带、终点机所在行覆盖配置。

墙体位于 768×512 地板外缘，不占用建造网格。直墙按一格墙厚等比缩放后重复，末段通过 Sprite2D.region_rect 裁切。门宽三格，货口高两格，右口水平镜像；所有 Sprite 保持宽高比。相机按墙体与货口实际外缘计算最紧取景，在完整显示车间的前提下等比放大，底部贴齐窗口；HUD 叠在场景上，不额外留白，宽高比不一致时保留必要的侧边或顶部空隙。

ExitApproach、InletApproach、OutletApproach 提供出入口定位。现有流程只有 Intro → Main，没有返回仓库并保留工厂状态的逻辑，所以顶部出口不触发场景切换。入料箱位于地图外 (-1, 4) 格，脚底坐标 (-32, 288)，通过 InletBox.gd 提供特殊拾取接口：人物在内侧 (0, 4) 格按 E 取料，或点击箱子寻路到内侧格中心后拾取。仅该入口箱子允许跨地图边界拾取，仍检查内侧设施遮挡、距离、对话锁和持箱状态；地图外不能走入、铺带或拆除。箱子移回地图内时恢复普通地面拾取规则。不自动补货；出货口支持成品箱 E 发货。上料机容量、点焊缓存及传送带逻辑保持原状。人物继续使用 GridCollision 的四边边界（下方只有不可见地图边界，没有墙壁 Sprite）。

    godot --headless --path . --script tests/test_inlet_pickup.gd

验证地图外点击寻路拾取、内侧 E 拾取与投料、隔行/远距离/对话/设施遮挡拒绝，以及人物仍不能走出地图。

    godot --headless --path . --script tests/test_workshop_walls.gd
    godot --path . --rendering-method gl_compatibility --resolution 1152x768 --script tests/test_workshop_walls.gd -- --preview

检查多种网格大小、等比缩放、末段裁切、无下墙、无地板侵占、货口行对齐和重复重建。预览保存到 tests/workshop-walls-preview.png。手动 F6 运行 Main.tscn，调整窗口宽高，检查三面墙完整可见；WASD/Shift 靠墙、E 拾箱投料和点焊继续使用原有交互。

# Intro 仓库场景

徐知夏配音使用 DialogueUI/Voice 独立 AudioStreamPlayer，每句通过 voice: AudioStream 显式关联资源。开场为 Intro00；成功分支为 Intro01、Intro02、主角静音、Intro06；未整理分支为 Intro03、主角静音、Intro04、Intro05、主角静音、Intro06。
换句先停止上一句，关闭、隐藏或移除 UI 也停止语音；语音播完仍等待点击/空格，不自动推进。不操作背景音乐或 SFX 播放器，音量可在 DialogueUI.tscn 的 Voice 节点调整。

    godot --headless --path . --script tests/test_dialogue_voice.gd

配合 test_intro_branches.gd 验证实际分支的音频引用、播放状态、主角静音及 Main 切换。手动试听：F5 分别走成功和未整理分支，快速换句检查无重叠，停留一句直到语音结束确认 UI 不自动推进。

剧情状态：INTRO → WALKING → BRANCH_DIALOGUE → TASK_STARTED。放回箱子成功后立即进入成功分支（4 句）；未放回时进入右端 WorkshopEntrance 区域则进入未整理分支（6 句），包括仍拿着箱子的情况。两个分支只选一次，对话期间锁定移动和拾放、停止跟随并朝向玩家。分支结束进入 TASK_STARTED，自动加载 Main.tscn。

手动测试（每种情况重新 F5）：
- 成功：结束开场，靠近散落箱子按 E 拾取，到上方中间托盘缺口按 E 放回，立即出现“看来我的眼光不错……”；推进全部 4 句后进入 Main。
- 未整理：结束开场，不放回箱子，沿通道走到最右端，出现“厂长先生，刚才地上那个箱子，你就这么放过它了？”；推进全部 6 句后进入 Main。
- 拿起未放回：拾取后直接向右走到通道末端，应同样进入未整理分支。

    godot --headless --path . --script tests/test_intro_branches.gd

自动检查三个场景、逐句原文、状态转换、互斥、防按键重复、对话锁定和 Main 实际加载。

徐知夏在开场结束后启用跟随，默认与玩家保持约 52 像素距离；走近时减速，玩家靠得过近时退让。沿用 FemaleAssistant 节点、FemaleAssistantWalk.tres、FemaleCharacterIdle 图片及 GridDepth 排序，Walk/Idle 尺寸和脚底基准一致。只有左右素材，竖直走动保留最近的水平朝向。
DialogueUI.active_changed 会让她停下并面向玩家；对话结束后按 follow_enabled 剧情状态恢复。可在 FemaleAssistant 的 Inspector 调整 Follow Distance、Minimum Distance 和 Move Speed。使用简单直线跟随和脚底碰撞扫掠，遇托盘阻挡时停步，不自动绕路。

    godot --headless --path . --script tests/test_assistant_follow.gd

手动验证：F5 结束开场后，按 D 前进、停下、左右转向并走近徐知夏，观察跟随间距、朝向和 Walk/Idle；再拾取并放回地面箱子，确认交互保持正常。

F5 启动项目或打开 Intro.tscn 后按 F6，自动播放新厂长与徐知夏的两句开场对话。期间通过 Worker 现有输入锁禁止移动，不暂停场景树。鼠标左键完整点击或 Space 推进；结束后显示“按 WASD 向右移动，前往生产车间。”并进入 WALKING，等待整理箱子或到达右端触发分支。
走近散落箱子会显示 E 拾取箱子，按 E 沿用 Worker 的 48 像素距离、遮挡检查、持箱动画与音效；拾取后移除地面箱子碰撞，手持图片换为 assets/Boxes/BoxFront.png，保持原手持宽度并等比缩放。场景沿用现有资源，参考图中的灯光、大门和管线因无对应素材省略。
FloorLayer、DecorationLayer、Walkway、Cargo、FemaleAssistant、Worker 均为可编辑场景节点。上下各五组托盘，上排中间为五箱托盘，另有一个斜放单箱；货箱底部和房间边缘有碰撞。Camera2D 等比容纳完整 768×432 构图。

    godot --headless --path . --script tests/test_intro.gd

拿着散落箱子，从通道走近上方中间托盘的右侧缺口（48 像素内）后，提示变为“E 放回箱子”。按 E 清除持箱状态，将五箱托盘替换成 Boxes6.png，并保持托盘宽度、底部位置和碰撞不变；禁止远距离、从背面、对话锁定期间或按键重复触发放回。完成后不能重复放入。

图形模式加 -- --preview 保存 tests/intro-preview.png。

# 剧情对话框

F6 运行 Main.tscn，按 **T** 播放徐知夏的两句测试对话；旧的 Game.tscn 可单独 F6 运行，完成原有开场后再按 T。
空格每次按下前进一句，长按不会连跳；最后一句结束后隐藏并恢复操作。Main 的 Dialogue Test Enabled 可关闭临时入口。
DialogueUI.tscn 使用 CanvasLayer 110，复用 DialogUI.png 和 FemaleEnter 的最后一帧，无新增美术。
姓名、职位、正文、提示均为独立控件；以背景原始尺寸等比缩放并贴底，立绘在背景后方独立显示。

TutorialManager 接入示例（Main 已连接输入锁信号）：

```gdscript
var dialogue = main.get_node("DialogueUI")
if dialogue.start_dialogue([
    {"name": "徐知夏", "job_title": "厂长助理", "text": "下一步教学内容"},
]):
    await dialogue.dialogue_finished
```

每句可另传 portrait: Texture2D；缺省使用徐知夏立绘。空队列、格式错误或播放中再次调用返回 false。
在其他关卡复用时连接 active_changed(active) 到该关卡的玩家输入锁；UI 不依赖 Main，也不修改 SceneTree.paused。
锁定时清除待执行移动/拾取/投料、建造手势，并取消玩家点焊（保留原料），关闭后恢复接受新操作。
现有 Game/OpeningPortrait 的旧开场暂停逻辑保留，与新对话框分离。

    godot --headless --path . --script tests/test_dialogue.gd

加 -- --preview 可在图形模式保存 tests/dialogue-preview.png。测试覆盖多句切换、防长按、信号、输入屏蔽/恢复、加工取消和窗口缩放。

# 开场立绘

使用 F6 运行 Game.tscn：玩家保持初始位置，女性助理从画面左侧外走到玩家左侧，随后播放 FemaleEnter 目录中的 54 张 PNG。项目 F5 默认运行新的 Intro 走廊开场。
助理使用 FemaleCharacterWalk 的 6 帧循环，到达玩家旁边后切换为 FemaleCharacterIdle/FemaleCharacterIdle.png 静态待机。Idle 按 Walk 站稳帧的实际人物高度和脚底基准对齐，补偿两套图片不同的透明留白；Game 节点可调整 Assistant Speed、Assistant Height 和 Walk Fps。入场期间冻结游戏并屏蔽点击，到达后沿用立绘点击关闭流程。关闭后助理留在场景中并保持 Idle。
OpeningPortrait.tscn 的 Frames Per Second 默认 12，可在 Inspector 调整。
入场动画只播放一次，随后自动循环 FemaleIdle 的 49 帧待机动画；播放中或结束后点击鼠标均可关闭。
开场立绘与对话框共用 FemaleAssistantIdle.tres，默认 12 FPS，可在该资源中调整 Speed。
对话框显示时循环待机，切换句子不重启动画，关闭后停止推进；显式传入 portrait 的其他人物仍显示其静态立绘。
开场期间暂停关卡，完整吞掉关闭用的鼠标按下/释放，再恢复游戏。
Main.tscn 仍是独立关卡，直接运行它可跳过开场，现有关卡测试不受影响。

    godot --headless --path . --script tests/test_opening_portrait.gd

检查帧序列、入场转待机、待机循环、暂停/恢复、点击跳过和建造手势隔离。

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

Dash 起步时额外保留切换前的 Idle/Walk/持箱动画当前帧：灰色残影不透明度 0.3，原地停留 0.06 秒后用 0.16 秒淡出。保留原来的朝向、缩放和视觉中心，位于真人后方；与沿途 Dash 姿势残影、起步扬尘独立。Inspector 的 Dash Start Ghost Opacity / Hold / Fade 可调整效果。

    godot --headless --path . --script tests/test_dash_start_ghost.gd

检查起步仅生成一次、保留切换前动画帧/方向/变换、灰度材质、停留淡出、对话锁定和中断后清理。手动验证：移动中点按 Shift，起点应短暂留下灰色 Walk 姿势，沿途仍为原来的 Dash 残影。

Dash 开始时在脚底生成一次 DashDustEffect.tscn：Dust0 主尘团加三个 Dust1/Dust2 次级尘团，沿冲刺方向的反向扩散并略微上飘。主尘团以素材基础缩放的 0.9 倍开始，放大到 1.15 倍，透明度从 0.85 在 0.28 秒内降到零；次级尘团略随机散开，所有 Tween 结束后删除整个特效。场景内可调整基础尺寸，脚本的 Duration、Drift Distance 可调整时长和飘散距离。特效为世界节点，不跟随玩家；跨行时仍保持在真人后方，暂停时也可完成清理。

    godot --headless --path . --script tests/test_dash_dust.gd

检查成功触发一次、无方向/对话/冷却不触发、八方向反向扩散、放大淡出、世界位置固定、层级和暂停后清理。手动验证：结束对话后向八方向 Dash，观察起步脚下的一次爆尘；持续按 Shift 不应连续扬尘。

冲刺残影：每 0.05 秒复制当前 Dash 帧到世界父节点下的独立 Sprite2D，保留世界变换、朝向与视觉中心；初始透明度 0.55，以 Tween 在 0.22 秒内淡出并删除。Inspector 可调整 Afterimage Interval、Afterimage Opacity、Afterimage Fade Duration。残影始终在真人后面，不包含碰撞/交互组件。冲刺结束、对话中断或本次冲刺发生碰撞后停发，已有残影继续清理（包括场景暂停时），不修改冲刺本身的碰撞或滑墙行为。

    godot --headless --path . --script tests/test_dash_afterimage.gd

检查八方向、带缩放/偏移父节点下的世界变换、0.05 秒生成间隔、淡出与删除、跨行遮挡排序、碰撞/对话/正常结束停发，以及工人删除和暂停后的清理。手动验证：在 Intro 对话结束后向八方向冲刺，再冲向墙壁；应看到固定在沿途、逐渐淡出的残影，真人始终清晰且不被残影盖住。

按住 WASD 移动时新按下 Shift，沿开始时的归一化方向以 3 倍速度冲刺 0.2 秒，同时显示 WorkerDash.png；途中松手或换方向不会改变冲刺方向。结束后冷却 0.35 秒，冷却期间正常移动；长按不重复，期间再次按下不续时。Inspector 的 Dash Speed Multiplier、Dash Duration、Dash Cooldown 可调整这三个参数，位移和姿势共用持续时间。沿用 move_and_slide 碰撞；冲刺取消旧寻路，期间忽略新的寻路请求，结束后可重新点击寻路。结束后恢复当前 Idle/Walk、持箱或操作动画；对话、暂停或禁用节点立即终止冲刺并进入冷却，恢复后不续冲。
Dash 按身体比例等比缩放，默认使用 Walk 节点缩放的 0.9 倍（Inspector 的 Dash Sprite Scale Multiplier 可调整），前倾后的显示高度约为 Walk 的 82%。同步下移 Sprite 中心以保持脚底基准，结束后恢复原缩放和位置；左右翻转沿用原逻辑。

    godot --headless --path . --script tests/test_dash.gd
    godot --headless --path . --script tests/test_dash_motion.gd

检查 Shift 绑定、移动触发、时长、动画优先级、长按防重复、尺寸/脚底/朝向、持箱恢复、对话与暂停锁定；真实物理帧检查八方向各 96 像素位移、锁方向、墙体碰撞、寻路优先级和结束后冷却。手动验证：分别向左右移动并点按 Shift，途中松手应保持冲刺至结束再回 Idle；冲向机器不能穿过，持箱时箱子应保持可见。

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

## 出货计分验证

    godot --headless --path . --script tests/test_shipping.gd

检查电池组/电芯不计分、原料箱拒绝且不丢失、未注册同类型箱子拒绝、正确成品箱只加一分、同帧 UI 更新、节点移除和释放、重复/长按/对话/错误位置拒绝。加 -- --preview 可保存 tests/shipping-preview.png。
