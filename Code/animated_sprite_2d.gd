extends AnimatedSprite2D

func _ready():
	var anim := "default"
	if sprite_frames.has_animation(anim):
		# Make sure the animation loops forever
		sprite_frames.set_animation_loop(anim, true)
		# Playback speed multiplier: 3.0 = 3x faster (1.0 = normal, 0.5 = half speed)
		speed_scale = 3.0
		# Start playing the chosen animation
		play(anim)
