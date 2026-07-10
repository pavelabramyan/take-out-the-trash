## Кусок мусора после разрыва. Подбирается на E.
extends RigidBody3D

var game: Node = null
var picked: bool = false

func _ready() -> void:
	add_to_group("trash_piece")

func setup_piece(g: Node) -> void:
	game = g
	if not is_in_group("trash_piece"):
		add_to_group("trash_piece")

func try_pick(player: Node3D) -> bool:
	if picked:
		return false
	if global_position.distance_to(player.global_position) > 2.2:
		return false
	picked = true
	Svc.audio().play_sfx("pickup", 1.1)
	queue_free()
	return true
