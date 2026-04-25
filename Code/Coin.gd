extends Area2D

@export var value: int = 5

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("radler"):
		get_tree().get_current_scene().add_coins(value)
		$AnimationPlayer.play("pickup")
		$CollisionShape2D.set_deferred("disabled", true)

func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	queue_free()
