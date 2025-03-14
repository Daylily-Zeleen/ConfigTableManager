## 在生成表格流程中修改数据，内部状态不会被复用，每次修改都会实例化一个修改器，
@tool

const _Localize = preload("../localization/localize.gd")


# 修改开始时调用, 典型应用是用于让继承者知道当前是为哪个数据类进行数据修改
func _begin_modify(_table_name: String, _data_class_name: String, _data_class_script: String) -> void:
	pass


## 修改后的字段与类型数量必须匹配，且类型必须时表格工具支持的类型
func _modify_fields_definitions(_in_out_fields: PackedStringArray, _in_out_types: PackedByteArray) -> void:
	pass


func _modify_data(data: Array[Dictionary]) -> Array[Dictionary]:
	return data


## descriptions： Key 为字段名（String）, Value 为描述（String）
func _modify_descriptions(descriptions: Dictionary) -> Dictionary:
	return descriptions


func _modify_meta_list(meta_list: PackedStringArray) -> PackedStringArray:
	return meta_list


func _modify_table_tool_options(options: PackedStringArray) -> PackedStringArray:
	return options


# --------------------------
func begin_modify(table_name: String, data_class_name: String, data_class_script: String) -> void:
	_begin_modify(table_name, data_class_name, data_class_script)


func modify_fields_definitions(in_out_fields: PackedStringArray, in_out_types: PackedByteArray) -> bool:
	if self.has_method("_modify_fileds_definitions"):
		push_warning("'_modify_fileds_definitions()' is deprecated, override '_modify_fields_definitions()' instead.")
		self.call("_modify_fileds_definitions", in_out_fields, in_out_types)
	else:
		_modify_fields_definitions(in_out_fields, in_out_types)
	if in_out_fields.size() != in_out_types.size():
		preload("log.gd").error([_Localize.translate(&"修改后的字段数量与类型属性不对应。")])
		return false
	return true


func modify_data(data: Array[Dictionary]) -> Array[Dictionary]:
	return _modify_data(data)


## descriptions： Key 为字段名（String）, Value 为描述（String）
func modify_descriptions(descriptions: Dictionary) -> Dictionary:
	return _modify_descriptions(descriptions)


func modify_meta_list(meta_list: PackedStringArray) -> PackedStringArray:
	if self.has_method("_modify_metas"):
		push_warning("'_modify_metas()' is deprecated, override '_modify_meta_list()' instead.")
		return self.call("_modify_metas", meta_list)
	else:
		return _modify_meta_list(meta_list)


func modify_table_tool_options(options: PackedStringArray) -> PackedStringArray:
	return _modify_table_tool_options(options)
