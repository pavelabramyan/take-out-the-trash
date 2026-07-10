class_name Svc
extends Object
## Доступ к автолоадам без compile-time имён (нужно для --script тестов).

static func meta() -> Node:
	return Engine.get_main_loop().root.get_node("Meta")

static func loc() -> Node:
	return Engine.get_main_loop().root.get_node("Loc")

static func audio() -> Node:
	return Engine.get_main_loop().root.get_node("GameAudio")

static func steam() -> Node:
	return Engine.get_main_loop().root.get_node("SteamAch")
