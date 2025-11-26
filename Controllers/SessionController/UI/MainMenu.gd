extends Control

func _on_new_session_pressed():
	get_tree().change_scene_to_file("res://Controllers/SessionController/UI/SessionSetup.tscn")
