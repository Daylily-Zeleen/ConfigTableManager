const TABLE_META_LIST: PackedStringArray = []

const DataClass = preload("res://data_classes/data.gd").InternalData

func get_data() -> Dictionary:
	return _data


func get_record(key: int) -> DataClass:
	return _data.get(key, null)


func find_by_property(prop_name: StringName, target_value: Variant) -> DataClass:
	for d: DataClass in _data.values():
		if d.get(prop_name) == target_value:
			return d
	return null


func find_by_getter(getter_name: StringName, target_value: Variant) -> DataClass:
	for d: DataClass in _data.values():
		if d.call(getter_name) == target_value:
			return d
	return null


func find(indicate: Callable) -> DataClass:
	for d: DataClass in _data.values():
		if indicate.call(d):
			return d
	return null


func filter(indicate: Callable) -> Array[DataClass]:
	return Array(_data.values().filter(indicate), TYPE_OBJECT, (DataClass as Script).get_instance_base_type(), DataClass)


# -----------------------------------------------------------------------
func _make_data(id: int, name: String, str_arr: PackedStringArray, desc: String) -> DataClass:
	var ret := DataClass.create(id, name)
	ret.str_arr = str_arr
	ret.desc = desc
	return ret


var _data:Dictionary = {}


func _init() -> void:
	_data[0] = _make_data(0, "test", PackedStringArray(["asd", "qweqwe"]), "啊吧啊吧")

