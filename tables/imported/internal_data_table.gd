@static_unload
const TABLE_META_LIST: PackedStringArray = []

const DataClass = preload("res://data_classes/data.gd").InternalData

static func get_data() -> Dictionary:
	return _data


static func get_record(key: int) -> DataClass:
	return _data.get(key, null)


static func find_by_property(prop_name: StringName, target_value: Variant) -> DataClass:
	for d: DataClass in _data.values():
		if d.get(prop_name) == target_value:
			return d
	return null


static func find_by_getter(getter_name: StringName, target_value: Variant) -> DataClass:
	for d: DataClass in _data.values():
		if d.call(getter_name) == target_value:
			return d
	return null


static func find(indicate: Callable) -> DataClass:
	for d: DataClass in _data.values():
		if indicate.call(d):
			return d
	return null


static func filter(indicate: Callable) -> Array[DataClass]:
	return Array(_data.values().filter(indicate), TYPE_OBJECT, (DataClass as Script).get_instance_base_type(), DataClass)


# -----------------------------------------------------------------------
static func _make_data(id: int, name: String, str_arr: PackedStringArray, desc: String) -> DataClass:
	var ret := DataClass.create(id, name)
	ret.str_arr = str_arr
	ret.desc = desc
	return ret


static var _data: Dictionary = {}


static func _init() -> void:
	_data[0] = _make_data(0, "test", PackedStringArray(["asd", "qweqwe"]), "啊吧啊吧")
	_data.make_read_only()

