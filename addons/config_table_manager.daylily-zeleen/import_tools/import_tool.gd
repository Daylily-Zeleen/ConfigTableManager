## 表格导入工具基类，子类必须能够被无参构造
## 重写 _ 开头的方法已自定义您的导入逻辑
@tool

const _TableHeader = preload("../scripts/table_header.gd")
const _Log = preload("../scripts/log.gd")
const _Localize = preload("../localization/localize.gd")

func _import(
	_import_path: String,
	_table_name: String,
	_header: _TableHeader,
	_data_class_name: String,
	_data_class_script: String,
	_instantiation: String,
	_custom_setters: Dictionary,
	_data_rows: Array[Dictionary],
	_options:PackedStringArray
) -> Error:
	assert(false, "Unimplemented")
	_Log.error(["Unimplemented: _import"])
	return FAILED


func _get_import_file_extension() -> String:
	assert(false, "Unimplemented")
	_Log.error(["Unimplemented: _get_import_file_extension"])
	return ""


#-----------------------
func is_meta_filed(field_name: String) -> bool:
	return field_name.begins_with("#")


func to_type_id(type_text: String) -> int:
	type_text = type_text.strip_edges()
	for i in range(TYPE_MAX):
		if type_text == type_string(i):
			return i
	return -1


func import(
	import_path: String,
	table_name: String,
	header: _TableHeader,
	data_class_name: String,
	data_class_script: String,
	instantiation: String,
	custom_setters: Dictionary,
	data_rows: Array[Dictionary],
	options:PackedStringArray
) -> Error:
	return _import(import_path, table_name, header, data_class_name, data_class_script, instantiation, custom_setters, data_rows, options)


func get_import_file_extension() -> String:
	return _get_import_file_extension()
