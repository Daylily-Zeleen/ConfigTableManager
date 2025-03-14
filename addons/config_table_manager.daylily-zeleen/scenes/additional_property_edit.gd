@tool
extends PanelContainer

const _Localize = preload("../localization/localize.gd")

signal delete_request

@onready var name_line_edit: LineEdit = %NameLineEdit
@onready var type_options: OptionButton = %TypeOptions
@onready var setter_line_edit: LineEdit = %SetterLineEdit
@onready var delete_btn: Button = %DeleteBtn


func _ready() -> void:
	type_options.clear()
	for t in range(TYPE_MAX):
		if t in [TYPE_NIL, TYPE_OBJECT, TYPE_CALLABLE, TYPE_RID, TYPE_SIGNAL]:
			continue
		type_options.add_item(type_string(t).trim_prefix("Packed"), t)
	delete_btn.pressed.connect(func() -> void: delete_request.emit())
	_Localize.localize_node(self)


func setup(prop_name: String, type: int, setter: String) -> void:
	if not is_node_ready():
		await ready
	name_line_edit.text = prop_name
	type_options.select(type_options.get_item_index(type))
	setter_line_edit.text = setter


func get_property_name() -> String:
	return name_line_edit.text


func get_type() -> int:
	return type_options.get_selected_id()


func get_setter() -> String:
	return setter_line_edit.text
