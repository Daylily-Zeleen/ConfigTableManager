class_name DataTable

const TABLE_META_LIST: PackedStringArray = ["测试元数据"]

const DataClass = preload("res://data_classes/data.gd")

func get_data() -> Array[DataClass]:
	return _data


func find_by_property(prop_name: StringName, target_value: Variant) -> DataClass:
	for d in _data:
		if d.get(prop_name) == target_value:
			return d
	return null


func find_by_getter(getter_name: StringName, target_value: Variant) -> DataClass:
	for d in _data:
		if d.call(getter_name) == target_value:
			return d
	return null


func find(indicate: Callable) -> DataClass:
	for d in _data:
		if indicate.call(d):
			return d
	return null


func filter(indicate: Callable) -> Array[DataClass]:
	return _data.filter(indicate)


# -----------------------------------------------------------------------
func _make_data(id: int, name: String, dict: Dictionary, description: String, arr: Array) -> DataClass:
	var ret := DataClass.new(id)
	ret.name = name
	ret.dict = dict
	ret.description = description
	ret.set_arr(arr)
	return ret


var _data:Array[DataClass] = [
	_make_data(0, "test1", {"a": 1, "b": "str1"}, "歪比八卜", Array([1, 1.2, "string"])),
	_make_data(1, "test2", {"c": "str2"}, "玛卡巴卡", Array([])),
	_make_data(2, "import_data", {}, "该行由导入修改器生成。", Array([])),
]

