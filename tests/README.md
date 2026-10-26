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
人物使用 WorkerWalk.png 的四帧行走动画（每帧 176×262，8 FPS），移动时循环播放，静止时切换至 WorkerIdle.png 的四帧 Idle 循环（4 FPS）。
当前为地图范围内的直线移动，可穿过传送带和机器，尚未加入碰撞和寻路。

    godot --headless --path . --script tests/test_worker.gd

检查点击与拖拽分流、地图外释放、移动、转向和到达后切换 Idle、静止时不重置动画进度。
添加 -- --preview 可在有图形渲染的运行中输出 tests/worker-preview.png。
## 箱子拾取

Main 场景的 Box 节点是可点击箱子，可以在编辑器中调整位置。
单击箱子后，人物走到箱子左右较近的一侧，距离 32 像素时拾取；
途中点击其他地面会取消拾取。拖动箱子不会触发拾取或铺设。
拾取后地面箱子隐藏，人物手边显示箱子，使用 hold_idle / hold_walk。
WorkerHoldIdle.png 为单帧姿势，WorkerHoldWalk.png 为四帧动画。
目前仅支持拿起一个箱子，尚未实现放下和碰撞寻路。
test_worker.gd 同时检查拾取距离、取消拾取、持箱动画和左右朝向。