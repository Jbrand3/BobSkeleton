extends CharacterBody2D

enum State { PATROL, CHASE, ATTACK, FRIGHTENED }

@export var patrol_speed: float = 80.0
@export var chase_speed: float = 140.0
@export var flee_speed: float = 200.0
@export var sight_range: float = 220.0
@export var give_up_range: float = 340.0
@export var attack_range: float = 120.0
@export var max_health: int = 19
@export var frightened_time: float = 3.0
@export var weapon_type: String = "hammer" # "dagger", "sword", or "hammer"

var current_health: int = 100
var state: State = State.PATROL
var patrol_points: Array[Vector2] = []
var patrol_index: int = 0
var frightened_left: float = 0.0
var default_hand_x: float = 0.0

var player: Node2D = null
var can_attack: bool = true
var is_attacking: bool = false
var attack_tween: Tween

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hand: Marker2D = $Hand
@onready var weapon_sprite: Sprite2D = $Hand/WeaponSprite

const WEAPONS: Dictionary = {
	"dagger": {
		"damage": 15,
		"swing_speed": 0.04,
		"cooldown": 0.40,
		"path": "res://assets/Golem_3/PNG/Vector Parts/Sword.png"
	},
	"sword": {
		"damage": 25,
		"swing_speed": 0.10,
		"cooldown": 0.70,
		"path": "res://assets/Golem_1/PNG/Vector Parts/Sword.png"
	},
	"hammer": {
		"damage": 40,
		"swing_speed": 0.28,
		"cooldown": 1.30,
		"path": "res://assets/Golem_2/PNG/Vector Parts/Sword.png"
	}
}

func _ready() -> void:
	add_to_group("Enemies")
	current_health = max_health

	if hand:
		default_hand_x = abs(hand.position.x)

	var origin := global_position
	patrol_points = [
		origin + Vector2(-90, -40),
		origin + Vector2(90, -40),
		origin + Vector2(90, 40),
		origin + Vector2(-90, 40)
	]

	equip_fixed_weapon()
	_change_state(State.PATROL)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("Player")
		if not player:
			move_and_slide()
			return

	var to_player := player.global_position - global_position
	var dist_to_player := to_player.length()

	match state:
		State.PATROL:
			var target := patrol_points[patrol_index]
			if global_position.distance_to(target) < 16.0:
				patrol_index = (patrol_index + 1) % patrol_points.size()
				target = patrol_points[patrol_index]

			var move_dir := (target - global_position).normalized()
			velocity = move_dir * patrol_speed
			update_facing(move_dir.x)

			if dist_to_player < sight_range:
				_change_state(State.CHASE)

		State.CHASE:
			var move_dir := to_player.normalized()
			velocity = move_dir * chase_speed
			update_facing(move_dir.x)

			if dist_to_player <= attack_range:
				_change_state(State.ATTACK)
			elif dist_to_player > give_up_range:
				_change_state(State.PATROL)

		State.ATTACK:
			update_facing(to_player.x)
			velocity = Vector2.ZERO

			if can_attack and not is_attacking:
				execute_swing()

			if dist_to_player > (attack_range + 35.0) and not is_attacking:
				_change_state(State.CHASE)

		State.FRIGHTENED:
			frightened_left -= delta
			var flee_dir := -to_player.normalized()
			velocity = flee_dir * flee_speed
			update_facing(flee_dir.x)

			if frightened_left <= 0.0:
				_change_state(State.PATROL)

	move_and_slide()

	# Active contact repulsion (smooth deflection when touching Bob)
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		if collider and collider.is_in_group("Player"):
			global_position += collision.get_normal() * 2.5

func _change_state(new_state: State) -> void:
	state = new_state
	match new_state:
		State.PATROL:
			modulate = Color.WHITE
			if animated_sprite and animated_sprite.sprite_frames.has_animation("Walk"):
				animated_sprite.play("Walk")
		State.CHASE:
			modulate = Color.WHITE
			if animated_sprite and animated_sprite.sprite_frames.has_animation("Walk"):
				animated_sprite.play("Walk")
		State.ATTACK:
			modulate = Color.WHITE
			if animated_sprite and animated_sprite.sprite_frames.has_animation("Idle"):
				animated_sprite.play("Idle")
		State.FRIGHTENED:
			modulate = Color("478cbf")

func execute_swing() -> void:
	var key := weapon_type.to_lower()
	var data: Dictionary = WEAPONS.get(key, WEAPONS["hammer"])
	is_attacking = true
	can_attack = false

	if attack_tween and attack_tween.is_valid():
		attack_tween.kill()

	attack_tween = create_tween()
	var spd: float = data["swing_speed"]

	# Windup, smash, reset
	attack_tween.tween_property(hand, "rotation_degrees", -45.0, spd * 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	attack_tween.tween_property(hand, "rotation_degrees", 85.0, spd * 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	# Damage strike on Bob
	attack_tween.tween_callback(func():
		if is_instance_valid(player):
			var dist = global_position.distance_to(player.global_position)
			if dist <= (attack_range + 25.0):
				if player.has_method("take_damage"):
					player.take_damage(data["damage"])
	)

	attack_tween.tween_property(hand, "rotation_degrees", 0.0, spd).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	attack_tween.finished.connect(func():
		if hand:
			hand.rotation_degrees = 0.0
		is_attacking = false
		start_attack_cooldown(data["cooldown"])
	)

func start_attack_cooldown(time: float) -> void:
	await get_tree().create_timer(time).timeout
	can_attack = true

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

func equip_fixed_weapon() -> void:
	var key := weapon_type.to_lower()
	if not WEAPONS.has(key):
		key = "hammer"

	if weapon_sprite:
		var path: String = WEAPONS[key]["path"]
		if ResourceLoader.exists(path):
			weapon_sprite.texture = load(path)
			weapon_sprite.scale = Vector2(1, 1)
			weapon_sprite.z_index = 2
			weapon_sprite.show()

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return

	current_health = max(0, current_health - amount)

	# Damage flash
	var flash_tween = create_tween()
	flash_tween.tween_property(self, "modulate", Color.RED, 0.08)
	flash_tween.tween_property(self, "modulate", Color.WHITE, 0.12)

	if current_health <= 0:
		die()

func die() -> void:
	set_physics_process(false)
	var death_tween = create_tween()
	death_tween.tween_property(self, "modulate:a", 0.0, 0.4)
	death_tween.finished.connect(queue_free)

func frighten() -> void:
	frightened_left = frightened_time
	_change_state(State.FRIGHTENED)

func calm() -> void:
	frightened_left = 0.0
	patrol_index = 0
	_change_state(State.PATROL)
