## Excel(xlsx) 表格工具
## Options:
## sheet=your_sheet_name 指定要解析的工作表,如果xlsx中存在多个工作表，则该参数必须指定。
## parse_sheet_must_exists 可选,如果加入该选项，指定工作表不存在时将发生解析错误。默认允许不存在。
## arr_dict_with_brackets 可选。如果使用，生成表格时所有的数组与字典类型将加上方/花括号。
## colorize_header=true 是否对生成的表头单元格被赋予颜色，默认true
@tool
extends "csv.gd"

const META_COLOR = Color.DARK_GRAY
const DESC_COLOR = Color.AQUA
const FIELD_COLOR = Color.DARK_SALMON
const TYPE_COLOR = Color.LAWN_GREEN
const META_FILED_COLOR = Color.ALICE_BLUE

const _PY_TOOL_RELATIVE_PATH = "py/xlsx_json.py"

var _py_tool_path: String = ProjectSettings.globalize_path((get_script().resource_path as String).get_base_dir().path_join(_PY_TOOL_RELATIVE_PATH))
var _tmp_json_path: String = ProjectSettings.globalize_path(EditorInterface.get_editor_paths().get_project_settings_dir().path_join("_xlsx_tmp_.json"))


func _parse_table_file(xlsx_file: String, options: PackedStringArray) -> Error:
	var sheet_name: String = ""
	var parse_sheet_must_exists := false
	for option in options:
		if option.begins_with("sheet="):
			sheet_name = option.trim_prefix("sheet=")
			sheet_name = sheet_name.strip_edges()
		if option == "parse_sheet_must_exists":
			parse_sheet_must_exists = true
		if option == "arr_dict_with_brackets":
			arr_dict_with_brackets = true

	if sheet_name.is_empty():
		_Log.error([_Localize.translate("解析xlsx文件: "), xlsx_file, " - ", _Localize.translate("必须使用 sheet=your_sheet_name 选项指定工作表。")])
		_last_parse_error = ERR_INVALID_PARAMETER
		return _last_parse_error

	if not FileAccess.file_exists(xlsx_file):
		_Log.error([_Localize.translate("无法读取xlsx文件: "), xlsx_file, " - ", error_string(ERR_FILE_NOT_FOUND)])
		_last_parse_error = ERR_FILE_NOT_FOUND
		return _last_parse_error

	var output := []
	var err := OS.execute("python", ['"%s"' % _py_tool_path, "--dump_json", '"%s"' % ProjectSettings.globalize_path(xlsx_file), '"%s"' % _tmp_json_path], output, true)
	if err != OK:
		_Log.error([_Localize.translate("无法解析xlsx文件: "), xlsx_file, " - ", "\n".join(output)])
		_last_parse_error = FAILED
		return _last_parse_error

	var json := FileAccess.get_file_as_string(_tmp_json_path)
	var sheets: Dictionary = JSON.parse_string(json) as Dictionary

	if not sheet_name in sheets:
		if parse_sheet_must_exists:
			_Log.error([_Localize.translate("解析xlsx文件: "), xlsx_file, " - ", _Localize.translate("不存在指定的工作表: "), sheet_name])
			_last_parse_error = ERR_PARSE_ERROR
			return _last_parse_error
		else:
			_last_parse_error = OK
			return _last_parse_error

	var sheet := Array(sheets[sheet_name]["data"], TYPE_ARRAY, &"", null) as Array[Array]
	if sheet.size() < 4:
		_Log.error([_Localize.translate("解析xlsx文件: "), xlsx_file, " - ", _Localize.translate("非法格式")])
		_last_parse_error = ERR_PARSE_ERROR
		return _last_parse_error

	_header = _TableHeader.new()
	var metas := _to_str_arr(sheet[0])
	var descs := _to_str_arr(sheet[1])
	var fields := _to_str_arr(sheet[2])
	var types := _to_str_arr(sheet[3])

	# 移除尾随空项（由其他软件产生）
	for i in range(metas.size() - 1, -1, -1):
		if metas[i].is_empty():
			metas.remove_at(i)
		else:
			break

	for i in range(descs.size() - 1, -1, -1):
		if descs[i].is_empty():
			descs.remove_at(i)
		else:
			break

	if metas.size() == 1 and metas[0] == "PlaceHolder Metas":
		metas.clear()
	if descs.size() == 1 and descs[0] == "PlaceHolder Descriptions":
		descs.clear()

	_header.metas = metas
	_header.descriptions = descs
	_header.fields = fields
	_header.types = types

	# 检查字段与类型是否匹配
	if fields.size() != types.size():
		_header = null
		_data.clear()
		_Log.error([_Localize.translate("解析xlsx文件失败: "), xlsx_file, " - ", _Localize.translate("请使用生成工具创建合法的表头。")])
		_last_parse_error = ERR_PARSE_ERROR
		return _last_parse_error

	# 检查字段名
	for f in fields:
		if not f.is_valid_identifier() and not is_meta_filed(f):
			_header = null
			_data.clear()
			_Log.error([_Localize.translate("解析xlsx文件失败: "), xlsx_file, " - ", _Localize.translate("非法标识符: "), f])
			_last_parse_error = ERR_PARSE_ERROR
			return _last_parse_error
	# 检查类型
	for t in types:
		if get_type_id(t) <= 0:
			_header = null
			_data.clear()
			_Log.error([_Localize.translate("解析xlsx文件失败: "), xlsx_file, " - ", _Localize.translate("不支持的类型: "), t])
			_last_parse_error = ERR_PARSE_ERROR
			return _last_parse_error

	_data.clear()
	# 读取数据行
	for row_idx in range(4, sheet.size()):
		var row := _to_str_arr(sheet[row_idx])
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
				_Log.error([_Localize.translate("解析xlsx文件失败: "), xlsx_file])
				_last_parse_error = ERR_PARSE_ERROR
				return _last_parse_error

			if row[i].is_empty():
				# 跳过空数据，避免在此生成默认值
				continue

			var value := parse_value(row[i], type)

			if typeof(value) == TYPE_NIL:
				_header = null
				_data.clear()
				_Log.error([_Localize.translate("解析xlsx文件失败: "), xlsx_file])
				_last_parse_error = ERR_PARSE_ERROR
				return _last_parse_error

			row_data[field] = value

		_data.push_back(row_data)

	return OK


func _get_table_file_extension() -> String:
	return "xlsx"


func _generate_table_file(save_path: String, header: _TableHeader, data_rows: Array[PackedStringArray], options: PackedStringArray) -> Error:
	save_path = ProjectSettings.globalize_path(save_path)
	var sheet_name: String = ""
	var colorize_header := true
	for option in options:
		if option.begins_with("sheet="):
			sheet_name = option.trim_prefix("sheet=")
			sheet_name = sheet_name.strip_edges()
		if option == "arr_dict_with_brackets":
			arr_dict_with_brackets = true
		if option.begins_with("colorize_header="):
			colorize_header = "t" in option.trim_prefix("colorize_header=").to_lower()

	if sheet_name.is_empty():
		_Log.error([_Localize.translate("解析xlsx文件: "), save_path, " - ", _Localize.translate("必须使用 sheet=your_sheet_name 选项指定工作表。")])
		_last_parse_error = ERR_INVALID_PARAMETER
		return _last_parse_error

	if not is_instance_valid(header):
		_Log.error([_Localize.translate("生成表格失败: "), error_string(ERR_INVALID_PARAMETER)])
		return ERR_INVALID_PARAMETER

	var json_data := {}
	var sheet_data := []
	json_data[sheet_name] = {"data": sheet_data}

	# 确保非空行
	var metas = header.metas.duplicate()
	var descs = header.descriptions.duplicate()
	if metas.size() == 0:
		metas.push_back("PlaceHolder Metas")
	if descs.size() <= 0:
		descs.push_back("PlaceHolder Descriptions")

	sheet_data.push_back(_to_row(metas))
	sheet_data.push_back(_to_row(descs))
	sheet_data.push_back(_to_row(header.fields))
	sheet_data.push_back(_to_row(header.types))

	if colorize_header:
		_colorize_header(sheet_data)

	for row in data_rows:
		var row_data := []
		row_data.resize(row.size())
		for i in range(row.size()):
			if row[i].is_empty():
				row_data[i] = ""
			else:
				var type_id := get_type_id(header.types[i])
				if type_id in [TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
					row_data[i] = parse_value(row[i], type_id)
				else:
					row_data[i] = row[i]
		sheet_data.push_back(_to_row(row_data))

	var fa := FileAccess.open(_tmp_json_path, FileAccess.WRITE)
	fa.store_string(JSON.stringify(json_data))
	fa.close()

	var output := []
	var err := OS.execute("python", ['"%s"' % _py_tool_path, "--override_xlsx", '"%s"' % _tmp_json_path, '"%s"' % ProjectSettings.globalize_path(save_path)], output, true)
	if err != OK:
		_Log.error([_Localize.translate("无法覆盖xlsx文件: "), save_path, " - ", "\n".join(output)])
		_last_parse_error = FAILED
		return _last_parse_error

	return OK


# -----------------
func _colorize_header(sheet_data: Array) -> void:
	assert(sheet_data.size() >= 4)
	# meta
	for cell in sheet_data[0]:
		cell["fill"] = _make_pattern_fill(META_COLOR)
		cell["border"] = _make_border()
	# desc
	for cell in sheet_data[1]:
		cell["fill"] = _make_pattern_fill(DESC_COLOR)
		cell["border"] = _make_border()
	# field & type
	for i in range(sheet_data[2].size()):
		if is_meta_filed(sheet_data[2][i]["value"]):
			sheet_data[2][i]["fill"] = _make_pattern_fill(META_FILED_COLOR)
			sheet_data[3][i]["fill"] = _make_pattern_fill(META_FILED_COLOR)
			if sheet_data[1].size() > i:
				sheet_data[1][i]["fill"] = _make_pattern_fill(META_FILED_COLOR)
		else:
			sheet_data[2][i]["fill"] = _make_pattern_fill(FIELD_COLOR)
			sheet_data[3][i]["fill"] = _make_pattern_fill(TYPE_COLOR)
		sheet_data[2][i]["border"] = _make_border()
		sheet_data[3][i]["border"] = _make_border()


func _make_pattern_fill(fgColor: Color, bgColor: Color = Color(0.0, 0.0, 0.0, 0.0)) -> Dictionary:
	return {
		patternType = "solid",
		fgColor = {rgb = fgColor.to_html(false)},
		bgColor = {rgb = bgColor.to_html(false)},
	}


func _make_border() -> Dictionary:
	return {
		left = {style = "thin", color = {rgb = Color.BLACK.to_html(false)}, outline = true},
		right = {style = "thin", color = {rgb = Color.BLACK.to_html(false)}, outline = true},
		top = {style = "thin", color = {rgb = Color.BLACK.to_html(false)}, outline = true},
		bottom = {style = "thin", color = {rgb = Color.BLACK.to_html(false), outline = true}},
	}


func _strip_right_null_cell(row: Array) -> Array[Dictionary]:
	# row:Array[Dictionary]
	var row_data = Array(row.duplicate(), TYPE_DICTIONARY, &"", null) as Array[Dictionary]
	for i in range(row_data.size() - 1, -1, -1):
		if row_data[i]["value"] == null:
			row_data.pop_back()
		else:
			break
	return row_data


func _to_str_arr(row: Array) -> PackedStringArray:
	# roe: Array[Dictionary]
	return _strip_right_null_cell(row).map(func(e: Dictionary): return "" if e["value"] == null else str(e["value"]))


func _to_row(str_arr: Array) -> Array[Dictionary]:
	return Array(str_arr.map(func(e): return {value = e}), TYPE_DICTIONARY, &"", null)
