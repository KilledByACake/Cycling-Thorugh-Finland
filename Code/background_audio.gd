# Background sounds that continues on all scenes. 
extends Node

var player: AudioStreamPlayer

func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	player.volume_db = -6.0
	add_child(player)

func play(stream: AudioStream, loop := true) -> void:
	player.stop()
	player.stream = stream
	# Anbefaling: sett loop i Import for fila. Hvis du MÅ sette i kode:
	if loop:
		if player.stream is AudioStreamOggVorbis:
			player.stream.loop = true
		elif player.stream is AudioStreamWAV:
			player.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	player.play()

func stop() -> void:
	player.stop()

func set_volume_db(db: float) -> void:
	player.volume_db = db
