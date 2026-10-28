extends Node2D
## 放在 BuildingLayer 下；位置对应所占地板格的左上角（64 像素网格）。
@export_enum("Belt:1", "Source:2", "Sink:3") var building_type: int = 1
@export_enum("Up:0", "Down:1", "Left:2", "Right:3") var direction: int = 3
