extends Control
## GalleryPage：图鉴占位页（空白内容 + 返回按钮）
## 后续在此收录死亡称号 / 终局条目；当前仅搭骨架。
## 注意：不声明 class_name（避免全局类缓存过期导致的 Parse Error）

signal back_pressed

@onready var back_btn = $VBox/BackBtn

func _ready() -> void:
	back_btn.pressed.connect(func(): back_pressed.emit())
