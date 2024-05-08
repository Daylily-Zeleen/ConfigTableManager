@tool
@export var _id:int
@export var name:String
@export var description:String
@export var arr: Array
@export var dict: Dictionary
@export var need_ignore: int

func _init(id: int) -> void:
	_id = id


func set_arr(p_arr:Array) -> void:
	arr = p_arr


func get_id() -> int:
	return _id


func _to_string() -> String:
	return "\n%d - %s: %s\n\t%s\n\t%s" % [_id, name, description, arr, dict]


#------------------------------------
class InternalData:
	@export var id: int
	@export var name: String
	@export var desc :String
	@export var str_arr: PackedStringArray
	
	static func create(p_id: int, p_name: String) -> InternalData:
		var ret := InternalData.new()
		ret.id = p_id
		ret.name = p_name
		return ret
	
	func _to_string() -> String:
		return "\n%d - %s: %s\n\t%s" % [id, name, desc, str_arr]
