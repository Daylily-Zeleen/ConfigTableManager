## 表格工具基类，子类必须能够被无参构造
## 重写 _ 开头的方法已自定义您的解析表格与生成表格逻辑
@tool

const _Log = preload("../scripts/log.gd")
const _TableHeader = preload("../scripts/table_header.gd")


func _get_support_types() -> PackedByteArray:
	assert(false, "unimplemented")
	_Log.error(["Unimplemented: _get_support_types"])
	return []


func _get_parse_error() -> Error:
	assert(false, "unimplemented")
	_Log.error(["Unimplemented: _get_parse_error"])
	return ERR_PARSE_ERROR


func _parse_table_file(table_file: String, options: PackedStringArray) -> Error:
	assert(false, "unimplemented")
	_Log.error(["Unimplemented: _parse_table_file"])
	return ERR_PARSE_ERROR


func _get_table_file_extension() -> String:
	assert(false, "unimplemented")
	_Log.error(["Unimplemented: _get_table_file_extension"])
	return ""


func _generate_table_file(save_path: String, table_header: _TableHeader, data_rows: Array[PackedStringArray], options: PackedStringArray) -> Error:
	assert(false, "unimplemented")
	_Log.error(["Unimplemented: _generate_table_file"])
	return FAILED


func _to_value_text(value: Variant) -> String:
	assert(false, "unimplemented")
	_Log.error(["Unimplemented: _to_value_text"])
	return ""


func _parse_value(text: String, type_id: int) -> Variant:
	assert(false, "unimplemented")
	_Log.error(["Unimplemented: _parse_value"])
	return null


# 获取解析结果->表头
func _get_header() -> _TableHeader:
	assert(false, "unimplemented")
	_Log.error(["Unimplemented: _get_header"])
	return null


# 获取解析结果->数据
func _get_data() -> Array[Dictionary]:
	assert(false, "unimplemented")
	_Log.error(["Unimplemented: _get_data"])
	return []


# -----------
func is_meta_filed(field_name: String) -> bool:
	return field_name.begins_with("#")


func get_type_id(type_text: String) -> int:
	type_text = type_text.strip_edges()
	for t in _get_support_types():
		if type_string(t) == type_text:
			return t
	_Log.error([tr("不支持的类型: "), type_text])
	return -1


func to_data_rows(data: Array[Dictionary], fields: PackedStringArray, types: PackedByteArray) -> Array[PackedStringArray]:
	if fields.size() != types.size():
		_Log.error([tr("无法转换，类型与字段不符")])
		return []

	for t in types:
		if not t in _get_support_types():
			_Log.error([tr("无法转换，不支持的类型: "), type_string(t)])
			return []

	var ret: Array[PackedStringArray] = []
	for d in data:
		var r: PackedStringArray = []
		r.resize(types.size())
		for i in range(fields.size()):
			var f = fields[i].strip_edges()
			var t = types[i]
			if not f in d:
				continue

			r[i] = _to_value_text(type_convert(d[f], t))
		ret.push_back(r)

	return ret


func get_support_types() -> PackedByteArray:
	return _get_support_types()


func get_parse_error() -> Error:
	return _get_parse_error()


func parse_table_file(file: String, options: PackedStringArray) -> Error:
	return _parse_table_file(file, options)


func get_table_file_extension() -> String:
	return _get_table_file_extension()


func generate_table_file(save_path: String, table_header: _TableHeader, data_rows: Array[PackedStringArray], options: PackedStringArray) -> Error:
	return _generate_table_file(save_path, table_header, data_rows, options)


func to_value_text(value: Variant) -> String:
	return _to_value_text(value)


func parse_value(text: String, type_id: int) -> Variant:
	return _parse_value(text, type_id)


func get_header() -> _TableHeader:
	return _get_header()


func get_data() -> Array[Dictionary]:
	return _get_data()
