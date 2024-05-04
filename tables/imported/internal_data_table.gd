const TABLE_META_LIST:PackedStringArray = []

const DataClass = preload("res://data_classes/data.gd").InternalData

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


func find(indicate:Callable) -> DataClass:
	for d in _data:
		if indicate.call(d):
			return d
	return null


func filter(indicate:Callable) -> Array[DataClass]:
	return _data.filter(indicate)


# -----------------------------------------------------------------------
func _make_data(id: int, name: String, str_arr: PackedStringArray, desc: String) -> DataClass:
	var ret = DataClass.create(id, name)
	ret.str_arr = str_arr
	ret.desc = desc
	return ret


var _data:Array[DataClass] = [
	_make_data(0, "test", PackedStringArray(["asd", "qweqwe"]), "啊吧啊吧"),
]

