@tool
extends VBoxContainer

const _Preset = preload("../scripts/preset.gd")
const _Log = _Preset._Log

enum Mode {
	GENERATE_TABLE,
	IMPORT_TABLE,
}

@export var title: String:
	set(v):
		%TitleLabel.text = v
	get:
		return %TitleLabel.text

@export var mode: Mode:
	set(v):
		mode = v
		if mode == Mode.GENERATE_TABLE:
			%SelectOnlyBtn.text = tr("对选中项进行生成")
			%AllBtn.text = tr("对所有项进行生成")
		else:
			%SelectOnlyBtn.text = tr("对选中项执行导入")
			%AllBtn.text = tr("对所有项执行导入")

@onready var _tree: Tree = %Tree


func _ready() -> void:
	%SelectAllBtn.pressed.connect(_on_select_all_pressed)
	%DeselectAllBtn.pressed.connect(_on_deselect_all_pressed)
	%InverseSelectBtn.pressed.connect(_on_inverse_select_pressed)

	%SelectOnlyBtn.pressed.connect(_on_select_only_btn_pressed)
	%AllBtn.pressed.connect(_on_all_btn_pressed)

	mode = mode

	_tree.clear()
	_tree.create_item()


func setup(presets: Array[_Preset]) -> void:
	var selected: PackedStringArray = []
	for item in _tree.get_root().get_children():
		if item.is_checked(0):
			selected.push_back(item.get_metadata(0))

		_tree.get_root().remove_child(item)
		item.free()

	for p in presets:
		var item = _tree.get_root().create_child() as TreeItem
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_text(0, "%s (%s)" % [p.name, p.resource_path])
		item.set_editable(0, true)
		item.set_metadata(0, p.resource_path)
		if p.resource_path in selected:
			item.set_checked(0, true)


# -----------------------
func _on_select_all_pressed() -> void:
	for item in _tree.get_root().get_children():
		item.set_checked(0, true)


func _on_deselect_all_pressed() -> void:
	for item in _tree.get_root().get_children():
		item.set_checked(0, false)


func _on_inverse_select_pressed() -> void:
	for item in _tree.get_root().get_children():
		item.set_checked(0, not item.is_checked(0))


func _on_select_only_btn_pressed() -> void:
	_execute(true)


func _on_all_btn_pressed() -> void:
	_execute(false)


# -------------
func _execute(select_only) -> void:
	for item in _tree.get_root().get_children():
		if select_only and not item.is_checked(0):
			continue
		var path := item.get_metadata(0) as String
		var preset = ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as _Preset
		if not is_instance_valid(preset):
			_Log.error([tr("表格预设不存在: "), path])
			continue

		if preset.resource_path.is_empty():
			preset.take_over_path(path)
			#preset.resource_path = path

		if mode == Mode.GENERATE_TABLE:
			preset.generate_table()
		else:
			preset.import_table()
