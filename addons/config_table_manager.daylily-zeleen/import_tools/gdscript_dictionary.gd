## 字典形式的 GDScript 导入，适合表格条目较多的情况
## Required Options:
##	key=prop_name - 必选，指定用于查找的数据类属性,该属性的值在所有数据中不能重复,也不能留空
## Options:
##	generate_class_name - 如果 table_name 非空且是合法的标识符，将使用 table_name 生成全局类名
##	pure_static=true/false - 是否以纯静态成员的形式进行生成, 默认为 true
@tool
extends "gdscript_default.gd"


func _import(
	import_path: String,
	table_name: String,
	header: _TableHeader,
	data_class_name: String,
	data_class_script: String,
	instantiation: String,
	custom_setters: Dictionary,
	data_rows: Array[Dictionary],
	options: PackedStringArray
) -> Error:
	var option_pairs := parse_options(options)

	var priority_key := option_pairs.get("key", "") as String
	if priority_key.is_empty():
		_Log.error([table_name, " ", _Localize.translate("导表失败: "), _Localize.translate("未指定作为key的数据类属性，请使用 key=prop_name 作为选项参数进行指定。")])
		return ERR_INVALID_PARAMETER

	var fa := FileAccess.open(import_path, FileAccess.WRITE)
	if not is_instance_valid(fa):
		_Log.error([_Localize.translate("导表失败: "), error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()

	var pure_static := (option_pairs.get("pure_static", "true") as String).to_lower() == "true"
	var member_prefix := "static " if pure_static else ""
	if pure_static:
		fa.store_line("@static_unload")

	if TextServerManager.get_primary_interface().is_valid_identifier(table_name) and option_pairs.has("generate_class_name"):
		fa.store_line("class_name %s" % table_name)
		fa.store_line("")

	# TABLE_META_LIST
	var meta_list_text := ""
	for m in header.meta_list:
		if not meta_list_text.is_empty():
			meta_list_text += ", "
		meta_list_text += '"%s"' % m
	fa.store_line("const TABLE_META_LIST: PackedStringArray = [%s]" % meta_list_text)
	fa.store_line("")

	# DataClass
	var property_list: Array[Dictionary]
	var property_default_values := {}
	var data_class := ""
	if not data_class_script.is_empty():
		var internal_class := "" if data_class_name.is_empty() else ".%s" % data_class_name
		fa.store_line('const DataClass = preload("%s")%s' % [data_class_script, internal_class])
		fa.store_line("")
		data_class = "DataClass"

		# 获取属性列表
		var script := ResourceLoader.load(data_class_script, "Script", ResourceLoader.CACHE_MODE_IGNORE) as Script
		if not data_class_name.is_empty():
			var internal := data_class_name.split(".", false)
			while not internal.is_empty():
				script = script.get_script_constant_map()[internal[0]]
				internal.remove_at(0)
		var base := script
		while true:
			property_list.append_array(base.get_script_property_list())
			if not is_instance_valid(base.get_base_script()):
				property_list.append_array(ClassDB.class_get_property_list(base.get_instance_base_type()))
				var tmp_obj := ClassDB.instantiate(base.get_instance_base_type()) as Object
				for p in property_list:
					var n := p["name"] as String
					if n in tmp_obj:
						property_default_values[n] = tmp_obj.get(n)
				break
			base = base.get_base_script()

		for p in property_list:
			var n := p["name"] as String
			if n in property_default_values:
				continue
			property_default_values[n] = script.get_property_default_value(n)
	else:
		data_class = data_class_name
		property_list = ClassDB.class_get_property_list(data_class_name)
		var tmp_obj := ClassDB.instantiate(data_class_name) as Object
		for p in property_list:
			var n := p["name"] as String
			if n in tmp_obj:
				property_default_values[n] = tmp_obj.get(n)

	var existed_values := []
	for d in data_rows:
		var v: Variant = d.get(priority_key, null)
		if typeof(v) == TYPE_NIL:
			_Log.error([table_name, " ", _Localize.translate("导表失败: "), _Localize.translate("存在未配置key (%s)的数据: %s。") % [priority_key, d]])
			return ERR_INVALID_PARAMETER
		if existed_values.has(v):
			_Log.error([table_name, " ", _Localize.translate("导表失败: "), _Localize.translate("存在key (%s)重复的数据，重复的值为: %s。") % [priority_key, v]])
			return ERR_INVALID_PARAMETER
		existed_values.push_back(v)

	var fields := header.fields.duplicate()
	var types := Array(header.types).map(to_type_id) as PackedByteArray

	if not fields.has(priority_key):
		_Log.error([table_name, " ", _Localize.translate("导表失败: "), _Localize.translate("数据类不存在指定为key的属性 %s，请使用 key=prop_name 作为选项参数进行指定。") % [priority_key]])
		return ERR_INVALID_PARAMETER

	var priority_key_type_id: int = types[fields.find(priority_key)]

	# get_data
	fa.store_line(member_prefix + "func get_data() -> Dictionary:")
	fa.store_line("\treturn _data")
	fa.store_line("")
	fa.store_line("")

	# get_record
	fa.store_line(member_prefix + "func get_record(key: %s) -> %s:" % [type_string(priority_key_type_id), data_class])
	fa.store_line("\treturn _data.get(key, null)")
	fa.store_line("")
	fa.store_line("")

	# find_by_property
	fa.store_line(member_prefix + "func find_by_property(prop_name: StringName, target_value: Variant) -> %s:" % data_class)
	fa.store_line("\tfor d: DataClass in _data.values():")
	fa.store_line("\t\tif d.get(prop_name) == target_value:")
	fa.store_line("\t\t\treturn d")
	fa.store_line("\treturn null")
	fa.store_line("")
	fa.store_line("")

	# find_by_getter
	fa.store_line(member_prefix + "func find_by_getter(getter_name: StringName, target_value: Variant) -> %s:" % data_class)
	fa.store_line("\tfor d: DataClass in _data.values():")
	fa.store_line("\t\tif d.call(getter_name) == target_value:")
	fa.store_line("\t\t\treturn d")
	fa.store_line("\treturn null")
	fa.store_line("")
	fa.store_line("")

	# find
	fa.store_line(member_prefix + "func find(indicate: Callable) -> %s:" % data_class)
	fa.store_line("\tfor d: DataClass in _data.values():")
	fa.store_line("\t\tif indicate.call(d):")
	fa.store_line("\t\t\treturn d")
	fa.store_line("\treturn null")
	fa.store_line("")
	fa.store_line("")

	# filter
	fa.store_line(member_prefix + "func filter(indicate: Callable) -> Array[%s]:" % data_class)
	fa.store_line("\treturn Array(_data.values().filter(indicate), TYPE_OBJECT, (DataClass as Script).get_instance_base_type(), DataClass)")
	fa.store_line("")
	fa.store_line("")

	fa.store_line("# -----------------------------------------------------------------------")
	# 过滤meta字段
	var idx := 0
	while idx < fields.size():
		if is_meta_filed(fields[idx]):
			fields.remove_at(idx)
			types.remove_at(idx)
			continue
		idx += 1

	# _make_data
	instantiation = instantiation.strip_edges()
	var args := (
		(
			Array(instantiation.split("(", false, 1)[1].split(")", false, 1)[0].split(",")).map(func(a: String) -> String: return a.strip_edges().trim_prefix("{").trim_suffix("}"))
			as PackedStringArray
		)
		if not instantiation.ends_with("()")
		else PackedStringArray()
	)
	var fields_with_type := fields.duplicate()
	for i in range(fields_with_type.size()):
		fields_with_type[i] = "%s: %s" % [fields_with_type[i], type_string(types[i])]
	fa.store_line(member_prefix + "func _make_data(%s) -> %s:" % [", ".join(fields_with_type), data_class])
	fa.store_line("\tvar ret := %s.%s(%s)" % [data_class, instantiation.split("(")[0], ", ".join(args)])
	var valid_properties := property_list.map(func(d: Dictionary) -> String: return d["name"]) as PackedStringArray
	var hinted_fields: PackedStringArray = []
	for f: String in Array(fields).filter(func(f: String) -> bool: return not args.has(f)):
		if custom_setters.has(f):
			fa.store_line("\tret.%s(%s)" % [custom_setters[f], f])
		elif valid_properties.has(f):
			fa.store_line("\tret.%s = %s" % [f, f])
		elif not hinted_fields.has(f):
			# 只提示一次
			_Log.warning([_Localize.translate("无法被赋值的字段将被跳过: "), f])
			hinted_fields.push_back(f)
	fa.store_line("\treturn ret")
	fa.store_line("")
	fa.store_line("")

	# 数据行
	fa.store_line(member_prefix + "var _data:Dictionary = {}")
	fa.store_line("")
	fa.store_line("")

	fa.store_line(member_prefix + "func _init() -> void:")
	for row in data_rows:
		var args_text_list := PackedStringArray()
		for i in range(fields.size()):
			var f := fields[i]
			var t := types[i]
			args_text_list.push_back(_get_value_text(row, f, t, property_default_values))
		var priority_key_text := _get_value_text(row, priority_key, priority_key_type_id, property_default_values)
		fa.store_line("\t_data[%s] = _make_data(%s)" % [priority_key_text, ", ".join(args_text_list)])
	if data_rows.is_empty():
		fa.store_line("\tpass")
	fa.store_line("")
	fa.close()

	return OK


func _get_tooltip_text() -> String:
	return """字典形式的 GDScript 导入，适合表格条目较多的情况
必选参数:
	key=prop_name - 必选，指定用于查找的数据类属性,该属性的值在所有数据中不能重复,也不能留空
可选参数:
	generate_class_name - 如果 table_name 非空且是合法的标识符，将使用 table_name 生成全局类名
	pure_static=true/false - 是否以纯静态成员的形式进行生成, 默认为 true
"""
