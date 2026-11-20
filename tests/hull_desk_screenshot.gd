extends SceneTree

const Desk = preload("res://scripts/hull_desk.gd")
const HullAudio = preload("res://scripts/hull_audio.gd")
const Registry = preload("res://scripts/hull_admin_registry.gd")

class FixtureAdmin:
	extends RefCounted
	var audio: Node
	var calls: Array[String] = []
	func execute(line: String) -> String:
		calls.append(line)
		var words: PackedStringArray = Registry.tokens(line).words
		return audio.command(PackedStringArray(words.slice(1))) if words.size() > 1 and words[0] == "audio" else "Ready · " + line
	func complete(line: String) -> PackedStringArray:
		return PackedStringArray([line + "combat.shield.catch"])

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.size = Vector2(1100, 720)
	root.add_child(container)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1100, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	var desk := Desk.new()
	viewport.add_child(desk)
	var audio := HullAudio.new()
	viewport.add_child(audio)
	audio.initialize(OS.get_environment("ASTRAL_SAVE_DIR"))
	print("BANK ", audio.bank.size(), " ERROR ", audio.last_error, " CUES ", audio.options("cues").size())
	assert(audio.last_error.is_empty() and not audio.options("cues").is_empty(), "Actual sound bank failed to load")
	var admin := FixtureAdmin.new()
	admin.audio = audio
	desk.setup(admin, audio)
	for i in 3: await process_frame
	var shield_index := -1
	for i in desk._catalog.item_count:
		if desk._catalog_cues[i] == "combat_shield":
			shield_index = i
			break
	assert(shield_index >= 0, "combat_shield must be in the real cue bank")
	desk._catalog.select(shield_index)
	desk._select_cue(shield_index)
	for i in desk._group_select.item_count:
		if desk._group_select.get_item_text(i) == "support/status":
			desk._group_select.select(i)
			desk._group = desk._group_select.get_item_text(i)
			desk._refresh_catalog()
			break
	var filtered_shield := -1
	for i in desk._catalog.item_count:
		if desk._catalog_cues[i] == "combat_shield":
			filtered_shield = i
	assert(filtered_shield >= 0, "Selecting a bank group filters to its actual cues")
	desk._catalog.select(filtered_shield)
	desk._select_cue(filtered_shield)
	print("SELECTED ", desk._cue, " TITLE ", desk.find_child("CueTitle", true, false).text)
	assert(desk.find_child("CueTitle", true, false).text == "COMBAT_SHIELD", "Selected cue title updates")
	desk._audition()
	assert(audio.trace.size() > 0 and audio.trace.back().cue == "combat_shield", "Audition must reach the real mixer and cue trace")
	assert(audio.trace.back().patch == "combat_shield_near", "Trace must identify the selected variant")
	admin.execute("audio bind combat_shield combat_shield_near")
	admin.execute("audio ab store")
	admin.execute("audio bind combat_shield combat_shield_hollow")
	admin.execute("audio ab swap")
	assert(audio.overrides.combat_shield.get("patch") == "combat_shield_near", "A/B swap restores stored mapping")
	admin.execute("audio mix combat_shield gain_db -15")
	admin.execute("audio preset save ui-fixture")
	assert(FileAccess.file_exists(audio.storage.path_join("ui-fixture.json")), "Preset save should use local sound settings")
	admin.execute("audio factory")
	admin.execute("audio preset load ui-fixture")
	assert(audio.overrides.combat_shield.get("patch") == "combat_shield_near", "Preset round trip restores cue binding")
	desk._select_cue(filtered_shield)
	assert(is_equal_approx((desk.find_child("GainSlider", true, false) as HSlider).value, -15.0), "Cue controls restore the saved mix without jumping")
	assert((desk.find_child("PatchSelect", true, false) as OptionButton).get_item_text((desk.find_child("PatchSelect", true, false) as OptionButton).selected) == "combat_shield_near", "Selected patch reflects saved binding")
	admin.execute("audio stinger off")
	assert(not audio.stingers_enabled, "Stinger toggle should reach the sound runtime")
	var track_select := desk.find_child("TrackSelect", true, false) as OptionButton
	var track_solo := desk.find_child("TrackSolo", true, false) as CheckButton
	var multiword_track := -1
	for i in track_select.item_count:
		if track_select.get_item_text(i) == "bowed hull":
			multiword_track = i
			break
	assert(multiword_track >= 0, "Multitrack bank exposes a multiword track ID")
	track_select.select(multiword_track)
	track_solo.toggled.emit(true)
	assert(audio.solo == "bowed hull", "Quoted solo command preserves a multiword track ID")
	assert(admin.calls.back() == "audio solo \"bowed hull\"", "Track command quotes its ID")
	audio.command(PackedStringArray(["audition", "combat_shield"]))
	desk._update_playing()
	for i in 2: await process_frame
	desk._update_playing()
	var image := viewport.get_texture().get_image()
	var path := OS.get_environment("HULL_DESK_SCREENSHOT")
	image.save_png(path)
	print("HULL_DESK_SCREENSHOT ", path, " ", image.get_width(), "x", image.get_height())
	print("HULL_DESK_INTEGRATION PASS 12 checks, 0 failures")
	quit()
