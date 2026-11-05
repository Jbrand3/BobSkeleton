extends Control

@onready var pause_menu: Control = $CanvasLayer/PauseMenu

# Uses unique names or falls back safely
@onready var health_node = get_node_or_null("%HealthLabel")
@onready var stamina_node = get_node_or_null("%StaminaLabel")

var player: CharacterBody2D = null

func _ready() -> void:
	if pause_menu:
		pause_menu.hide()
	get_tree().paused = false
	
	# Locate Bob and connect signals directly
	player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_health_changed)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(_on_stamina_changed)
		_on_health_changed(player.current_health, player.max_health)
		_on_stamina_changed(player.current_stamina, player.max_stamina)

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player") as CharacterBody2D
		if player:
			_ready()

func _on_health_changed(current: int, _max_val: int) -> void:
	if not health_node:
		# Fallback search if unique name wasn't set
		health_node = find_child("HealthLabel", true, false)
	if health_node:
		if health_node is Label:
			health_node.text = "Health: " + str(current)
		elif "value" in health_node:
			health_node.value = current

func _on_stamina_changed(current: float, _max_val: float) -> void:
	if not stamina_node:
		stamina_node = find_child("StaminaLabel", true, false)
	if stamina_node:
		if stamina_node is Label:
			stamina_node.text = "Stamina: " + str(int(current))
		elif "value" in stamina_node:
			stamina_node.value = current

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			close_pause_menu()
		else:
			open_pause_menu()

func open_pause_menu() -> void:
	get_tree().paused = true
	if pause_menu:
		pause_menu.show()

func close_pause_menu() -> void:
	if pause_menu:
		pause_menu.hide()
	get_tree().paused = false

func _on_resume_pressed() -> void:
	close_pause_menu()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit()
