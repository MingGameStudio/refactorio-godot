# 代码与资源检查（2026-10-28）

检查入口为 project.godot，并递归检查场景、脚本、图集资源、Shader 的 res:// 引用；同时检查 tests 中的引用、测试输出路径及动态加载调用。未把 .import 对源图片的自引用、编辑器缓存或 .tmp 备份视为游戏引用。以下资源均未删除。

## 当前未引用的资源

| 文件 | 大小 | 说明 |
| --- | ---: | --- |
| assets/Worker/WorkerSprites.png | 255,565 字节 | 未被场景或代码引用的人物总图；当前动画使用 WorkerIdle、WorkerWalk、WorkerHoldIdle、WorkerHoldWalk。可能仍有美术源文件价值。 |
| assets/Machines/WeldingMachine.png | 1,562,082 字节 | 焊接机图片尚未接入当前关卡或代码，可能是预备素材。 |
| assets/FloorDecorations/patch_1_3.tres | 283 字节 | 未被引用的装饰 AtlasTexture 切片；它引用的 FloorDecorations.png 仍被其他装饰使用，不能一起删除。 |

以上三个源文件合计 1,817,930 字节，约 1.73 MiB。前两张图片各自的 .import 文件属于相应导入配置，也一并保留。

## 不参与游戏运行的辅助产物

- tests/worker-preview.png 及 .import：人物测试的可重新生成预览图。
- tests/corners-preview.png 及 .import：转角测试的可重新生成预览图。
- Main.tscn183732389353.tmp、Main.tscn252938141296.tmp、Main.tscn3241684814.tmp、Main.tscn3250707780.tmp：不被项目加载的场景保存临时文件，可能具有恢复价值。
- godot-*.log：检查运行日志，不是游戏资源。

tests 下的七个测试脚本是独立测试入口，保留；.uid、正在使用的资源的 .import 以及 .godot 导入缓存不算无用业务代码。

## 已清理的代码

- Main.gd：删除未使用的 C_BELT、C_BELT_HI、C_SOURCE、C_SINK、C_ARROW 常量。
- Main.gd：删除未使用的 _floor_layer、_hint_label 节点引用，保留实际场景节点。
- Main.gd：删除 _make_building_node 中未使用的 rect 局部变量。
- Main.gd：合并带面与结构件重复的方向计算；简化清空拖拽路径后的恒定空预览赋值；移除过时注释。
- belt_scroll.gdshader：删除不执行任何操作的 vertex() 函数。

保留 Godot 生命周期回调、信号回调、Callable 引用、Inspector 导出属性及被测试使用的辅助接口。未发现可以确认整体废弃的游戏脚本。

## 验证

Godot 无窗口运行以下七组测试，全部退出码为 0，无失败：test_corners、test_worker、test_occupancy、test_navigation、test_machine_feeding、test_level_buildings、test_depth。git diff --check 通过。
