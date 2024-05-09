@tool
extends PanelContainer

const _Settings = preload("settings.gd")
const _Preset = preload("../scripts/preset.gd")
const _Log = _Preset._Log

const _AdditionalPropertyEdit = preload("additional_property_edit.gd")
const _PropertyDescriptionEdit = preload("property_description_edit.gd")
const _MetaEdit = preload("meta_edit.gd")

#
@onready var _file_dialog: FileDialog = %FileDialog
@onready var _confirmation_dialog: ConfirmationDialog = %ConfirmationDialog

# 预设
@onready var _preset_name_line_edit: LineEdit = %PresetNameLineEdit

# 操作
@onready var _preset_options: OptionButton = %PresetOption
@onready var _save_btn: Button = %SaveButton
@onready var _delete_btn: Button = %DeleteButton
@onready var _script_select_btn: Button = %ScriptSelectBtn
@onready var _add_ap_btn: Button = %AddAPBtn
@onready var _add_desc_btn: Button = %AddDescBtn
@onready var _add_meta_btn: Button = %AddMetaBtn
@onready var _output_select_btn: Button = %OutputSeletBtn
@onready var _table_import_select_btn: Button = %TableImportSelectBtn

# 预设参数
@onready var _klass_name_line_edit: LineEdit = %ClassNameLineEdit
@onready var _script_line_edit: LineEdit = %ScriptLineEdit
@onready var _only_storage_check_box: CheckBox = %OnlyStorageCheckBox
@onready var _no_inheritance_check_box: CheckBox = %NoInheritanceCheckBox
@onready var _ascending_check_box: CheckBox = %AscendingCheckBox
@onready var _instantiation_line_edit: LineEdit = %InstantiationLineEdit
@onready var _priority_line_edit: LineEdit = %PriorityLineEdit
@onready var _output_line_edit: LineEdit = %OutputLineEdit
@onready var _table_import_line_edit: LineEdit = %TableImportLineEdit

@onready var _tab_contaner: TabContainer = %TabContainer
@onready var _settings: _Settings
@onready var _ap_contianer: VBoxContainer = %APContaner
@onready var _desc_container: VBoxContainer = %DescContaner
@onready var _meta_container: VBoxContainer = %MetaContaner

@onready var _table_tool_options: OptionButton = %TableToolOptions
@onready var _import_tool_options: OptionButton = %ImportToolOptions

@onready var _preset_manager_tab = find_child("预设管理")
@onready var _gen_and_import_tab = find_child("生成与导入")

var _ap_edit_scene: PackedScene = _load((get_script().resource_path as String).get_base_dir().path_join("additional_property_edit.tscn"))
var _pd_edit_scene: PackedScene = _load((get_script().resource_path as String).get_base_dir().path_join("property_description_edit.tscn"))
var _meta_edit_scene: PackedScene = _load((get_script().resource_path as String).get_base_dir().path_join("meta_edit.tscn"))


func _ready() -> void:
	_settings = _load((get_script().resource_path as String).get_base_dir().path_join("settings.tscn")).instantiate()
	_settings.tools_updated.connect(_on_settings_tools_updated)
	_tab_contaner.add_child(_settings)

	_confirmation_dialog.confirmed.connect(func(): _confirmed.emit(true))
	_confirmation_dialog.canceled.connect(func(): _confirmed.emit(false))

	_file_dialog.canceled.connect(func(): _path_selected.emit(false, ""))
	_file_dialog.dir_selected.connect(func(dir): _path_selected.emit(true, dir))
	_file_dialog.file_selected.connect(func(file): _path_selected.emit(true, file))

	_preset_options.item_selected.connect(_on_preset_options_selected)
	_save_btn.pressed.connect(_on_save_btn_pressed)
	_delete_btn.pressed.connect(_on_delete_btn_pressed)
	_script_select_btn.pressed.connect(_on_script_select_btn_pressed)
	_add_ap_btn.pressed.connect(_on_add_additional_property_btn_pressed)
	_add_desc_btn.pressed.connect(_on_add_desc_btn_pressed)
	_add_meta_btn.pressed.connect(_on_add_meta_btn_pressed)
	_output_select_btn.pressed.connect(_on_output_select_btn_pressed)
	%GenerateModifierSeletBtn.pressed.connect(_on_generate_modifier_select_btn_pressed)
	%ImportModifierSeletBtn.pressed.connect(_on_import_modifier_select_btn_pressed)

	_gen_and_import_tab.visibility_changed.connect(_on_gen_and_import_tab_visibility_changed)

	_preset_options.pressed.connect(_on_preset_options_pressed)

	_preset_options.clear()
	_preset_options.add_item("- None -")
	_preset_options.set_item_metadata(0, null)

	_on_settings_tools_updated()


# ---------------
signal _path_selected(confirmed: bool, path: String)
signal _confirmed(confirm: bool)


#region 内部方法
func _pop_file_dialog(title: String, mode: FileDialog.FileMode, filters: PackedStringArray, path: String) -> void:
	_file_dialog.title = title
	_file_dialog.file_mode = mode
	_file_dialog.filters = filters
	_file_dialog.current_path = path
	_file_dialog.popup_centered_ratio(0.6)


func _on_preset_options_pressed() -> void:
	if _preset_options.item_count <= 1:
		_refresh_preset_options()


func _refresh_preset_options(preset_name: String = "") -> void:
	_preset_options.clear()
	_preset_options.add_item("- None -")
	_preset_options.set_item_metadata(0, null)
	if not DirAccess.dir_exists_absolute(_settings.presets_dir):
		return
	var fs := EditorInterface.get_resource_filesystem() as EditorFileSystem
	var dir := fs.get_filesystem_path(_settings.presets_dir)
	if not is_instance_valid(dir):
		_Log.error([tr('无效的预设保存路径"{save_dir}"，必须是资源目录下的合法路径。').format({save_dir = _settings.presets_dir})])
		return

	var idx := -1
	for i in range(dir.get_file_count()):
		if dir.get_file_type(i) != &"Resource":
			continue
		var preset = _load(dir.get_file_path(i)) as _Preset
		if not is_instance_valid(preset):
			continue

		_preset_options.add_item(preset.name)
		_preset_options.set_item_metadata(_preset_options.item_count - 1, preset)
		if preset.name == preset_name:
			idx == _preset_options.item_count - 1

	if idx >= 0:
		_on_preset_options_selected(idx)


func _save_preset() -> void:
	var preset_name: String = _preset_name_line_edit.text
	if preset_name.is_empty():
		_Log.error([tr("预设名称不能为空。")])
		return
	if not preset_name.is_valid_filename():
		_Log.error([tr('预设名称"{preset_name}"无法作为文件名').format({preset_name = preset_name})])
		return
	var presets_dir := _settings.presets_dir
	if not DirAccess.dir_exists_absolute(presets_dir):
		var err := DirAccess.make_dir_recursive_absolute(presets_dir)
		if err != OK:
			_Log.error([tr('创建预设路径"{presets_dir}"失败: ').format({presets_dir = presets_dir}), error_string(err)])
			return

	var preset := _Preset.new()
	_set_to_preset(preset)

	var file_name := preset_name.capitalize().replace(" ", "_").to_lower().trim_suffix(".tres") + ".tres"
	var fp := presets_dir.path_join(file_name)
	var err := ResourceSaver.save(preset, fp, ResourceSaver.FLAG_NONE)
	if err != OK:
		_Log.error([tr('保存预设失败"{file_name}"失败: ').format({file_name = file_name}), error_string(err)])
		return

	EditorInterface.get_resource_filesystem().update_file(file_name)
	_Log.info([tr('保存预设"{preset_name}"成功: ').format({preset_name = preset_name})])
	_refresh_preset_options(preset.name)


func _delete_preset(preset: _Preset) -> void:
	var file_path := preset.resource_path
	if not FileAccess.file_exists(file_path):
		_Log.error([tr("删除失败,预设”{file_path}“不存在").format({file_path = file_path})])
		return

	var err := DirAccess.remove_absolute(file_path)
	if not err == OK:
		_Log.error([tr("删除预设失败: "), error_string(err)])
		return

	_Log.info([tr("删除预设成功: "), preset.name])
	EditorInterface.get_resource_filesystem().update_file(file_path)
	_refresh_preset_options()


func _remove_and_queue_free_children(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


func _load_preset(preset: _Preset) -> void:
	_preset_name_line_edit.text = preset.name
	_klass_name_line_edit.text = preset.data_class
	_script_line_edit.text = preset.data_class_script
	%TableNameLineEdit.text = preset.table_name.strip_edges()
	%SkipPrefixUnderscoreCheckBox.set_pressed_no_signal(preset.skip_prefix_underscore_properties)
	_only_storage_check_box.set_pressed_no_signal(preset.only_strage_properties)
	_no_inheritance_check_box.set_pressed_no_signal(preset.no_inheritance)
	_ascending_check_box.set_pressed_no_signal(preset.ascending_order)
	_instantiation_line_edit.text = preset.instantiation
	_priority_line_edit.text = ", ".join(preset.priority_properties)
	%IgnoreLineEdit.text = ", ".join(preset.ignored_properties)
	%MetaPriorityLineEdit.text = ", ".join(preset.need_meta_properties)
	_output_line_edit.text = preset.table_ouput_path
	%BackupCheckBox.set_pressed_no_signal(preset.auto_backup)
	%MergeCheckBox.set_pressed_no_signal(preset.auto_merge)
	_table_import_line_edit.text = preset.import_path
	%TableOptionsLineEdit.text = ", ".join(preset.table_tool_options)
	%ImportOptionsLineEdit.text = ", ".join(preset.import_tool_options)
	%GenerateModifierLineEdit.text = preset.generate_modifier_file
	%ImportModifierLineEdit.text = preset.import_mofifier_file

	_remove_and_queue_free_children(_ap_contianer)
	for ap in preset.additional_properties:
		var ape = _ap_edit_scene.instantiate() as _AdditionalPropertyEdit
		ape.setup(ap.get("name", ""), ap.get("type", TYPE_BOOL), ap.get("setter", ""))
		ape.delete_request.connect(_on_additional_property_delete_request.bind(ape))
		_ap_contianer.add_child(ape)

	_remove_and_queue_free_children(_desc_container)
	for f in preset.descriptions:
		var pde = _pd_edit_scene.instantiate() as _PropertyDescriptionEdit
		pde.setup(f, preset.descriptions[f])
		pde.delete_request.connect(_on_property_description_delete_request.bind(pde))
		_desc_container.add_child(pde)

	_remove_and_queue_free_children(_meta_container)
	for m in preset.metas:
		var me = _meta_edit_scene.instantiate() as _MetaEdit
		me.setup(m)
		me.delete_request.connect(_on_meta_edit_delete_request.bind(me))
		_meta_container.add_child(me)

	for i in range(_table_tool_options.item_count):
		if _table_tool_options.get_item_metadata(i) == preset.table_tool_script_file:
			_table_tool_options.select(i)
			break

	for i in range(_import_tool_options.item_count):
		if _import_tool_options.get_item_metadata(i) == preset.import_tool_script_file:
			_import_tool_options.select(i)
			break


func _set_to_preset(preset: _Preset) -> void:
	preset.name = _preset_name_line_edit.text
	preset.data_class = _klass_name_line_edit.text
	preset.data_class_script = _script_line_edit.text
	preset.table_name = %TableNameLineEdit.text.strip_edges()
	preset.skip_prefix_underscore_properties = %SkipPrefixUnderscoreCheckBox.button_pressed
	preset.only_strage_properties = _only_storage_check_box.button_pressed
	preset.no_inheritance = _no_inheritance_check_box.button_pressed
	preset.ascending_order = _ascending_check_box.button_pressed
	preset.instantiation = _instantiation_line_edit.text
	preset.priority_properties = Array(_priority_line_edit.text.split(",", false)).map(func(text: String): return text.strip_edges())
	preset.ignored_properties = Array(%IgnoreLineEdit.text.split(",", false)).map(func(text: String): return text.strip_edges())
	preset.table_ouput_path = _output_line_edit.text
	preset.need_meta_properties = Array(%MetaPriorityLineEdit.text.split(",", false)).map(func(text: String): return text.strip_edges())
	preset.auto_backup = %BackupCheckBox.button_pressed
	preset.auto_merge = %MergeCheckBox.button_pressed
	preset.import_path = _table_import_line_edit.text
	preset.table_tool_options = Array(%TableOptionsLineEdit.text.split(",", false)).map(func(text: String): return text.strip_edges())
	preset.import_tool_options = Array(%ImportOptionsLineEdit.text.split(",", false)).map(func(text: String): return text.strip_edges())
	preset.generate_modifier_file = %GenerateModifierLineEdit.text
	preset.import_mofifier_file = %ImportModifierLineEdit.text

	preset.additional_properties.clear()
	for ape in _ap_contianer.get_children():
		ape = ape as _AdditionalPropertyEdit
		if not is_instance_valid(ape):
			continue
		var ap := {}  # _Preset._AdditionalProperty.new()
		ap["name"] = ape.get_property_name()
		ap["type"] = ape.get_type()
		ap["setter"] = ape.get_setter()
		preset.additional_properties.push_back(ap)

	preset.descriptions.clear()
	for pde in _desc_container.get_children():
		pde = pde as _PropertyDescriptionEdit
		if not is_instance_valid(pde):
			continue
		if preset.descriptions.has(pde.get_property_name()):
			_Log.warning([tr("重复的字段描述将被跳过: "), pde.get_property_name(), " - ", pde.get_description()])
			continue
		preset.descriptions[pde.get_property_name()] = pde.get_description()

	preset.metas.clear()
	for me in _meta_container.get_children():
		me = me as _MetaEdit
		if not is_instance_valid(me):
			continue
		preset.metas.push_back(me.get_meta_text())

	var m = _table_tool_options.get_selected_metadata()
	if typeof(m) == TYPE_STRING:
		preset.table_tool_script_file = m
	else:
		preset.table_tool_script_file = ""

	m = _import_tool_options.get_selected_metadata()
	if typeof(m) == TYPE_STRING:
		preset.import_tool_script_file = m
	else:
		preset.import_tool_script_file = ""


#endregion


#--------------------------------------
#region 回调
func _on_preset_options_selected(idx: int) -> void:
	var preset: _Preset
	if idx == 0:
		preset = _Preset.new()
	else:
		preset = _preset_options.get_item_metadata(idx)
	if not is_instance_valid(preset):
		_Log.error([tr("Bug，请提交issue并提供复现步骤")])
		return
	_load_preset(preset)


func _on_save_btn_pressed() -> void:
	_save_preset()


func _on_delete_btn_pressed() -> void:
	if _preset_options.selected < 0:
		_Log.error([tr("删除预设失败,未选中预设")])
		return

	_confirmation_dialog.popup_centered()
	if not await _confirmed:
		return

	var preset = _preset_options.get_item_metadata(_preset_options.selected) as _Preset
	if not is_instance_valid(preset):
		_Log.error([tr("Bug，请提交issue并提供复现步骤")])
		return

	_delete_preset(preset)


func _on_script_select_btn_pressed() -> void:
	var path = _script_line_edit.text
	_pop_file_dialog(tr("选择脚本"), FileDialog.FILE_MODE_OPEN_FILE, _get_script_filters(), path)
	var result = await _path_selected as Array
	if not result[0]:
		return
	_script_line_edit.text = result[1]


func _on_generate_modifier_select_btn_pressed() -> void:
	var path = %GenerateModifierLineEdit.text
	_pop_file_dialog(tr("选择脚本"), FileDialog.FILE_MODE_OPEN_FILE, _get_script_filters(), path)
	var result = await _path_selected as Array
	if not result[0]:
		return
	%GenerateModifierLineEdit.text = result[1]


func _on_import_modifier_select_btn_pressed() -> void:
	var path = %ImportModifierLineEdit.text
	_pop_file_dialog(tr("选择脚本"), FileDialog.FILE_MODE_OPEN_FILE, _get_script_filters(), path)
	var result = await _path_selected as Array
	if not result[0]:
		return
	%ImportModifierLineEdit.text = result[1]


func _on_add_additional_property_btn_pressed() -> void:
	var ape = _ap_edit_scene.instantiate()
	ape.delete_request.connect(_on_additional_property_delete_request.bind(ape))
	_ap_contianer.add_child(ape)


func _on_add_desc_btn_pressed() -> void:
	var pde = _pd_edit_scene.instantiate()
	pde.delete_request.connect(_on_property_description_delete_request.bind(pde))
	_desc_container.add_child(pde)


func _on_add_meta_btn_pressed() -> void:
	var me = _meta_edit_scene.instantiate()
	me.delete_request.connect(_on_meta_edit_delete_request.bind(me))
	_meta_container.add_child(me)


func _on_output_select_btn_pressed() -> void:
	var path = _output_line_edit.text
	# "*.csv;CSV表格"
	_pop_file_dialog(tr("输出文件"), FileDialog.FILE_MODE_OPEN_FILE, [], path)
	var result = await _path_selected as Array
	if not result[0]:
		return
	_output_line_edit.text = result[1]


func _on_additional_property_delete_request(ape: _AdditionalPropertyEdit) -> void:
	_ap_contianer.remove_child(ape)
	ape.queue_free()


func _on_property_description_delete_request(pde: _PropertyDescriptionEdit) -> void:
	_desc_container.remove_child(pde)
	pde.queue_free()


func _on_meta_edit_delete_request(me: _MetaEdit) -> void:
	_meta_container.remove_child(me)
	me.queue_free()


func _on_settings_tools_updated() -> void:
	var selecting_table_tool = _table_tool_options.get_selected_metadata()
	_table_tool_options.clear()
	var table_tools := _settings.table_tools
	var table_option_idx := -1
	for n in table_tools:
		_table_tool_options.add_item("%s: %s" % [n, table_tools[n]])
		_table_tool_options.set_item_metadata(_table_tool_options.item_count - 1, table_tools[n])
		if selecting_table_tool == table_tools[n]:
			table_option_idx = _table_tool_options.item_count - 1
	if table_option_idx >= 0:
		_table_tool_options.select(table_option_idx)

	var selecting_import_tool = _import_tool_options.get_selected_metadata()
	_import_tool_options.clear()
	var import_option_idx := -1
	var import_tools := _settings.import_tools
	for n in import_tools:
		_import_tool_options.add_item("%s: %s" % [n, import_tools[n]])
		_import_tool_options.set_item_metadata(_import_tool_options.item_count - 1, import_tools[n])
		if selecting_import_tool == import_tools[n]:
			import_option_idx = _import_tool_options.item_count - 1
	if import_option_idx >= 0:
		_import_tool_options.select(import_option_idx)


func _on_gen_and_import_tab_visibility_changed() -> void:
	if not _gen_and_import_tab.visible:
		return

	var presets: Array[_Preset] = []
	var dir := EditorInterface.get_resource_filesystem().get_filesystem_path(_settings.presets_dir)
	if is_instance_valid(dir):
		for i in range(dir.get_file_count()):
			if dir.get_file_type(i) != &"Resource":
				continue
			var preset = _load(dir.get_file_path(i)) as _Preset
			if not is_instance_valid(preset):
				continue

			presets.append(preset)

	%GenerateTables.setup(presets)
	%ImportTables.setup(presets)


#endregion


#--------------------------------------
func _load(path: String) -> Resource:
	var ret = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if is_instance_valid(ret) and ret.resource_path.is_empty():
		# 兼容 4.2
		ret.take_over_path(path)
		#ret.resource_path = path
	return ret


func _get_script_filters() -> PackedStringArray:
	var ret: PackedStringArray = ["*.gd;GDScript"]
	if ClassDB.class_exists(&"CSharpScript"):
		ret.push_back("*.cs;CSharpScript")
	for klass in ClassDB.get_inheriters_from_class(&"ScriptLanguageExtension"):
		if not ClassDB.can_instantiate(klass):
			continue
		var script := ClassDB.instantiate(klass) as ScriptExtension
		if not is_instance_valid(script):
			continue
		var language := script._get_language() as ScriptLanguageExtension
		if not is_instance_valid(language):
			continue
		var extension := language._get_extension() as String
		var script_name := language._get_name() as String
		if extension.is_empty() or script_name.is_empty():
			continue
		ret.push_back("*.%s;%s" % [extension, script_name])
	return ret
