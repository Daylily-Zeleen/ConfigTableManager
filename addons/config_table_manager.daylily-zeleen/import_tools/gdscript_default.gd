## 默认的 GDScript 导入
## 可选 Options:
##	generate_class_name - 如果 table_name 非空且是合法的标识符，将使用 table_name 生成全局类名
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
	var fa = FileAccess.open(import_path, FileAccess.WRITE)
	if not is_instance_valid(fa):
		_Log.error([tr("导表失败: "), error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()

	if table_name.is_valid_identifier() and options.has("generate_class_name"):
		fa.store_line("class_name %s" % table_name)
		fa.store_line("")

	# TABLE_META_LIST
	var metas_text := ""
	for m in header.metas:
		if not metas_text.is_empty():
			metas_text += ", "
		metas_text += '"%s"' % m
	fa.store_line("const TABLE_META_LIST:PackedStringArray = [%s]" % metas_text)
	fa.store_line("")

	# DataClass
	var data_class := ""
	if not data_class_script.is_empty():
		var internal_class = "" if data_class_name.is_empty() else ".%s" % data_class_name
		fa.store_line('const DataClass = preload("%s")%s' % [data_class_script, internal_class])
		fa.store_line("")
		data_class = "DataClass"
	else:
		data_class = data_class_name

	# find_by_property
	fa.store_line("func get_data() -> Array[%s]:" % data_class)
	fa.store_line("\treturn _data")
	fa.store_line("")
	fa.store_line("")

	# find_by_property
	fa.store_line("func find_by_property(prop_name: StringName, target_value: Variant) -> %s:" % data_class)
	fa.store_line("\tfor d in _data:")
	fa.store_line("\t\tif d.get(prop_name) == target_value:")
	fa.store_line("\t\t\treturn d")
	fa.store_line("\treturn null")
	fa.store_line("")
	fa.store_line("")

	# find_by_getter
	fa.store_line("func find_by_getter(getter_name: StringName, target_value: Variant) -> %s:" % data_class)
	fa.store_line("\tfor d in _data:")
	fa.store_line("\t\tif d.call(getter_name) == target_value:")
	fa.store_line("\t\t\treturn d")
	fa.store_line("\treturn null")
	fa.store_line("")
	fa.store_line("")

	# find
	fa.store_line("func find(indicate:Callable) -> %s:" % data_class)
	fa.store_line("\tfor d in _data:")
	fa.store_line("\t\tif indicate.call(d):")
	fa.store_line("\t\t\treturn d")
	fa.store_line("\treturn null")
	fa.store_line("")
	fa.store_line("")

	# filter
	fa.store_line("func filter(indicate:Callable) -> Array[%s]:" % data_class)
	fa.store_line("\treturn _data.filter(indicate)")
	fa.store_line("")
	fa.store_line("")

	fa.store_line("# -----------------------------------------------------------------------")
	# 过滤meta字段
	var fields := header.fields.duplicate()
	var types := Array(header.types).map(to_type_id) as PackedByteArray
	var idx = 0
	while idx < fields.size():
		if is_meta_filed(fields[idx]):
			fields.remove_at(idx)
			types.remove_at(idx)
			continue
		idx += 1

	# _make_data
	instantiation = instantiation.strip_edges()
	var args := (
		Array(instantiation.split("(", false, 1)[1].split(")", false, 1)[0].split(",")).map(func(a: String): return a.strip_edges().trim_prefix("{").trim_suffix("}")) as PackedStringArray
	) if not instantiation.ends_with("()") else PackedStringArray()
	var fields_with_type = fields.duplicate()
	for i in range(fields_with_type.size()):
		fields_with_type[i] = "%s: %s" % [fields_with_type[i], type_string(types[i])]
	fa.store_line("func _make_data(%s) -> %s:" % [", ".join(fields_with_type), data_class])
	fa.store_line("\tvar ret = %s.%s(%s)" % [data_class, instantiation.split("(")[0], ", ".join(args)])
	for f in Array(fields).filter(func(f: String): return not args.has(f)):
		if custom_setters.has(f):
			fa.store_line("\tret.%s(%s)" % [custom_setters[f], f])
		else:
			fa.store_line("\tret.%s = %s" % [f, f])
	fa.store_line("\treturn ret")
	fa.store_line("")
	fa.store_line("")

	# 数据行
	fa.store_line("var _data:Array[%s] = [" % data_class)
	for row in data_rows:
		var args_text_list: PackedStringArray
		for i in range(fields.size()):
			var f = fields[i]
			var t = types[i]
			args_text_list.push_back(_get_value_text(row, f, t))
		fa.store_line("\t_make_data(%s)," % [", ".join(args_text_list)])
	fa.store_line("]")
	fa.store_line("")
	fa.close()

	return OK


func _get_import_file_extension() -> String:
	return "gd"


func _get_value_text(row: Dictionary, field: String, type_id: int) -> String:
	var value = row.get(field, null)

	var default := typeof(value) == TYPE_NIL
	var convertd_value = type_convert(value, type_id)
	return __get_value_text(convertd_value, default)


func __get_value_text(convertd_value, default := false) -> String:
	var type_id = typeof(convertd_value)
	var type := type_string(type_id)
	match type_id:
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return str(false) if default else str(convertd_value)
		TYPE_INT:
			return str(0) if default else str(convertd_value)
		TYPE_FLOAT:
			return str(0.0) if default else str(convertd_value)
		TYPE_STRING:
			return '""' if default else '"%s"' % convertd_value
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return (type + "()") if default else (type + "(%s, %s)" % [convertd_value.x, convertd_value.y])
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return (type + "()") if default else (type + "(%s, %s, %s)" % [convertd_value.x, convertd_value.y, convertd_value.z])
		TYPE_RECT2, TYPE_RECT2I:
			if default:
				return type + "()"
			else:
				return type + "(%s, %s, %s, %s)" % [convertd_value.position.x, convertd_value.position.y, convertd_value.size.x, convertd_value.size.y]
		TYPE_TRANSFORM2D:
			if default:
				return type + "()"
			else:
				var tran = convertd_value as Transform2D
				return type + "(Vector2(%s, %s), Vector2(%s, %s), Vector2(%s, %s))" % [tran.x.x, tran.x.y, tran.y.x, tran.y.y, tran.origin.x, tran.origin.y]
		TYPE_VECTOR4, TYPE_VECTOR4I:
			if default:
				return type + "()"
			else:
				return type + "(%s, %s, %s, %s)" % [convertd_value.x, convertd_value.y, convertd_value.z, convertd_value.w]
		TYPE_PLANE:
			if default:
				return type + "()"
			else:
				var plane = convertd_value as Plane
				return type + "(Vector3(%s, %s, %s), %s)" % [plane.normal.x, plane.normal.y, plane.normal.z, plane.d]
		TYPE_QUATERNION:
			if default:
				return type + "()"
			else:
				return type + "(%s, %s, %s, %s)" % [convertd_value.x, convertd_value.y, convertd_value.z, convertd_value.w]
		TYPE_AABB:
			if default:
				return type + "()"
			else:
				var aabb = convertd_value as AABB
				return type + "(Vector3(%s, %s, %s), Vector3(%s, %s, %s))" % [aabb.position.x, aabb.position.y, aabb.position.z, aabb.size.x, aabb.size.y, aabb.size.z]
		TYPE_BASIS:
			if default:
				return type + "()"
			else:
				var basis = convertd_value as Basis
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
				var trans = convertd_value as Transform3D
				var basis = trans.basis
				var origin = trans.origin
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
				var proj = convertd_value as Projection
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
				var color = convertd_value as Color
				return type + "(%s, %s, %s, %s)" % [color.r, color.g, color.b, color.a]
		TYPE_STRING_NAME:
			return '&""' if default else '&"%s"' % String(convertd_value)
		TYPE_NODE_PATH:
			return '^""' if default else '^"%s"' % String(convertd_value)
		TYPE_DICTIONARY:
			var elems: PackedStringArray = []
			for k in convertd_value:
				var v = convertd_value[k]
				elems.push_back("%s: %s" % [__get_value_text(k), __get_value_text(v)])
			return "{}" if default else "{%s}" % ", ".join(elems)
		_:
			if type_id >= TYPE_ARRAY and type_id < TYPE_MAX:
				var elems: PackedStringArray = []
				for e in convertd_value:
					elems.push_back(__get_value_text(e))
				return ("%s([])" % type) if default else ("%s([%s])" % [type, ", ".join(elems)])

	_Log.error([tr("转换失败，不支持的类型: "), type, " - ", convertd_value])
	return ""
