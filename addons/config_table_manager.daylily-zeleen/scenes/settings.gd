@tool
extends PanelContainer

const _Localize = preload("../localization/localize.gd")

signal tools_updated

var presets_dir: String:
	set(v):
		_preset_save_dir_line_edit.text = v
	get:
		return _preset_save_dir_line_edit.text

@export var table_tools: Dictionary:
	set(v):
		table_tools = v
		tools_updated.emit()
	get:
		return _validate_tools(table_tools, true)
@export var import_tools: Dictionary:
	set(v):
		import_tools = v
		tools_updated.emit()
	get:
		return _validate_tools(import_tools, false)

@onready var _preset_save_dir_line_edit: LineEdit = %PresetSaveDirLineEdit
@onready var _preset_dir_select_btn: Button = %PresetDirSelectBtn

@onready var _table_tools_tree: Tree = %TableToolsTree
@onready var _import_tools_tree: Tree = %ImportToolsTree

@onready var _save_btn: Button = %SaveBtn
@onready var _file_dialog: FileDialog = %FileDialog

const DEFAULT_TABLE_TOOL = {
	"CSV(,分隔)": "res://addons/config_table_manager.daylily-zeleen/table_tools/csv.gd",
	"Excel(xlsx)": "res://addons/config_table_manager.daylily-zeleen/table_tools/xlsx.gd",
}

const DEFAULT_IMPORT_TOOL = {
	"GDScript(TypedArray风格)": "res://addons/config_table_manager.daylily-zeleen/import_tools/gdscript_default.gd",
	"GDScript(Dictionary风格)": "res://addons/config_table_manager.daylily-zeleen/import_tools/gdscript_dictionary.gd",
}


func _ready() -> void:
	_preset_dir_select_btn.pressed.connect(func(): _file_dialog.popup_centered_ratio(0.6))
	_file_dialog.dir_selected.connect(func(dir: String): _preset_save_dir_line_edit.text = dir)
	_save_btn.pressed.connect(_on_save_btn_pressed)

	_table_tools_tree.clear()
	_table_tools_tree.create_item()
	_table_tools_tree.set_column_title(0, _Localize.translate("表格工具"))
	_table_tools_tree.set_column_title(1, _Localize.translate("脚本路径"))
	_table_tools_tree.set_column_title(2, _Localize.translate("+"))
	_table_tools_tree.set_column_expand(1, true)
	_table_tools_tree.set_column_expand(2, false)
	_table_tools_tree.column_title_clicked.connect(_on_tree_colum_title_clicked.bind(_table_tools_tree))
	_table_tools_tree.item_edited.connect(_on_tree_item_edited.bind(_table_tools_tree))
	_table_tools_tree.button_clicked.connect(_on_tree_button_clicked.bind(_table_tools_tree))

	_import_tools_tree.clear()
	_import_tools_tree.create_item()
	_import_tools_tree.set_column_title(0, _Localize.translate("导入工具"))
	_import_tools_tree.set_column_title(1, _Localize.translate("脚本路径"))
	_import_tools_tree.set_column_title(2, _Localize.translate("+"))
	_import_tools_tree.set_column_expand(1, true)
	_import_tools_tree.set_column_expand(2, false)
	_import_tools_tree.column_title_clicked.connect(_on_tree_colum_title_clicked.bind(_import_tools_tree))
	_import_tools_tree.item_edited.connect(_on_tree_item_edited.bind(_import_tools_tree))
	_import_tools_tree.button_clicked.connect(_on_tree_button_clicked.bind(_import_tools_tree))

	_refresh()


func _refresh() -> void:
	var root := _table_tools_tree.get_root()
	for item in root.get_children():
		root.remove_child(item)
		item.free()
	for k in DEFAULT_TABLE_TOOL:
		_add_tree_itme(root, k, DEFAULT_TABLE_TOOL[k], false)
	for n in table_tools:
		if table_tools[n] in DEFAULT_TABLE_TOOL.values():
			continue
		_add_tree_itme(root, n, table_tools[n])
	_refresh_tools(_table_tools_tree)

	root = _import_tools_tree.get_root()
	for item in root.get_children():
		root.remove_child(item)
		item.free()
	for k in DEFAULT_IMPORT_TOOL:
		_add_tree_itme(root, k, DEFAULT_IMPORT_TOOL[k], false)
	for n in import_tools:
		if import_tools[n] in DEFAULT_IMPORT_TOOL.values():
			continue
		_add_tree_itme(root, n, import_tools[n])
	_refresh_tools(_import_tools_tree)


func _add_tree_itme(parent: TreeItem, p_name: String, path: String, editable := true) -> void:
	var item := parent.create_child()
	item.set_text(0, _Localize.translate(p_name))
	item.set_text(1, path)
	item.set_editable(0, editable)
	item.set_editable(1, editable)

	if editable:
		item.add_button(2, EditorInterface.get_editor_theme().get_icon(&"Remove", &"EditorIcons"), 0)
		item.set_text(2, "-")


func _refresh_tools(tree: Tree) -> void:
	var map := {}
	for item in tree.get_root().get_children():
		var n := item.get_text(0).strip_edges()
		if map.has(n):
			continue
		map[n] = item.get_text(1)

	if tree == _table_tools_tree:
		table_tools = map
	elif tree == _import_tools_tree:
		import_tools = map


func _validate_tools(tools: Dictionary, for_table_tool: bool) -> Dictionary:
	var ret := {}
	var required_base: Script
	if for_table_tool:
		required_base = ResourceLoader.load("res://addons/config_table_manager.daylily-zeleen/table_tools/table_tool.gd", "Script", ResourceLoader.CACHE_MODE_IGNORE)
	else:
		required_base = ResourceLoader.load("res://addons/config_table_manager.daylily-zeleen/import_tools/import_tool.gd", "Script", ResourceLoader.CACHE_MODE_IGNORE)

	for n in tools:
		n = (n as String).strip_edges()
		var path = tools[n] as String
		if n.is_empty():
			continue
		if not ResourceLoader.exists(path, "Script"):
			continue
		var s := ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_IGNORE) as Script
		if not is_instance_valid(s):
			continue

		var valid = false
		var base = s.get_base_script()
		while base:
			if base == required_base:
				valid = true
				break
			base = base.get_base_script()

		if valid:
			ret[n] = path

	return ret


# --------
func _on_tree_colum_title_clicked(column: int, mouse_button_index: int, tree: Tree) -> void:
	if column != 2 or mouse_button_index != MOUSE_BUTTON_LEFT:
		return
	_add_tree_itme(tree.get_root(), "tool name", "script path")


func _on_tree_item_edited(tree: Tree) -> void:
	_refresh_tools(tree)


func _on_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int, tree: Tree) -> void:
	if column != 2 or mouse_button_index != MOUSE_BUTTON_LEFT or id != 0:
		return
	if not item.is_editable(0):
		return
	item.get_parent().remove_child(item)
	item.free()

	_refresh_tools(tree)


func _on_save_btn_pressed() -> void:
	var scene_path := (get_script().resource_path as String).trim_suffix("gd") + "tscn"
	var ps := PackedScene.new()
	var err := ps.pack(self)
	if err != OK:
		printerr(_Localize.translate("保存设置失败: "), error_string(err))

	err = ResourceSaver.save(ps, scene_path)
	if err != OK:
		printerr(_Localize.translate("保存设置失败: "), error_string(err))
