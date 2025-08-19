"""csv 表格工具
可选参数：
 - arr_dict_with_brackets=true/false 生成表格时是否为所有的数组与字典类型将加上方/花括号, 默认为 false
"""
@tool
extends "table_tool.gd"

const CSV_DELIM = ","

var _last_parse_error: Error = ERR_PARSE_ERROR
var _header: _TableHeader
var _data: Array[Dictionary] = []

var arr_dict_with_brackets := false


func _get_support_types() -> PackedByteArray:
	return [
		TYPE_BOOL,
		TYPE_INT,
		TYPE_FLOAT,
		TYPE_STRING,
		TYPE_STRING_NAME,
		TYPE_NODE_PATH,
		TYPE_ARRAY,
		TYPE_DICTIONARY,
		TYPE_PACKED_BYTE_ARRAY,
		TYPE_PACKED_INT32_ARRAY,
		TYPE_PACKED_INT64_ARRAY,
		TYPE_PACKED_FLOAT32_ARRAY,
		TYPE_PACKED_FLOAT64_ARRAY,
		TYPE_PACKED_STRING_ARRAY,
	]


func _get_parse_error() -> Error:
	return _last_parse_error


func _parse_table_file(csv_file: String, options: PackedStringArray) -> Error:
	var option_pairs := parse_options(options)
	arr_dict_with_brackets = option_pairs.get("arr_dict_with_brackets", "false").to_lower() == "true"

	var fa := FileAccess.open(csv_file, FileAccess.READ)
	if not is_instance_valid(fa):
		_Log.error([_Localize.translate("无法读取csv文件: "), csv_file, " - ", error_string(FileAccess.get_open_error())])
		_last_parse_error = FileAccess.get_open_error()
		return _last_parse_error

	_header = _TableHeader.new()
	var meta_list := fa.get_csv_line(CSV_DELIM)
	var descs := fa.get_csv_line(CSV_DELIM)
	var fields := fa.get_csv_line(CSV_DELIM)
	var types := fa.get_csv_line(CSV_DELIM)

	# 移除尾随空项（由其他软件产生）
	for i in range(meta_list.size() - 1, -1, -1):
		if meta_list[i].is_empty():
			meta_list.remove_at(i)
		else:
			break

	for i in range(descs.size() - 1, -1, -1):
		if descs[i].is_empty():
			descs.remove_at(i)
		else:
			break

	if meta_list.size() == 1 and meta_list[0] in ["PlaceHolder Meta List", "PlaceHolder Metas"]: # 兼容旧格式
		meta_list.clear()
	if descs.size() == 1 and descs[0] == "PlaceHolder Descriptions":
		descs.clear()

	_header.meta_list = meta_list
	_header.descriptions = descs
	_header.fields = fields
	_header.types = types

	# 检查字段与类型是否匹配
	if fields.size() != types.size():
		_header = null
		_data.clear()
		_Log.error([_Localize.translate("解析csv文件失败: "), csv_file, " - ", _Localize.translate("请使用生成工具创建合法的表头。")])
		_last_parse_error = ERR_PARSE_ERROR
		return _last_parse_error

	# 检查字段名
	for f in fields:
		if not TextServerManager.get_primary_interface().is_valid_identifier(f) and not is_meta_filed(f):
			_header = null
			_data.clear()
			_Log.error([_Localize.translate("解析csv文件失败: "), csv_file, " - ", _Localize.translate("非法标识符: "), f])
			_last_parse_error = ERR_PARSE_ERROR
			return _last_parse_error
	# 检查类型
	for t in types:
		if get_type_id(t) <= 0:
			_header = null
			_data.clear()
			_Log.error([_Localize.translate("解析csv文件失败: "), csv_file, " - ", _Localize.translate("不支持的类型: "), t])
			_last_parse_error = ERR_PARSE_ERROR
			return _last_parse_error

	_data.clear()
	# 读取数据行
	while not fa.eof_reached():
		var row := fa.get_csv_line(CSV_DELIM)
		if _is_empty_csv_row(row, fields.size()):
			# 跳过空行
			continue
		var row_data := {}
		for i in range(min(types.size(), row.size())):
			var type := get_type_id(types[i].strip_edges())
			var field := fields[i].strip_edges()
			if type < 0:
				_header = null
				_data.clear()
				_Log.error([_Localize.translate("解析csv文件失败: "), csv_file])
				_last_parse_error = ERR_PARSE_ERROR
				return _last_parse_error

			if row[i].is_empty():
				# 跳过空数据，避免在此生成默认值
				continue

			var value: Variant = parse_value(row[i], type)

			if typeof(value) == TYPE_NIL:
				_header = null
				_data.clear()
				_Log.error([_Localize.translate("解析csv文件失败: "), csv_file])
				_last_parse_error = ERR_PARSE_ERROR
				return _last_parse_error

			row_data[field] = value

		_data.push_back(row_data)

	return OK


func _get_table_file_extension() -> String:
	return "csv"


func _generate_table_file(save_path: String, header: _TableHeader, data_rows: Array[PackedStringArray], options: PackedStringArray) -> Error:
	var option_pairs := parse_options(options)
	arr_dict_with_brackets = option_pairs.get("arr_dict_with_brackets", "false").to_lower() == "true"

	if not is_instance_valid(header):
		_Log.error([_Localize.translate("生成表格失败: "), error_string(ERR_INVALID_PARAMETER)])
		return ERR_INVALID_PARAMETER

	# 生成用于跳过导入的.import
	var f := FileAccess.open(save_path + ".import", FileAccess.WRITE)
	if not is_instance_valid(f):
		_Log.error([_Localize.translate("生成表格失败,无法生成:"), save_path + ".import", " - ", error_string(FileAccess.get_open_error())])
		return FAILED

	var engine_version := Engine.get_version_info()
	if engine_version.major >= 4 and engine_version.minor >= 3:
		# 4.3 之后使用skip
		f.store_string('[remap]\n\nimporter="skip"\n')
	else:
		# 4.3 之前使用keep
		f.store_string('[remap]\n\nimporter="keep"\n')

	f.close()

	var fa := FileAccess.open(save_path, FileAccess.WRITE)
	if not is_instance_valid(fa):
		_Log.error([_Localize.translate("生成表格失败: "), error_string(FileAccess.get_open_error())])
		return FileAccess.get_open_error()

	# 确保非空行
	var meta_list := header.meta_list.duplicate()
	var descs := header.descriptions.duplicate()
	if meta_list.size() == 0:
		meta_list.push_back("PlaceHolder Meta List")
	if descs.size() <= 0:
		descs.push_back("PlaceHolder Descriptions")
	fa.store_csv_line(meta_list, CSV_DELIM)
	fa.store_csv_line(descs, CSV_DELIM)
	fa.store_csv_line(header.fields, CSV_DELIM)
	fa.store_csv_line(header.types, CSV_DELIM)
	for row in data_rows:
		fa.store_csv_line(row, CSV_DELIM)
	fa.close()

	return OK


func _to_value_text(value: Variant) -> String:
	if not typeof(value) in get_support_types():
		_Log.error([_Localize.translate("转换为文本失败,不支持的类型: "), value, " - ", type_string(typeof(value))])
		return ""
	if typeof(value) in [TYPE_STRING, TYPE_NODE_PATH, TYPE_STRING_NAME]:
		return str(value)
	if typeof(value) > TYPE_ARRAY:
		# 转为数组给json
		value = type_convert(value, TYPE_ARRAY)
	# 不带两侧括号
	const fake_indent = "F`A@K*E&I#N|D-E+N/T"
	match typeof(value):
		TYPE_ARRAY:
			var text := JSON.stringify(value, fake_indent).replace("\n" + fake_indent, " ").trim_prefix("[ ").trim_suffix("\n]")
			if value.is_empty():
				text = ""
			if arr_dict_with_brackets:
				text = "[%s]" % text
			return text
		TYPE_DICTIONARY:
			var text := JSON.stringify(value, fake_indent).replace("\n" + fake_indent, " ").trim_prefix("{ ").trim_suffix("\n}")
			if value.is_empty():
				text = ""
			if arr_dict_with_brackets:
				text = "{%s}" % text
			return text
		_:
			return JSON.stringify(value)


func _parse_value(text: String, type_id: int) -> Variant:
	if not type_id in get_support_types():
		_Log.error([_Localize.translate("不支持的类型: "), type_string(type_id)])
		return null

	var default := text.is_empty()
	if default:
		_Log.error([_Localize.translate("Bug: 为空值生成默认值,请提交issue并提供复现流程或MRP。")])
		return null

	match type_id:
		TYPE_BOOL:
			return false if default else ("t" in text.to_lower())
		TYPE_INT:
			return 0 if default else text.to_int()
		TYPE_FLOAT:
			return 0.0 if default else text.to_float()
		TYPE_STRING:
			return "" if default else text
		TYPE_STRING_NAME:
			return &"" if default else StringName(text)
		TYPE_NODE_PATH:
			return ^"" if default else NodePath(text)
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY:
			if default:
				return convert([], type_id)
			var value_text := text
			if not text.begins_with("[") and not text.ends_with("]"):
				value_text = "[%s]" % text
			var arr: Variant = JSON.parse_string(value_text)
			if typeof(arr) != TYPE_ARRAY:
				_Log.error([_Localize.translate("非法值文本: "), text])
				return null
			return convert(arr, type_id)
		TYPE_DICTIONARY:
			if default:
				return {}
			var value_text := text
			if not text.begins_with("{") and not text.ends_with("}"):
				value_text = "{%s}" % text
			var dict: Variant = JSON.parse_string(value_text)
			if typeof(dict) != TYPE_DICTIONARY:
				_Log.error([_Localize.translate("非法值文本: "), text])
				return null
			return dict
	return null


func _get_header() -> _TableHeader:
	return _header


func _get_data() -> Array[Dictionary]:
	return _data


func _get_tooltip_text() -> String:
	return """csv 表格工具
可选参数：
 - arr_dict_with_brackets=true/false 生成表格时是否为所有的数组与字典类型将加上方/花括号, 默认为 false
"""


# --------------
func _is_empty_csv_row(row: PackedStringArray, fields_count: int) -> bool:
	for i in range(min(row.size(), fields_count)):
		if not row[i].strip_edges().is_empty():
			return false
	return true
