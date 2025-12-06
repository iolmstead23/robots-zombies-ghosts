class_name LoadingModal
extends CanvasLayer

## Loading Modal - Displays initialization progress during session startup
## Shows current stage name and progress bar

signal modal_closed()

@onready var title_label: Label = $Control/Panel/VBoxContainer/TitleLabel
@onready var progress_bar: ProgressBar = $Control/Panel/VBoxContainer/ProgressBar
@onready var stage_label: Label = $Control/Panel/VBoxContainer/StageLabel

var total_stages: int = 5
var current_stage: int = 0


func _ready() -> void:
	layer = 100  # Ensure modal renders on top
	visible = false


func show_modal() -> void:
	"""Show the loading modal and reset progress"""
	current_stage = 0
	_update_progress()
	visible = true


func hide_modal() -> void:
	"""Hide the loading modal"""
	visible = false
	modal_closed.emit()


func set_stage(stage_text: String, stage_number: int) -> void:
	"""Update the current stage display"""
	if stage_label:
		stage_label.text = stage_text

	if stage_number >= 0:
		current_stage = stage_number
		_update_progress()


func _update_progress() -> void:
	"""Update the progress bar based on current stage"""
	if progress_bar and total_stages > 0:
		progress_bar.value = (float(current_stage) / float(total_stages)) * 100.0
