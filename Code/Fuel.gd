extends Area2D

func _on_body_shape_entered(body_rid: RID, body: Node2D, body_shape_index: int, local_shape_index: int) -> void:
	var actor := body
	while actor and not actor.is_in_group("player"):
		actor = actor.get_parent()
	if actor and actor.has_method("refuel"):
		actor.refuel()
		$AnimationPlayer.play("pickup")
		$CollisionShape2D.set_deferred("disabled", true)

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	queue_free()
