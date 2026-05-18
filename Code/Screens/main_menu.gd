extends Control

# Main menu screen: handles navigation to name input and dashboard scenes.

const NAME_INPUT_SCENE_PATH: String = "res://Levels/NameInput.tscn"
const DASHBOARD_SCENE_PATH: String = "res://Levels/Dashboard.tscn"
const HIGHSCORES_SCENE_PATH: String = "res://Levels/Highscores.tscn"

# Cache for preloaded scenes (path -> PackedScene).
# We fill this once when the main menu opens so later switches are instant.
var _scene_cache: Dictionary = {}

func _ready() -> void:
	# Preload every .tscn inside res://Levels (recursively).
	# Simple and contained in this script; no need to list each scene.
	_preload_scenes_in_folder("res://Levels")

# Called by the Start Game button; goes to the name input screen.
func _on_start_game_pressed() -> void:
	_change_scene_fast(NAME_INPUT_SCENE_PATH)

# Called by the Dashboard button; goes to the dashboard scene.
func _on_dashboard_pressed() -> void:
	_change_scene_fast(DASHBOARD_SCENE_PATH)

# Called by the Highscores button; goes to the highscore scene.
func _on_highscores_pressed() -> void:
	_change_scene_fast(HIGHSCORES_SCENE_PATH)

# ---------- Helpers ----------

# Change scene using a preloaded PackedScene if available; otherwise fall back to loading by path.
# This keeps button presses fast after the main menu has preloaded everything.
func _change_scene_fast(path: String) -> void:
	var ps: PackedScene = _scene_cache.get(path, null)
	if ps:
		get_tree().change_scene_to_packed(ps)
	else:
		get_tree().change_scene_to_file(path)

# Recursively preload all .tscn files under a folder and store them in _scene_cache.
# This runs once when the menu opens so later scene switches won’t hitch.
func _preload_scenes_in_folder(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		push_warning("Could not open folder: " + dir_path)
		return

	dir.list_dir_begin()
	var entry_name: String = dir.get_next()
	while entry_name != "":
		if dir.current_is_dir():
			if entry_name != "." and entry_name != "..":
				_preload_scenes_in_folder(dir_path + "/" + entry_name)
		else:
			if entry_name.ends_with(".tscn"):
				var full_path: String = dir_path + "/" + entry_name
				var res: Resource = ResourceLoader.load(full_path)
				if res is PackedScene:
					_scene_cache[full_path] = res
		entry_name = dir.get_next()
	dir.list_dir_end()
