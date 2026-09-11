extends Control
## TitlePage：主菜单（标题 + 游戏说明 + 菜单）
## 菜单：新的一局 / 图 鉴 / 存档（未开放，置灰占位）/ 退出游戏
## 注意：预言已从开门页移除，改为建卡完成后的独立预言页（ProphecyPage）
## 注意：不声明 class_name（避免全局类缓存过期导致的 Parse Error）

signal start_pressed
signal gallery_pressed
signal quit_pressed

@onready var start_btn = $VBox/MenuBox/StartBtn
@onready var gallery_btn = $VBox/MenuBox/GalleryBtn
@onready var save_btn = $VBox/MenuBox/SaveBtn
@onready var quit_btn = $VBox/MenuBox/QuitBtn

func _ready() -> void:
	start_btn.pressed.connect(func(): start_pressed.emit())
	gallery_btn.pressed.connect(func(): gallery_pressed.emit())
	quit_btn.pressed.connect(func(): quit_pressed.emit())
	# 存档系统未实装：置灰占位，不接任何信号
	save_btn.disabled = true
