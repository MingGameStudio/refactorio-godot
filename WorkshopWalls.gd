@tool
extends Node2D
## 外缘墙体只负责表现；人物边界继续由 GridCollision 管理。
## 货口对接现有生产行，不生成物品或改动机器库存。

const TOP = preload("res://assets/Wall/wall_top_tile.png")
const LEFT = preload("res://assets/Wall/wall_left_tile.png")
const RIGHT = preload("res://assets/Wall/wall_right_tile.png")
const TOP_LEFT = preload("res://assets/Wall/wall_top_left_corner.png")
const TOP_RIGHT = preload("res://assets/Wall/wall_top_right_corner.png")
const DOOR = preload("res://assets/Wall/wall_top_exit_door.png")
const CARGO = preload("res://assets/Wall/wall_cargo_port.png")

@export var grid_size := Vector2i(12, 8):
	set(value):
		grid_size = Vector2i(maxi(value.x, 4), maxi(value.y, 3))
		_refresh()
@export_range(16, 128, 1) var cell_size: float = 64.0:
	set(value):
		cell_size = value
		_refresh()
@export var inlet_row: int = 4:
	set(value):
		inlet_row = value
		_refresh()
@export var outlet_row: int = 4:
	set(value):
		outlet_row = value
		_refresh()

func _ready() -> void:
	rebuild()

func _refresh() -> void:
	if is_inside_tree():
		rebuild()

func visual_bounds() -> Rect2:
	# 按素材等比缩放后的实际外缘取景，不附加墙外留白。
	var side_extent := maxf(cell_size, CARGO.get_width() * cell_size * 2.0 / CARGO.get_height())
	var top_extent := maxf(cell_size, DOOR.get_height() * cell_size * 3.0 / DOOR.get_width())
	return Rect2(Vector2(-side_extent, -top_extent),
		Vector2(grid_size) * cell_size + Vector2(side_extent * 2.0, top_extent))

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var size := Vector2(grid_size) * cell_size
	var door_scale := cell_size * 3.0 / DOOR.get_width()
	var door_size := DOOR.get_size() * door_scale
	var door_left := (size.x - door_size.x) * 0.5
	_repeat(TOP, Vector2(0, -cell_size), door_left, true)
	_repeat(TOP, Vector2(door_left + door_size.x, -cell_size), door_left, true)
	_sprite(TOP_LEFT, Vector2(-cell_size, -cell_size), cell_size / TOP_LEFT.get_width(), "TopLeftCorner")
	_sprite(TOP_RIGHT, Vector2(size.x, -cell_size), cell_size / TOP_RIGHT.get_width(), "TopRightCorner")
	_sprite(DOOR, Vector2(door_left, -door_size.y), door_scale, "ExitDoor")
	_marker("ExitApproach", Vector2(size.x * 0.5, cell_size * 0.5))
	# 牌子内框使用门素材的相对坐标，随门一起等比缩放。
	var exit_label := _label("人物出口",
		Vector2(door_left, -door_size.y) + door_size * Vector2(0.29, 0.075), door_size.x * 0.42)
	exit_label.name = "ExitSignLabel"
	exit_label.add_theme_font_size_override("font_size", 12)
	exit_label.scale = Vector2.ONE * cell_size / 64.0
	exit_label.size = door_size * Vector2(0.42, 0.27) / exit_label.scale
	exit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_side(LEFT, -cell_size, inlet_row, false, size.y)
	_side(RIGHT, size.x, outlet_row, true, size.y)

func _side(texture: Texture2D, x: float, row: int, mirror: bool, height: float) -> void:
	var center := clampf((row + 0.5) * cell_size, cell_size, height - cell_size)
	var start := center - cell_size
	_repeat(texture, Vector2(x, 0), start, false)
	_repeat(texture, Vector2(x, center + cell_size), height - center - cell_size, false)
	var factor := cell_size * 2.0 / CARGO.get_height()
	var width := CARGO.get_width() * factor
	var port_x := x if mirror else -width
	var port := _sprite(CARGO, Vector2(port_x, start), factor, "Outlet" if mirror else "Inlet")
	port.flip_h = mirror
	_marker("OutletApproach" if mirror else "InletApproach",
		Vector2(x - cell_size * 0.5 if mirror else cell_size * 0.5, center))
	_label("出货口" if mirror else "入料口", Vector2(port_x, start - 24), width)

func _repeat(texture: Texture2D, origin: Vector2, length: float, horizontal: bool) -> void:
	# 先按墙厚等比缩放，再重复；最后一段裁切源区域，绝不压缩补齐。
	var factor := cell_size / (texture.get_height() if horizontal else texture.get_width())
	var unit := (texture.get_width() if horizontal else texture.get_height()) * factor
	var cursor := 0.0
	while cursor < length - 0.001:
		var span := minf(unit, length - cursor)
		var sprite := _sprite(texture, origin + (Vector2(cursor, 0) if horizontal else Vector2(0, cursor)), factor, "WallTile")
		if span < unit - 0.001:
			sprite.region_enabled = true
			sprite.region_rect = Rect2(Vector2.ZERO,
				Vector2(span / factor, texture.get_height()) if horizontal else Vector2(texture.get_width(), span / factor))
			sprite.region_filter_clip_enabled = true
		cursor += span

func _sprite(texture: Texture2D, point: Vector2, factor: float, title: String) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = title
	sprite.texture = texture
	sprite.centered = false
	sprite.position = point
	sprite.scale = Vector2.ONE * factor
	add_child(sprite)
	return sprite

func _marker(title: String, point: Vector2) -> void:
	var marker := Marker2D.new()
	marker.name = title
	marker.position = point
	add_child(marker)

func _label(text: String, point: Vector2, width: float) -> Label:
	var label := Label.new()
	label.text = text
	label.position = point
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.35))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label
