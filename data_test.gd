extends Node

func _ready() -> void:
	var data_table := DataTable.new()
	var internal_data_table := preload("res://tables/imported/internal_data_table.gd").new() as RefCounted

	print("== DataTable 所有数据:")
	print(data_table.get_data())
	print("")

	print("== DataTable 查找 name 为 “test1” 的数据（find_by_property）:")
	print(data_table.find_by_property(&"name", "test1"))
	print("")

	print("== DataTable 查找 id 为 1 的数据（find_by_getter）:")
	print(data_table.find_by_getter(&"get_id", 1))
	print("")

	print("== InternalDataTable 查找 id 为 0 的数据（find）:")
	print(internal_data_table.find(func(d: DataTable.DataClass.InternalData) -> bool: return d.id == 0))
	print("")
