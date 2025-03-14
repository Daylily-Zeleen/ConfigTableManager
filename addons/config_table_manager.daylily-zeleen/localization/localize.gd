@tool

static var _translations: Array[Translation] = []


static func add_translation(translation: Translation) -> void:
	if translation in _translations:
		return
	_translations.push_front(translation)


static func remote_translation(translation: Translation) -> void:
	_translations.erase(translation)


static func clean_translations() -> void:
	_translations.clear()


static func translate(msg: String) -> String:
	var local := TranslationServer.get_tool_locale()
	for translation: Translation in _translations.filter(func(t: Translation) -> bool: return t.locale == local):
		translation = translation as Translation
		var translated := translation.get_message(msg)
		if not translated.is_empty() and translated != msg:
			return translated
	return msg


static func localize_node(node: Control) -> void:
	for n in node.get_children():
		if n is Control:
			localize_node(n)
	for p in node.get_property_list():
		if not p.type in [TYPE_STRING, TYPE_STRING_NAME]:
			continue
		var name := p.name as String

		var val := node.get(name) as StringName
		if val.is_empty():
			continue

		var translated := translate(val)
		if not translated.is_empty() and translated != val:
			node.set(name, translated)
