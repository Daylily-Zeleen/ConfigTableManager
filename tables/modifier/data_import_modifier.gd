# 仅用于演示对 "res://data_classes/data.gd" 对应的表格插入数据
@tool
extends "res://addons/config_table_manager.daylily-zeleen/scripts/import_modifier.gd"

var _is_required_data: bool


# 修改开始时调用, 典型应用是用于让继承者知道当前是为哪个数据类进行数据修改
func _begin_modify(_table_name: String, _data_class_name: String, data_class_script: String) -> void:
	var require := ResourceLoader.load("res://data_classes/data.gd", "", ResourceLoader.CACHE_MODE_IGNORE)
	var input := ResourceLoader.load(data_class_script, "", ResourceLoader.CACHE_MODE_IGNORE)
	_is_required_data = is_instance_valid(input) and require.resource_path == input.resource_path


func _modify_data(data: Array[Dictionary]) -> Array[Dictionary]:
	const generated_name = "import_data"
	# 检查是否有该行
	for d in data:
		if d.has("name") and d["name"] == generated_name:
			return data

	# 添加生成数据
	data.push_back({id = data.size(), name = generated_name, description = "该行由导入修改器生成。"})
	return data
