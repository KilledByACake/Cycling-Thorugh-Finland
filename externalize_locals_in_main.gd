# File: res://externalize_locals_in_main.gd
# Godot 4.x
@tool
extends EditorScript

# Scenen vi vil rydde
const SCENE_PATH := "res://Levels/Main.tscn"

# Hvor vi legger eksterne .res-filer
const OUT_DIR := "res://Externalized/Main"

# Hvis du vil lagre til en ny tscn i stedet for å overskrive original:
const SAVE_TO_NEW_TSCN := false
const NEW_TSCN_PATH := "res://Levels/Main_clean.tscn"

func _run():
	# Sørg for at OUT_DIR finnes
	if not DirAccess.dir_exists_absolute(OUT_DIR):
		var ok := DirAccess.make_dir_recursive_absolute(OUT_DIR)
		if ok != OK:
			push_error("Kunne ikke opprette mappe: " + OUT_DIR)
			return

	var ps := load(SCENE_PATH) as PackedScene
	if ps == null:
		push_error("Finner ikke scene: " + SCENE_PATH)
		return

	var inst := ps.instantiate()
	if inst == null:
		push_error("Kan ikke instansiere scenen.")
		return

	var count := _process_node(inst, "")

	print("Eksternaliserte %d lokale ressurser." % count)

	# Pakk og lagre scenen på nytt
	var repacked := PackedScene.new()
	var err := repacked.pack(inst)
	if err != OK:
		push_error("Pack feilet: %s" % err)
		return

	var target := SCENE_PATH
	if SAVE_TO_NEW_TSCN:
		target = NEW_TSCN_PATH

	err = ResourceSaver.save(repacked, target, ResourceSaver.FLAG_RELATIVE_PATHS)
	if err != OK:
		push_error("Lagring feilet: %s" % err)
	else:
		print("Lagret scene:", target)

func _process_node(n: Node, ctx: String) -> int:
	var c := 0
	for p in n.get_property_list():
		var name: String = p.name
		var v = n.get(name)
		c += _process_value(v, "%s/%s.%s" % [ctx, n.name, name])
	for child in n.get_children():
		c += _process_node(child, "%s/%s" % [ctx, n.name])
	return c

func _process_value(v, ctx: String) -> int:
	var c := 0
	if v is Resource:
		c += _externalize_resource(v, ctx)
	elif v is Array:
		for i in v.size():
			c += _process_value(v[i], "%s[%d]" % [ctx, i])
	elif v is Dictionary:
		for k in v.keys():
			c += _process_value(v[k], "%s{%s}" % [ctx, str(k)])
	return c

func _externalize_resource(res: Resource, ctx: String) -> int:
	var total := 0
	# Hopp over Script-ressurser; de skal ikke lagres som .res
	if res is Script:
		return 0

	# Hvis den mangler path, er den "Local to Scene" -> gjør den ekstern
	if res.resource_path == "":
		# Gi en unik, sikker filsti
		var safe_ctx := ctx.replace("/", "_").replace(":", "_").replace(" ", "_")
		var path := "%s/%s_%s.res" % [OUT_DIR, res.get_class(), safe_ctx]
		# Sørg for at denne ressursen eier pathen sin
		res.take_over_path(path)
		var err := ResourceSaver.save(res, path)
		if err == OK:
			total += 1
			print("Lagret lokal ressurs som ekstern:", res.get_class(), "->", path)
		else:
			push_warning("Kunne ikke lagre %s ved %s (err=%s)" % [res.get_class(), ctx, err])

	# Gå også gjennom eventuelle nestede ressurser inni denne
	for p in res.get_property_list():
		var name: String = p.name
		var v = res.get(name)
		total += _process_value(v, ctx + ":" + name)

	return total
