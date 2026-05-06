# File: res://clean_all_scenes.gd
# Godot 4.x
@tool
extends EditorScript

const ROOTS := [
	"res://Levels",
	"res://Scenes"
]

const MAKE_BACKUP := true      # Lager .bak ved siden av .tscn før overskriving
const SAVE_BINARY := false     # Sett true hvis du heller vil lagre som .scn

func _run():
	var all: Array = []
	for r in ROOTS:
		all += _list_tscn(r)
	if all.is_empty():
		print("Fant ingen .tscn i:", ROOTS)
		return

	var ok := 0
	for p in all:
		if _clean_scene(p):
			ok += 1
	print("Ferdig: renset %d/%d scener." % [ok, all.size()])

func _list_tscn(dir_path: String) -> Array:
	var out: Array = []
	var da := DirAccess.open(dir_path)
	if da == null:
		return out
	da.list_dir_begin()
	while true:
		var name := da.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var full := dir_path.path_join(name)
		if da.current_is_dir():
			out += _list_tscn(full)
		elif full.ends_with(".tscn"):
			out.append(full)
	da.list_dir_end()
	return out

func _clean_scene(path: String) -> bool:
	var ps := load(path) as PackedScene
	if ps == null:
		push_warning("Hopper over (ikke PackedScene): %s" % path)
		return false

	var inst := ps.instantiate()
	if inst == null:
		push_warning("Kan ikke instansiere: %s" % path)
		return false

	var repacked := PackedScene.new()
	var err := repacked.pack(inst)
	if err != OK:
		push_error("Pack feilet for %s (%s)" % [path, err])
		return false

	var save_path := path
	if SAVE_BINARY:
		save_path = path.get_basename() + ".scn"

	if MAKE_BACKUP and not SAVE_BINARY:
		var backup := path + ".bak"
		if FileAccess.file_exists(path):
			var src := FileAccess.open(path, FileAccess.READ)
			var dst := FileAccess.open(backup, FileAccess.WRITE)
			if src and dst:
				dst.store_buffer(src.get_buffer(src.get_length()))
				dst.close()
				src.close()

	var flags := ResourceSaver.FLAG_RELATIVE_PATHS
	err = ResourceSaver.save(repacked, save_path, flags)  # <- riktig rekkefølge i Godot 4
	if err != OK:
		push_error("Save feilet: %s (%s)" % [save_path, err])
		return false

	print("Renset og lagret:", save_path)
	return true
