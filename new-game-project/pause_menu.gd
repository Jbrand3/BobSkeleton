extends Control

# This script safely references its own children directly
@onready var color_rect: ColorRect = $ColorRect
@onready var button_container: Control = $ButtonContainer

func _ready() -> void:
	# Ensure the individual pause window elements don't block mouse inputs
	mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE
	if color_rect:
		color_rect.mouse_filter = MouseFilter.MOUSE_FILTER_IGNORE
