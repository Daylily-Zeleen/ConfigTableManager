## 用于在导入流场中修改数据，内部状态不会被复用，每次修改修改流程都会实例化一个修改器
@tool

const _Localize = preload("../localization/localize.gd")


# 修改开始时调用, 典型应用是用于让继承者知道当前是为哪个数据类进行数据修改
func _begin_modify(table_name: String, data_class_name: String, data_class_script: String) -> void:
	pass


func _modify_table_name(table_name: String) -> String:
	return table_name


func _modify_custom_setters(custom_setters: Dictionary) -> Dictionary:
	return custom_setters


func _modify_data(data: Array[Dictionary]) -> Array[Dictionary]:
	return data


func _modify_metas(metas: PackedStringArray) -> PackedStringArray:
	return metas


func _modify_import_tool_options(options: PackedStringArray) -> PackedStringArray:
	return options


# ----------------------
func begin_modify(table_name: String, data_class_name: String, data_class_script: String) -> void:
	_begin_modify(table_name, data_class_name, data_class_script)


func modify_table_name(table_name: String) -> String:
	return _modify_table_name(table_name)


func modify_custom_setters(custom_setters: Dictionary) -> Dictionary:
	return _modify_custom_setters(custom_setters)


func modify_data(data: Array[Dictionary]) -> Array[Dictionary]:
	return _modify_data(data)


func modify_metas(metas: PackedStringArray) -> PackedStringArray:
	return _modify_metas(metas)


func modify_import_tool_options(options: PackedStringArray) -> PackedStringArray:
	return _modify_import_tool_options(options)
