@tool
extends PanelContainer

signal delete_request

@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var description_edit: LineEdit = %DescriptionLineEdit
@onready var delete_btn: Button = %DeleteBtn


func _ready() -> void:
	delete_btn.pressed.connect(func(): delete_request.emit())
	preload("../localization/localize.gd").localiza_node(self)

func setup(prop_name: String, desc: String) -> void:
	if not is_node_ready():
		await ready
	name_line_edit.text = prop_name
	description_edit.text = desc


func get_property_name() -> String:
	return name_line_edit.text


func get_description() -> String:
	return description_edit.text
