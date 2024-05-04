@tool


static func error(texts: PackedStringArray) -> void:
	printerr("[TableManager]", "".join(texts))


static func warning(texts: PackedStringArray) -> void:
	print_rich("[color=yellow][TableManager]%s[/color]" % "".join(texts))


static func info(texts: PackedStringArray) -> void:
	print("[TableManager]", "".join(texts))
