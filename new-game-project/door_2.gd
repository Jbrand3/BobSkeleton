extends Area2D

@export_file("*.tscn") var target_scene: String = "res://world.tscn"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("Bob entered Door 2! Returning to: ", target_scene)
		if ResourceLoader.exists(target_scene):
			get_tree().change_scene_to_file(target_scene)
		else:
			push_error("Target scene path not found: " + target_scene)
