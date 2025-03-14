## 默认的 GDScript 导入 (TypedArray) 适合表格条目较少的情况。
## 可选配置参数:
##	generate_class_name - 如果 table_name 非空且是合法的标识符，将使用 table_name 生成全局类名
##	pure_static=true/false - 是否以纯静态成员的形式进行生成, 默认为 true
@tool
extends "import_tool.gd"


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
	var fa := FileAccess.open(import_path, FileAccess.WRITE)
	if not is_instance_valid(fa):
		_Log.error([_Localize.translate("导表失败: "), error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()

	var option_pairs := parse_options(options)

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
	var property_default_values: Dictionary = {}
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

	# get_data
	fa.store_line(member_prefix + "func get_data() -> Array[%s]:" % data_class)
	fa.store_line("\treturn _data")
	fa.store_line("")
	fa.store_line("")

	# find_by_property
	fa.store_line(member_prefix + "func find_by_property(prop_name: StringName, target_value: Variant) -> %s:" % data_class)
	fa.store_line("\tfor d in _data:")
	fa.store_line("\t\tif d.get(prop_name) == target_value:")
	fa.store_line("\t\t\treturn d")
	fa.store_line("\treturn null")
	fa.store_line("")
	fa.store_line("")

	# find_by_getter
	fa.store_line(member_prefix + "func find_by_getter(getter_name: StringName, target_value: Variant) -> %s:" % data_class)
	fa.store_line("\tfor d in _data:")
	fa.store_line("\t\tif d.call(getter_name) == target_value:")
	fa.store_line("\t\t\treturn d")
	fa.store_line("\treturn null")
	fa.store_line("")
	fa.store_line("")

	# find
	fa.store_line(member_prefix + "func find(indicate: Callable) -> %s:" % data_class)
	fa.store_line("\tfor d in _data:")
	fa.store_line("\t\tif indicate.call(d):")
	fa.store_line("\t\t\treturn d")
	fa.store_line("\treturn null")
	fa.store_line("")
	fa.store_line("")

	# filter
	fa.store_line(member_prefix + "func filter(indicate: Callable) -> Array[%s]:" % data_class)
	fa.store_line("\treturn _data.filter(indicate)")
	fa.store_line("")
	fa.store_line("")

	fa.store_line("# -----------------------------------------------------------------------")
	# 过滤meta字段
	var fields := header.fields.duplicate()
	var types := Array(header.types).map(to_type_id) as PackedByteArray
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
	fa.store_line(member_prefix + "var _data:Array[%s] = [" % data_class)
	for row in data_rows:
		var args_text_list := PackedStringArray()
		for i in range(fields.size()):
			var f := fields[i]
			var t := types[i]
			args_text_list.push_back(_get_value_text(row, f, t, property_default_values))
		fa.store_line("\t_make_data(%s)," % [", ".join(args_text_list)])
	fa.store_line("]")
	fa.store_line("")
	fa.store_line("")

	# 构造，使数据只读
	fa.store_line(member_prefix + "func _init() -> void:")
	fa.store_line("\t_data.make_read_only()")
	fa.store_line("")
	fa.close()

	return OK


func _get_import_file_extension() -> String:
	return "gd"


func _get_value_text(row: Dictionary, field: String, type_id: int, default_values: Dictionary) -> String:
	var value: Variant = row.get(field, default_values.get(field, null))

	var default := typeof(value) == TYPE_NIL
	var converted_value: Variant = type_convert(value, type_id)
	return __get_value_text(converted_value, default)


func __get_value_text(converted_value: Variant, default := false) -> String:
	var type_id: Variant = typeof(converted_value)
	var type := type_string(type_id)
	match type_id:
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return str(false) if default else str(converted_value)
		TYPE_INT:
			return str(0) if default else str(converted_value)
		TYPE_FLOAT:
			return str(0.0) if default else str(converted_value)
		TYPE_STRING:
			return '""' if default else '"%s"' % converted_value
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return (type + "()") if default else (type + "(%s, %s)" % [converted_value.x, converted_value.y])
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return (type + "()") if default else (type + "(%s, %s, %s)" % [converted_value.x, converted_value.y, converted_value.z])
		TYPE_RECT2, TYPE_RECT2I:
			if default:
				return type + "()"
			else:
				return type + "(%s, %s, %s, %s)" % [converted_value.position.x, converted_value.position.y, converted_value.size.x, converted_value.size.y]
		TYPE_TRANSFORM2D:
			if default:
				return type + "()"
			else:
				var tran := converted_value as Transform2D
				return type + "(Vector2(%s, %s), Vector2(%s, %s), Vector2(%s, %s))" % [tran.x.x, tran.x.y, tran.y.x, tran.y.y, tran.origin.x, tran.origin.y]
		TYPE_VECTOR4, TYPE_VECTOR4I:
			if default:
				return type + "()"
			else:
				return type + "(%s, %s, %s, %s)" % [converted_value.x, converted_value.y, converted_value.z, converted_value.w]
		TYPE_PLANE:
			if default:
				return type + "()"
			else:
				var plane := converted_value as Plane
				return type + "(Vector3(%s, %s, %s), %s)" % [plane.normal.x, plane.normal.y, plane.normal.z, plane.d]
		TYPE_QUATERNION:
			if default:
				return type + "()"
			else:
				return type + "(%s, %s, %s, %s)" % [converted_value.x, converted_value.y, converted_value.z, converted_value.w]
		TYPE_AABB:
			if default:
				return type + "()"
			else:
				var aabb := converted_value as AABB
				return type + "(Vector3(%s, %s, %s), Vector3(%s, %s, %s))" % [aabb.position.x, aabb.position.y, aabb.position.z, aabb.size.x, aabb.size.y, aabb.size.z]
		TYPE_BASIS:
			if default:
				return type + "()"
			else:
				var basis := converted_value as Basis
				return (
					type
					+ (
						"(Vector3(%s, %s, %s), Vector3(%s, %s, %s), Vector3(%s, %s, %s))"
						% [basis.x.x, basis.x.y, basis.x.z, basis.y.x, basis.y.y, basis.y.z, basis.z.x, basis.z.y, basis.z.z]
					)
				)
		TYPE_TRANSFORM3D:
			if default:
				return type + "()"
			else:
				var trans := converted_value as Transform3D
				var basis := trans.basis
				var origin := trans.origin
				return (
					type
					+ (
						"(Vector3(%s, %s, %s), Vector3(%s, %s, %s), Vector3(%s, %s, %s), Vector3(%s, %s, %s))"
						% [basis.x.x, basis.x.y, basis.x.z, basis.y.x, basis.y.y, basis.y.z, basis.z.x, basis.z.y, basis.z.z, origin.x, origin.y, origin.z]
					)
				)
		TYPE_PROJECTION:
			if default:
				return type + "()"
			else:
				var proj := converted_value as Projection
				return (
					type
					+ (
						"(Vector4(%s, %s, %s, %s), Vector4(%s, %s, %s, %s), Vector4(%s, %s, %s, %s), Vector4(%s, %s, %s, %s))"
						% [
							proj.x.x,
							proj.x.y,
							proj.x.z,
							proj.x.w,
							proj.y.x,
							proj.y.y,
							proj.y.z,
							proj.y.w,
							proj.z.x,
							proj.z.y,
							proj.z.z,
							proj.z.w,
							proj.w.x,
							proj.w.y,
							proj.w.z,
							proj.w.w,
						]
					)
				)
		TYPE_COLOR:
			if default:
				return type + "()"
			else:
				var color := converted_value as Color
				return type + "(%s, %s, %s, %s)" % [color.r, color.g, color.b, color.a]
		TYPE_STRING_NAME:
			return '&""' if default else '&"%s"' % String(converted_value)
		TYPE_NODE_PATH:
			return '^""' if default else '^"%s"' % String(converted_value)
		TYPE_DICTIONARY:
			var elements: PackedStringArray = []
			for k: Variant in converted_value:
				var v: Variant = converted_value[k]
				elements.push_back("%s: %s" % [__get_value_text(k), __get_value_text(v)])
			return "{}" if default else "{%s}" % ", ".join(elements)
		_:
			if type_id >= TYPE_ARRAY and type_id < TYPE_MAX:
				var elements: PackedStringArray = []
				for e: Variant in converted_value:
					elements.push_back(__get_value_text(e))
				return ("%s([])" % type) if default else ("%s([%s])" % [type, ", ".join(elements)])

	_Log.error([_Localize.translate("转换失败，不支持的类型: "), type, " - ", converted_value])
	return ""


func _get_tooltip_text() -> String:
	return """默认的 GDScript 导入 (TypedArray) 适合表格条目较少的情况。
可选配置参数:
    generate_class_name - 如果 table_name 非空且是合法的标识符，将使用 table_name 生成全局类名
    pure_static=true/false - 是否以纯静态成员的形式进行生成, 默认为 true
"""
