extends CharacterBody2D

signal health_changed(new_health: int, max_health: int)
signal stamina_changed(new_stamina: float, max_stamina: float)

@export var speed: float = 150.0
@export var dash_speed: float = 340.0
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 25.0
@export var dash_stamina_cost: float = 25.0
@export var dash_duration: float = 0.28

@export var max_health: int = 100
@export var health_regen_amount: int = 5
@export var health_regen_delay: float = 2 # Secs between ticks

var current_stamina: float = 100.0
var current_health: int = 100
var is_invulnerable: bool = false
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.DOWN
var health_regen_timer: float = 0.0

var can_attack: bool = true
var is_attacking: bool = false
var default_hand_x: float = 0.0

var current_weapon: String = "sword"
var current_damage: int = 30
var current_swing_speed: float = 0.10
var current_cooldown: float = 0.65
var current_stamina_cost: float = 22.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hand: Marker2D = $Hand
@onready var weapon_sprite: Sprite2D = $Hand/WeaponSprite

const WEAPONS: Dictionary = {
	"dagger": {
		"damage": 15,
		"swing_speed": 0.04,
		"cooldown": 0.35,
		"stamina_cost": 12.0,
		"path": "res://assets/Golem_3/PNG/Vector Parts/Sword.png"
	},
	"sword": {
		"damage": 30,
		"swing_speed": 0.10,
		"cooldown": 0.65,
		"stamina_cost": 22.0,
		"path": "res://assets/Golem_1/PNG/Vector Parts/Sword.png"
	},
	"hammer": {
		"damage": 60,
		"swing_speed": 0.28,
		"cooldown": 1.25,
		"stamina_cost": 40.0,
		"path": "res://assets/Golem_2/PNG/Vector Parts/Sword.png"
	}
}

func _ready() -> void:
	add_to_group("Player")
	current_health = max_health
	current_stamina = max_stamina
	if hand:
		default_hand_x = abs(hand.position.x)
	equip_weapon("sword")
	health_changed.emit(current_health, max_health)
	stamina_changed.emit(current_stamina, max_stamina)

func _physics_process(delta: float) -> void:
	# Stamina regeneration
	if not is_attacking and not is_dashing and current_stamina < max_stamina:
		current_stamina = min(max_stamina, current_stamina + stamina_regen_rate * delta)
		stamina_changed.emit(current_stamina, max_stamina)

	# Passive Health regeneration
	if current_health < max_health and current_health > 0:
		health_regen_timer += delta
		if health_regen_timer >= health_regen_delay:
			health_regen_timer = 0.0
			current_health = min(max_health, current_health + health_regen_amount)
			health_changed.emit(current_health, max_health)

	# If dashing, bypass regular inputs and propel forward
	if is_dashing:
		velocity = dash_direction * dash_speed
		move_and_slide()
		return

	# Standard movement
	var input_vector := Vector2.ZERO
	if InputMap.has_action("move_left"):
		input_vector.x = Input.get_axis("move_left", "move_right")
		input_vector.y = Input.get_axis("move_up", "move_down")
	else:
		input_vector.x = Input.get_axis("ui_left", "ui_right")
		input_vector.y = Input.get_axis("ui_up", "ui_down")

	if input_vector != Vector2.ZERO:
		input_vector = input_vector.normalized()
		dash_direction = input_vector
		velocity = input_vector * speed
		update_facing(input_vector.x)
		if animated_sprite and animated_sprite.sprite_frames.has_animation("Walk"):
			animated_sprite.play("Walk")
	else:
		velocity = Vector2.ZERO
		if animated_sprite and animated_sprite.sprite_frames.has_animation("Idle"):
			animated_sprite.play("Idle")

	move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
	# Slide Dash trigger (Shift key or "roll" action)
	var is_dash_input: bool = false
	if InputMap.has_action("roll") and event.is_action_pressed("roll"):
		is_dash_input = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SHIFT:
			is_dash_input = true

	if is_dash_input:
		if not is_dashing and not is_attacking and current_stamina >= dash_stamina_cost:
			start_dash()
			return

	# Weapon cycling
	if event.is_action_pressed("cycle_weapon"):
		if current_weapon == "hammer":
			equip_weapon("dagger")
		elif current_weapon == "dagger":
			equip_weapon("sword")
		elif current_weapon == "sword":
			equip_weapon("hammer")

	# Direct 1, 2, 3 hotkeys
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			equip_weapon("dagger")
		elif event.keycode == KEY_2:
			equip_weapon("sword")
		elif event.keycode == KEY_3:
			equip_weapon("hammer")

	# Melee Attack
	var is_attack_input: bool = false
	if InputMap.has_action("attack") and event.is_action_pressed("attack"):
		is_attack_input = true
	elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		is_attack_input = true
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		is_attack_input = true

	if is_attack_input:
		if can_attack and not is_attacking and not is_dashing and current_weapon != "none":
			if current_stamina >= current_stamina_cost:
				perform_attack()

func start_dash() -> void:
	is_dashing = true
	is_invulnerable = true
	current_stamina -= dash_stamina_cost
	stamina_changed.emit(current_stamina, max_stamina)

	# Hide weapon during slide so it doesn't float weirdly over the sprite
	if weapon_sprite:
		weapon_sprite.hide()

	# Play your slide animation (matches "Slide", "slide", or "Roll")
	if animated_sprite:
		if animated_sprite.sprite_frames.has_animation("Slide"):
			animated_sprite.play("Slide")
	
	# Slip past enemies during the dash
	set_collision_mask_value(2, false)

	await get_tree().create_timer(dash_duration).timeout

	set_collision_mask_value(2, true)
	is_dashing = false
	is_invulnerable = false

	# Restore weapon and return to standard movement animation
	if weapon_sprite and current_weapon != "none":
		weapon_sprite.show()
		
	if animated_sprite:
		if velocity != Vector2.ZERO and animated_sprite.sprite_frames.has_animation("Walk"):
			animated_sprite.play("Walk")
		elif animated_sprite.sprite_frames.has_animation("Idle"):
			animated_sprite.play("Idle")

func perform_attack() -> void:
	current_stamina -= current_stamina_cost
	stamina_changed.emit(current_stamina, max_stamina)
	is_attacking = true
	can_attack = false

	var tween = create_tween()
	var spd = current_swing_speed

	# Windup, slash, reset
	tween.tween_property(hand, "rotation_degrees", -40.0, spd * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(hand, "rotation_degrees", 80.0, spd * 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Strike check
	tween.tween_callback(func():
		var found_any_enemy: bool = false
		
		# Check all enemies in tree (both by group AND by class/name fallback)
		var targets = get_tree().get_nodes_in_group("Enemies")
		for node in get_parent().get_children():
			if node != self and node is CharacterBody2D and not targets.has(node):
				targets.append(node)

		for enemy in targets:
			if is_instance_valid(enemy) and enemy.has_method("take_damage"):
				var dist = global_position.distance_to(enemy.global_position)
				print("Bob swung! Distance to enemy: ", dist)
				# 160px reach guarantees hits land even with wide sprites
				if dist <= 160.0:
					found_any_enemy = true
					print("HIT LANDED! Dealing ", current_damage, " damage to Golem.")
					enemy.take_damage(current_damage)
		
		if not targets:
			print("ATTACK WARNING: Bob found 0 enemies in the scene!")
	)

	tween.tween_property(hand, "rotation_degrees", 0.0, spd).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	tween.finished.connect(func():
		if hand:
			hand.rotation_degrees = 0.0
		is_attacking = false
		await get_tree().create_timer(current_cooldown).timeout
		can_attack = true
	)
func equip_weapon(weapon_name: String) -> void:
	if not WEAPONS.has(weapon_name):
		return
	var data = WEAPONS[weapon_name]
	current_weapon = weapon_name
	current_damage = data["damage"]
	current_swing_speed = data["swing_speed"]
	current_cooldown = data["cooldown"]
	current_stamina_cost = data["stamina_cost"]

	if weapon_sprite and ResourceLoader.exists(data["path"]):
		weapon_sprite.texture = load(data["path"])
		weapon_sprite.scale = Vector2(2,2)
		weapon_sprite.z_index = 2
		weapon_sprite.show()

func update_facing(dir_x: float) -> void:
	if is_attacking or not hand:
		return
	if dir_x < 0:
		if animated_sprite:
			animated_sprite.flip_h = true
		hand.position.x = -default_hand_x
		hand.scale.x = -1
	elif dir_x > 0:
		if animated_sprite:
			animated_sprite.flip_h = false
		hand.position.x = default_hand_x
		hand.scale.x = 1

func take_damage(amount: int) -> void:
	if is_invulnerable or current_health <= 0:
		return

	health_regen_timer = 0.0
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)

	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color.RED, 0.08)
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.12)

	is_invulnerable = true
	get_tree().create_timer(0.4).timeout.connect(func(): 
		if not is_dashing:
			is_invulnerable = false
	)

	if current_health <= 0:
		die()

func die() -> void:
	set_physics_process(false)
	var death_tween = create_tween()
	death_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	death_tween.finished.connect(func():
		get_tree().reload_current_scene()
	)
