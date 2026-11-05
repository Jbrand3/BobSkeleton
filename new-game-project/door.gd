extends Area2D

var player_nearby: bool = false

func _ready() -> void:
	# This forces the connections directly through code so the editor can't break them!
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("Door system initialized and listening for Bob...")

func _on_body_entered(body: Node2D) -> void:
	print("PHYSICS TOUCH DETECTED! Object name: ", body.name)
	if body.name == "Bob" or body.is_in_group("player") or body.get_parent().is_in_group("player"):
		print("BOB IS AT THE DOOR!")
		player_nearby = true

func _on_body_exited(body: Node2D) -> void:
	if body.name == "Bob" or body.is_in_group("player") or body.get_parent().is_in_group("player"):
		print("Bob walked away.")
		player_nearby = false

func _process(_delta: float) -> void:
	# Temporary fallback: lets us check if Enter works ANYWHERE on screen
	if Input.is_action_just_pressed("interact"):
		print("Input Map works! Enter key detected. Am I near Bob? ", player_nearby)
		
		if player_nearby:
			print("Switching scenes now...")
			get_tree().change_scene_to_file("res://world_2.tscn")
