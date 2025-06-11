@tool
extends Resource

const _Log = preload("log.gd")
const _TableHeader = preload("table_header.gd")
const _TableTool = preload("../table_tools/table_tool.gd")
const _ImportTool = preload("../import_tools/import_tool.gd")
const _GenerateModifier = preload("generate_modifier.gd")
const _ImportModifier = preload("import_modifier.gd")
const _Localize = preload("../localization/localize.gd")

const _DEFAULT_GENERATE_MODIFIER_FILE := "res://addons/config_table_manager.daylily-zeleen/scripts/generate_modifier.gd"
const _DEFAULT_IMPORT_MODIFIER_FILE := "res://addons/config_table_manager.daylily-zeleen/scripts/import_modifier.gd"

@export_group("Editor Tool")
# 触发生成
@export var trigger_generate_table: bool = false:
	set(v):
		if v:
			generate_table()
# 触发导入
@export var trigger_import_table: bool = false:
	set(v):
		if v:
			import_table()

@export_group("Basic")
@export var name: String
# 数据类
@export var data_class: String
var data_class_script: String:
	set(v):
		_data_class_script = _get_script_by_path(v)
	get:
		return _get_script_file_path(_data_class_script)
@export var _data_class_script: Script # 为保兼容性，仅作为保存用的脚本引用
@export var table_name: String

# 表格生成选项
@export var skip_prefix_underscore_properties: bool = false
@export var only_storage_properties: bool = false
@export var no_inheritance: bool = true
@export var ascending_order: bool = false
@export var auto_backup: bool = false #
@export var auto_merge: bool = true #
@export var priority_properties: PackedStringArray:
	get:
		return _strip_str_arr_elements_edges(priority_properties)
@export var ignored_properties: PackedStringArray:
	get:
		return _strip_str_arr_elements_edges(ignored_properties)

@export_group("Table")
@export var table_tool_options: PackedStringArray:
	get:
		return _strip_str_arr_elements_edges(table_tool_options)
# Deprecated
var table_tool_script_file: String:
	set(v):
		table_tool_script = _get_script_by_path(v)
	get:
		return _get_script_file_path(table_tool_script)
@export var table_tool_script: Script = preload("res://addons/config_table_manager.daylily-zeleen/table_tools/csv.gd")
@export_file() var table_output_path: String = "res://tables/{table_name}.csv"
# Deprecated
var generate_modifier_file: String:
	set(v):
		generate_modifier = _get_script_by_path(v)
	get:
		return _get_script_file_path(generate_modifier)
@export var generate_modifier: Script = preload(_DEFAULT_GENERATE_MODIFIER_FILE)

@export_group("Import")
# 表格导入选项
@export var instantiation: String
@export var import_tool_options: PackedStringArray:
	get:
		return _strip_str_arr_elements_edges(import_tool_options)
var import_tool_script_file: String:
	set(v):
		import_tool_script = _get_script_by_path(v)
	get:
		return _get_script_file_path(import_tool_script)
@export var import_tool_script: Script = preload("res://addons/config_table_manager.daylily-zeleen/import_tools/gdscript_default.gd")
@export_file() var import_path: String = "res://tables/imported/{table_name}.gd"
# Deprecated
var import_modifier_file: String:
	set(v):
		import_modifier = _get_script_by_path(v)
	get:
		return _get_script_file_path(import_modifier)
@export var import_modifier: Script = preload(_DEFAULT_IMPORT_MODIFIER_FILE)

@export_group("Addtional")
# 附加
@export var additional_properties: Array[Dictionary]
@export var descriptions: Dictionary
@export var meta_list: PackedStringArray
# 需要meta的字段，生成时将在对应的字段下一列插入一列#开头的字段，仅用于编辑时，不会被导入
@export var need_meta_properties: PackedStringArray:
	get:
		return _strip_str_arr_elements_edges(need_meta_properties)

#region 旧版兼容
func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"only_strage_properties":
			only_storage_properties = value
		&"table_ouput_path":
			table_output_path = value
		&"metas":
			meta_list = value
		_:
			return false
	return true


func _get(property: StringName) -> Variant:
	match property:
		&"only_strage_properties":
			return only_storage_properties
		&"table_ouput_path":
			return table_output_path
		&"metas":
			return meta_list
	return null
#endregion 旧版兼容


## enable_modifier: 是否启用修改器
## func_modify_data: Callable 修改要生成的数据行,参数为 Array[Dictionary], 返回修改后的数据 Array[Dictionary]
func generate_table(enable_modifier: bool = true, func_modify_data: Callable = Callable()) -> Error:
	if table_name.is_empty():
		_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("表格名不能为空")])
		return ERR_INVALID_PARAMETER

	instantiation = instantiation.strip_edges()
	var instantiation_method := "new" if instantiation.is_empty() else instantiation.split("(")[0]
	var instantiation_args := Array([] if instantiation.is_empty() or instantiation.ends_with("()") else Array(instantiation.trim_suffix(")").split("(")).back().split(",", false)).map(
		func(a: String) -> String: return a.strip_edges().trim_prefix("{").trim_suffix("}")
	) as PackedStringArray

	var script: Script = _data_class_script
	var property_list: Array[Dictionary]

	if is_instance_valid(script):
		if not data_class.is_empty():
			# 脚本内部类
			script = script[data_class]
			if not is_instance_valid(script):
				_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("非法内部类"), " - ", data_class])
				return ERR_INVALID_PARAMETER

		_append_base_property_list_recursively_script(no_inheritance, script, property_list)
	else:
		if instantiation_method != "new":
			if not ClassDB.class_has_method(data_class, instantiation_method):
				_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("原生类不存在需要的静态实例化方法"), " - ", data_class, " - ", instantiation_method])
				return ERR_INVALID_PARAMETER
		_append_base_property_list_recursively(no_inheritance, data_class, property_list)

	# 排除忽略的属性
	property_list = property_list.filter(func(p: Dictionary) -> bool: return not p["name"] in ignored_properties)

	# 附加属性检查
	for ap in additional_properties:
		if not _is_ap_valid(ap):
			return ERR_INVALID_PARAMETER

	if skip_prefix_underscore_properties:
		property_list = property_list.filter(func(p: Dictionary) -> bool: return not p["name"].begins_with("_"))

	# 仅 PROPERTY_USAGE_STORAGE
	if only_storage_properties:
		property_list = property_list.filter(func(p: Dictionary) -> bool: return p["usage"] & PROPERTY_USAGE_STORAGE)

	# 表格工具实例化
	if not is_instance_valid(table_tool_script):
		_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("表格工具脚本不存在: "), table_tool_script.resource_path])
		return ERR_INVALID_PARAMETER

	if table_tool_script.reload() != OK:
		_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("表格工具脚本不存在: "), table_tool_script.resource_path])
		return ERR_INVALID_PARAMETER

	if not table_tool_script.can_instantiate():
		_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("表格工具无法被实例化: "), table_tool_script.resource_path])
		return ERR_INVALID_PARAMETER

	var table_tool := table_tool_script.new() as _TableTool
	if not is_instance_valid(table_tool):
		_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("脚本不是继承自合法的表格工具: "), table_tool_script.resource_path])
		_Log.error(["\t- ", _Localize.translate("请查阅: "), "res://addons/config_table_manager.daylily-zeleen/table_tools/table_tool.gd"])
		return ERR_INVALID_PARAMETER

	var table_file := table_output_path.replace("{table_name}", table_name.capitalize().replace(" ", "_").to_lower())

	if table_tool.get_table_file_extension().to_lower() != table_file.get_extension().to_lower():
		_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("表格工具不支持该扩展名: "), table_output_path])
		return ERR_INVALID_PARAMETER

	# 过滤不支持的类型
	property_list = property_list.filter(_exclude_unsupported_type_filter.bind(table_tool.get_support_types()))

	# 添加附加属性
	for ap in additional_properties:
		var ap_name: String = ap.name.strip_edges()

		if property_list.filter(func(p: Dictionary) -> bool: return p["name"] == ap_name).size():
			_Log.warning([name, " - ", _Localize.translate("重复的附加字段将被跳过："), ap_name])
			continue

		property_list.append({"name": ap_name, "type": ap.type})

	# 检查实例化需要的参数
	for arg in instantiation_args:
		if property_list.filter(func(p: Dictionary) -> bool: return p["name"] == arg).is_empty():
			_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("被生成的属性中缺少需要的实例化参数: "), arg])
			return ERR_INVALID_PARAMETER

	# 升序
	if ascending_order:
		property_list.sort_custom(_sort_ascending)

	# 优先排序
	for i in range(priority_properties.size() - 1, -1, -1):
		var prop_name := priority_properties[i].strip_edges()
		var filtered := property_list.filter(func(p: Dictionary) -> bool: return p["name"] == prop_name)
		if filtered.size() <= 0:
			_Log.warning([name, " - ", _Localize.translate("不存在的优先排序字段将被跳过: "), prop_name])
			continue
		# 将其调到最前端
		var first := filtered.front() as Dictionary
		property_list.erase(first)
		property_list.push_front(first)

	# 将meta字段插入
	var need_meta_props := Array(need_meta_properties).map(func(e: String) -> String: return e.strip_edges()) as PackedStringArray
	if need_meta_props.size():
		var idx := 0
		while idx < property_list.size():
			var p := property_list[idx] as Dictionary
			if need_meta_props.has(p["name"]):
				idx += 1
				property_list.insert(idx, {"name": "#" + p["name"], "type": TYPE_STRING})
			idx += 1

	var backup_file := _converted_to_backup_file_path(table_file)

	var data: Array[Dictionary] = []
	if FileAccess.file_exists(table_file):
		if not DirAccess.dir_exists_absolute(backup_file.get_base_dir()):
			var make_dir_err := DirAccess.make_dir_recursive_absolute(backup_file.get_base_dir())
			if make_dir_err != OK:
				_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("无法创建备份路径: "), backup_file.get_base_dir()])
				return make_dir_err

		var copy_err := DirAccess.copy_absolute(table_file, backup_file)
		if copy_err != OK:
			_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("无法创建备份: "), backup_file])
			return copy_err

		# 自动合并
		if auto_merge:
			var parse_err := table_tool.parse_table_file(table_file, table_tool_options)
			if parse_err != OK:
				_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("指定的表格工具无法解析已有的表格: "), table_file])
				return parse_err
			data = table_tool.get_data().duplicate(true)

	# 修改器
	var modified_fields := property_list.map(func(p: Dictionary) -> String: return p["name"]) as PackedStringArray
	var modified_types := property_list.map(func(p: Dictionary) -> int: return p["type"]) as PackedByteArray
	var modified_data := data
	var modified_options := table_tool_options.duplicate()
	var modified_meta_list := meta_list.duplicate()
	var modified_desc := descriptions.duplicate()
	if enable_modifier:
		if not is_instance_valid(generate_modifier):
			generate_modifier = ResourceLoader.load(_DEFAULT_GENERATE_MODIFIER_FILE, "Script", ResourceLoader.CACHE_MODE_IGNORE)

		if generate_modifier.reload(false) != OK:
			_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("无效的生成修改器脚本: "), generate_modifier.resource_path])
			return ERR_INVALID_PARAMETER

		if not generate_modifier.can_instantiate():
			_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("生成修改器无法被实例化: "), generate_modifier.resource_path])
			return ERR_INVALID_PARAMETER

		var modifier := generate_modifier.new() as _GenerateModifier
		if not is_instance_valid(modifier):
			_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("脚本不是继承自合法的合法的生成修改器: "), generate_modifier.resource_path])
			_Log.error(["\t- ", _Localize.translate("请查阅: "), "res://addons/config_table_manager.daylily-zeleen/scripts/generate_modifier.gd"])
			return ERR_INVALID_PARAMETER

		# 修改
		modifier.begin_modify(table_name, data_class.strip_edges(), data_class_script.strip_edges())
		modifier.modify_fields_definitions(modified_fields, modified_types)
		modified_data = modifier.modify_data(modified_data)
		modified_desc = modifier.modify_descriptions(modified_desc)
		modified_meta_list = modifier.modify_meta_list(modified_meta_list)
		modified_options = modifier.modify_table_tool_options(modified_options)

	# 通过数据修改方法修改数据
	if func_modify_data.is_valid():
		modified_data = func_modify_data.call(modified_data)

	var data_rows: Array[PackedStringArray]
	if not modified_data.is_empty():
		data_rows = table_tool.to_data_rows(modified_data, modified_fields, modified_types)

	# 准备表头
	var header := _TableHeader.new()
	header.meta_list = modified_meta_list
	header.fields = modified_fields
	header.types = Array(modified_types).map(func(t: int) -> String: return type_string(t)) as PackedStringArray
	header.descriptions.resize(header.fields.size())
	for i in range(header.fields.size()):
		var f := header.fields[i]
		if f.begins_with("#"):
			header.descriptions[i] = _Localize.translate("不被导入")
		elif modified_desc.has(f):
			header.descriptions[i] = modified_desc[f]

	var err := table_tool.generate_table_file(table_file, header, data_rows, table_tool_options)
	if not auto_backup:
		# 不需要备份，删除
		DirAccess.remove_absolute(backup_file)

	if err != OK:
		_Log.error([name, " - ", _Localize.translate("生成表格失败："), error_string(err)])
		return err

	_Log.info([name, " - ", _Localize.translate("生成表格成功："), table_file])
	_update_file_change(table_file)
	return OK


## enable_modifier: 是否启用修改器
func import_table(enable_modifier: bool = true) -> Error:
	# 表格工具
	if not is_instance_valid(table_tool_script):
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("表格工具脚本不存在："), table_tool_script.resource_path])
		return ERR_INVALID_PARAMETER

	if table_tool_script.reload(false) != OK:
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("表格工具脚本不存在："), table_tool_script.resource_path])
		return ERR_INVALID_PARAMETER

	if not table_tool_script.can_instantiate():
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("表格工具无法被实例化："), table_tool_script.resource_path])
		return ERR_INVALID_PARAMETER

	var table_tool := table_tool_script.new() as _TableTool
	if not is_instance_valid(table_tool):
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("脚本不是继承自合法的表格工具："), table_tool_script.resource_path])
		_Log.error(["\t- ", _Localize.translate("请查阅: "), "res://addons/config_table_manager.daylily-zeleen/table_tools/table_tool.gd"])
		return ERR_INVALID_PARAMETER

	var table_file := table_output_path.replace("{table_name}", table_name.capitalize().replace(" ", "_").to_lower())

	if table_tool.get_table_file_extension().to_lower() != table_file.get_extension().to_lower():
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("表格工具不支持该扩展名："), table_output_path])
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(table_file):
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("表格不存在："), table_file])
		return ERR_FILE_NOT_FOUND

	var err := table_tool.parse_table_file(table_output_path.replace("{table_name}", table_name.capitalize().replace(" ", "_").to_lower()), table_tool_options)
	if err != OK:
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("指定表格工具无法解析表格："), error_string(err)])
		return err

	# 导入工具
	if not is_instance_valid(import_tool_script):
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("指定导入工具不存在："), import_tool_script.resource_path])
		return ERR_INVALID_PARAMETER

	if not import_tool_script.can_instantiate():
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("指定导入工具无法实例化："), import_tool_script.resource_path])
		return ERR_INVALID_PARAMETER

	var header := table_tool.get_header()
	if not is_instance_valid(header):
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("指定表格工具无法解析表格："), error_string(ERR_PARSE_ERROR)])
		return ERR_PARSE_ERROR

	var custom_setters := {}
	for ap in additional_properties:
		if not ap.setter.is_empty():
			custom_setters[ap.name] = ap.setter

	# 修改器
	var modified_table_name := table_name
	var modified_custom_setter := custom_setters
	var modified_data := table_tool.get_data().duplicate(true)
	var modified_options := import_tool_options.duplicate()
	if enable_modifier:
		if not is_instance_valid(import_modifier):
			import_modifier = ResourceLoader.load(_DEFAULT_IMPORT_MODIFIER_FILE, "Script", ResourceLoader.CACHE_MODE_IGNORE)

		if import_modifier.reload(false) != OK:
			_Log.error([name, " - ", _Localize.translate("导入表格失败："), _Localize.translate("无效的导入修改器脚本: "), import_modifier.resource_path])
			return ERR_INVALID_PARAMETER

		if not import_modifier.can_instantiate():
			_Log.error([name, " - ", _Localize.translate("导入表格失败："), _Localize.translate("导入修改器无法被实例化: "), import_modifier.resource_path])
			return ERR_INVALID_PARAMETER

		var modifier := import_modifier.new() as _ImportModifier
		if not is_instance_valid(modifier):
			_Log.error([name, " - ", _Localize.translate("导入表格失败："), _Localize.translate("脚本不是继承自合法的合法的导入修改器: "), import_modifier.resource_path])
			_Log.error(["\t- ", _Localize.translate("请查阅: "), "res://addons/config_table_manager.daylily-zeleen/scripts/import_modifier.gd"])
			return ERR_INVALID_PARAMETER

		# 修改
		modifier.begin_modify(table_name, data_class.strip_edges(), data_class_script.strip_edges())
		modified_table_name = modifier.modify_table_name(modified_table_name)
		modified_custom_setter = modifier.modify_custom_setters(modified_custom_setter)
		modified_data = modifier.modify_data(modified_data)
		header.meta_list = modifier.modify_meta_list(header.meta_list)
		modified_options = modifier.modify_import_tool_options(modified_options)

	var inst := instantiation.strip_edges()
	if inst.is_empty():
		inst = "new()"

	var script: Script = _data_class_script
	if is_instance_valid(script):
		if not data_class.is_empty():
			# 脚本内部类
			script = script[data_class]
			if not is_instance_valid(script):
				_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("非法内部类"), " - ", data_class])
				return ERR_INVALID_PARAMETER

		if not Engine.is_editor_hint() and not script.can_instantiate():
			# 只在非编辑器下进行检查
			_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("类无法被实例化"), " - ", data_class_script, " - ", data_class])
			return ERR_INVALID_PARAMETER

		if not inst.begins_with("new"):
			if script.get_script_method_list().filter(func(m: Dictionary) -> bool: return m["name"] == inst.split("(")[0] and m["flags"] & METHOD_FLAG_STATIC).is_empty():
				_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("脚本类不存在需要的静态实例化方法"), " - ", data_class_script, " - ", inst])
				return ERR_INVALID_PARAMETER
	else:
		if not ClassDB.class_exists(data_class) or not ClassDB.can_instantiate(data_class):
			_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("原生类不存在或者不能被实例化"), " - ", data_class])
			return ERR_INVALID_PARAMETER

		if not inst.begins_with("new"):
			if not ClassDB.class_has_method(data_class, inst.split("(")[0]):
				_Log.error([name, " - ", _Localize.translate("生成表格失败："), _Localize.translate("原生类不存在需要的静态实例化方法"), " - ", data_class, " - ", inst])
				return ERR_INVALID_PARAMETER

	var import_tool := import_tool_script.new() as _ImportTool
	if not is_instance_valid(import_tool):
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("指定脚本不是继承自导入工具："), import_tool_script.resource_path])
		_Log.error(["\t- ", _Localize.translate("请查阅: "), "res://addons/config_table_manager.daylily-zeleen/import_tools/import_tool.gd"])
		return ERR_INVALID_PARAMETER

	var import_file_path := import_path.replace("{table_name}", table_name.capitalize().replace(" ", "_").to_lower())
	if import_tool.get_import_file_extension().to_lower() != import_file_path.get_extension().to_lower():
		_Log.error([name, " - ", _Localize.translate("导入失败:"), _Localize.translate("导入工具不支持该扩展名："), import_file_path])
		return ERR_INVALID_PARAMETER

	if not DirAccess.dir_exists_absolute(import_file_path.get_base_dir()):
		err = DirAccess.make_dir_recursive_absolute(import_file_path.get_base_dir())
		if err != OK:
			_Log.error([name, " - ", _Localize.translate("导入失败,无法创建导入路径:"), import_file_path.get_base_dir(), " - ", error_string(err)])
			return err

	err = import_tool.import(import_file_path, modified_table_name, header, data_class, data_class_script, inst, modified_custom_setter, modified_data, modified_options)
	if err != OK:
		_Log.error([name, " - ", _Localize.translate("导入失败:"), error_string(err)])
		return err

	_Log.info([name, " - ", _Localize.translate("导入表格成功:"), import_file_path])
	_update_file_change(import_file_path)
	return OK


#---------------------
func _get_script_by_path(path: String) -> Script:
	if FileAccess.file_exists(path) and ResourceLoader.exists(path, &"Script"):
		return load(path)
	return null


func _get_script_file_path(script: Script) -> String:
	if is_instance_valid(script):
		return script.resource_path
	return ""


func _strip_str_arr_elements_edges(str_arr: PackedStringArray) -> PackedStringArray:
	for i in range(str_arr.size()):
		str_arr[i] = str_arr[i].strip_edges()
	return str_arr


func _update_file_change(file: String) -> void:
	if not Engine.is_editor_hint():
		return
	EditorInterface.get_resource_filesystem().update_file(file)
	var file_type := EditorInterface.get_resource_filesystem().get_file_type(file)
	if ClassDB.is_parent_class(file_type, &"Script"):
		if Engine.get_main_loop().has_meta(&"__HACK_TIMER__"):
			return
		var timer := (Engine.get_main_loop() as SceneTree).create_timer(1.0)
		timer.timeout.connect(func() -> void:
			# Hack
			EditorInterface.get_script_editor().notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
			Engine.get_main_loop().remove_meta(&"__HACK_TIMER__")
		)
		Engine.get_main_loop().set_meta(&"__HACK_TIMER__", timer)
	elif file_type == &"Resource" or ClassDB.is_parent_class(file_type, &"Resource"):
		EditorInterface.get_resource_filesystem().reimport_files([file])


func _converted_to_backup_file_path(origin_path: String) -> String:
	var base_dir := origin_path.get_base_dir().path_join(".backup")
	var prefix := ".%s_" % (Time.get_datetime_string_from_system().replace(":", "-") + str(Time.get_unix_time_from_system()))
	return base_dir.path_join(prefix + origin_path.get_file())


func _get_custom_setter(prop_name: String) -> String:
	var filtered := additional_properties.filter(func(ap: Dictionary) -> bool: return ap.get("name", "").strip_edges() == prop_name)
	if filtered.size():
		return filtered.front().get("setter", "")
	return ""


func _exclude_unsupported_type_filter(p: Dictionary, support_types: PackedByteArray) -> bool:
	var t := p["type"] as int
	if not t in support_types:
		_Log.warning([name, " - ", _Localize.translate("不支持的属性类型将被跳过:"), p["name"], " - ", type_string(t), " ", _Localize.translate("如果是脚本类型可以安全忽略。")])
		return false
	return true


func _sort_ascending(a: Dictionary, b: Dictionary) -> bool:
	var an := a["name"] as String
	var bn := b["name"] as String
	return an > bn


func _append_base_property_list_recursively_script(p_no_inheritance: bool, script: Script, r_property_list: Array[Dictionary]) -> void:
	if not is_instance_valid(script):
		return
	r_property_list.append_array(script.get_script_property_list())

	if p_no_inheritance:
		return

	var base := script.get_base_script()
	if is_instance_valid(base):
		_append_base_property_list_recursively_script(p_no_inheritance, script, r_property_list)
	else:
		_append_base_property_list_recursively(p_no_inheritance, script.get_instance_base_type(), r_property_list)


func _append_base_property_list_recursively(p_no_inheritance: bool, klass: StringName, r_property_list: Array[Dictionary]) -> void:
	if klass.is_empty():
		return

	if klass in [&"Object", &"RefCounted", &"Resource", &"Node"]:
		# 跳过基础类
		return

	r_property_list.append_array(ClassDB.class_get_property_list(klass, true))

	if p_no_inheritance:
		return

	_append_base_property_list_recursively(p_no_inheritance, ClassDB.get_parent_class(klass), r_property_list)


func _is_ap_valid(ap: Dictionary) -> bool:
	ap["name"] = ap.get("name", "").strip_edges()
	if not TextServerManager.get_primary_interface().is_valid_identifier(ap["name"]):
		_Log.error([_Localize.translate("非法属性名称: "), ap["name"]])
		return false

	var type := ap["type"] as int
	if type in [TYPE_NIL, TYPE_OBJECT, TYPE_CALLABLE, TYPE_SIGNAL, TYPE_RID]:
		_Log.error([_Localize.translate("非法属性类型: "), name, " - ", type_string(type)])
		return false

	return true
