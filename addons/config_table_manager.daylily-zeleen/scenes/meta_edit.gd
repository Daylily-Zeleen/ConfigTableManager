@tool
extends PanelContainer

signal delete_request

@onready var meta_line_edit: LineEdit = %MetaLineEdit
@onready var delete_btn: Button = %DeleteBtn


func _ready() -> void:
	delete_btn.pressed.connect(func(): delete_request.emit())


func setup(meta: String) -> void:
	if not is_node_ready():
		await ready
	meta_line_edit.text = meta


func get_meta_text() -> String:
	return meta_line_edit.text
