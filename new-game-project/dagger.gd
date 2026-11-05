extends Area2D

@export var weapon_name: String = "dagger" # Can be "dagger", "sword", or "hammer"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		if body.has_method("add_to_inventory"):
			body.add_to_inventory(weapon_name)
		queue_free() # Removes the item from the floor
