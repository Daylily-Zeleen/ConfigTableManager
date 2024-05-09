## 在生成表格流程中修改数据，内部状态不会被复用，每次修改都会实例化一个修改器，
@tool


# 修改开始时调用, 典型应用是用于让继承者知道当前是为哪个数据类进行数据修改
func _begin_modify(table_name: String, data_class_name: String, data_class_script: String) -> void:
	pass


## 修改后的字段与类型数量必须匹配，且类型必须时表格工具支持的类型
func _modify_fileds_definitions(inout_fields: PackedStringArray, inout_types: PackedByteArray) -> void:
	pass


func _modify_data(data: Array[Dictionary]) -> Array[Dictionary]:
	return data


## descriptions： Key 为字段名（String）, Value 为描述（String）
func _modify_descriptions(descriptions: Dictionary) -> Dictionary:
	return descriptions


func _modify_metas(metas: PackedStringArray) -> PackedStringArray:
	return metas


func _modify_table_tool_options(options: PackedStringArray) -> PackedStringArray:
	return options


# --------------------------
func begin_modify(table_name: String, data_class_name: String, data_class_script: String) -> void:
	_begin_modify(table_name, data_class_name, data_class_script)


func modify_fileds_definitions(inout_fields: PackedStringArray, inout_types: PackedByteArray) -> bool:
	_modify_fileds_definitions(inout_fields, inout_types)
	if inout_fields.size() != inout_types.size():
		preload("log.gd").error([tr("修改后的字段数量与类型属性不对应。")])
		return false
	return true


func modify_data(data: Array[Dictionary]) -> Array[Dictionary]:
	return _modify_data(data)


## descriptions： Key 为字段名（String）, Value 为描述（String）
func modify_descriptions(descriptions: Dictionary) -> Dictionary:
	return _modify_descriptions(descriptions)


func modify_metas(metas: PackedStringArray) -> PackedStringArray:
	return _modify_metas(metas)


func modify_table_tool_options(options: PackedStringArray) -> PackedStringArray:
	return _modify_table_tool_options(options)
