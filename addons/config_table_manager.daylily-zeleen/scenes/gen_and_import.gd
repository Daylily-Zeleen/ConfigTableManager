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
		if not is_node_ready():
			await ready
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

var save_path: String

@onready var _tree: Tree = %Tree


func _ready() -> void:
	%SelectOnlyBtn.pressed.connect(_on_select_only_btn_pressed)
	%AllBtn.pressed.connect(_on_all_btn_pressed)

	mode = mode

	_tree.clear()
	_tree.create_item()
	_tree.column_titles_visible = true
	_tree.set_column_title(0, tr("选中"))
	_tree.set_column_title(1, tr("排除"))
	_tree.set_column_title(2, tr("预设"))
	_tree.set_column_expand(0, false)
	_tree.set_column_expand(1, false)
	_tree.item_edited.connect(_on_tree_item_edited)


func setup(presets: Array[_Preset]) -> void:
	for p in presets:
		var item = _tree.get_root().create_child() as TreeItem
		item.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		item.set_text(2, "%s (%s)" % [p.name, p.resource_path])
		item.set_editable(0, true)
		item.set_editable(1, true)
		item.set_metadata(2, p.resource_path)

	_load_archive()


# -----------------------
func _on_select_only_btn_pressed() -> void:
	_execute(true)


func _on_all_btn_pressed() -> void:
	_execute(false)


func _on_tree_item_edited() -> void:
	if save_path.is_empty():
		return

	var presets := {}

	for item in _tree.get_root().get_children():
		if not item.is_checked(0) and not item.is_checked(1):
			continue
		var preset_file = item.get_metadata(2) as String
		if not presets.has(preset_file):
			presets[preset_file] = {}
		if item.is_checked(0):
			presets[preset_file]["include"] = true
		if item.is_checked(1):
			presets[preset_file]["exclude"] = true

	if not DirAccess.dir_exists_absolute(save_path.get_base_dir()):
		DirAccess.make_dir_recursive_absolute(save_path.get_base_dir())

	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if not is_instance_valid(f):
		printerr("BUG, Open File failed: ", error_string(FileAccess.get_open_error()))
		return

	f.store_var(presets)
	f.close()


# -------------
func _load_archive() -> void:
	if not FileAccess.file_exists(save_path):
		return

	var f := FileAccess.open(save_path, FileAccess.READ)
	if not is_instance_valid(f):
		printerr("BUG, open file failed: ", error_string(FileAccess.get_open_error()))
		return

	var presets = f.get_var()
	if typeof(presets) != TYPE_DICTIONARY:
		printerr("BUG, Parse error")
		return

	for item in _tree.get_root().get_children():
		var preset_file = item.get_metadata(2) as String

		if not presets.has(preset_file):
			continue

		item.set_checked(0, presets[preset_file].get("include", false))
		item.set_checked(1, presets[preset_file].get("exclude", false))


func _execute(select_only) -> void:
	for item in _tree.get_root().get_children():
		if select_only and not item.is_checked(0):
			# 仅选中项
			continue
		if item.is_checked(1):
			# 排除
			continue
		var path := item.get_metadata(2) as String
		var preset = ResourceLoader.load(path, "Resource", ResourceLoader.CACHE_MODE_IGNORE) as _Preset
		if not is_instance_valid(preset):
			_Log.error([tr("表格预设不存在: "), path])
			continue

		if preset.resource_path.is_empty():
			preset.take_over_path(path)

		if mode == Mode.GENERATE_TABLE:
			preset.generate_table()
		else:
			preset.import_table()
