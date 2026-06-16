extends RefCounted

## Loads the CS 1.6 menu interaction sounds from the player's local install
## (resolved through the GoldSrc VFS, never bundled) and plays them on button
## rollover / click. Missing sounds degrade silently rather than faking audio
## (DECISIONS 0007).
##
## Paths confirmed against a licensed install: valve/sound/ui/buttonrollover.wav
## and buttonclickrelease.wav (the VFS searches cstrike then valve).

class_name OpenStrikeCSUiSounds

const ROLLOVER_PATH := "sound/ui/buttonrollover.wav"
const CLICK_PATH := "sound/ui/buttonclickrelease.wav"
const VOLUME_DB := -6.0

var _rollover: AudioStream = null
var _click: AudioStream = null
var _rollover_player: AudioStreamPlayer = null
var _click_player: AudioStreamPlayer = null
var _report: Dictionary = {}


## host_node owns the AudioStreamPlayer lifetime; asset_manager resolves WAVs.
func configure(host_node: Node, asset_manager) -> void:
	_rollover = _load_stream(asset_manager, ROLLOVER_PATH)
	_click = _load_stream(asset_manager, CLICK_PATH)

	_rollover_player = AudioStreamPlayer.new()
	_rollover_player.volume_db = VOLUME_DB
	host_node.add_child(_rollover_player)

	_click_player = AudioStreamPlayer.new()
	_click_player.volume_db = VOLUME_DB
	host_node.add_child(_click_player)


## Wire a button so hovering plays rollover and pressing plays click, exactly
## like the CS main menu.
func attach(button: BaseButton) -> void:
	button.mouse_entered.connect(play_rollover)
	button.pressed.connect(play_click)


func play_rollover() -> void:
	if _rollover != null and _rollover_player != null:
		_rollover_player.stream = _rollover
		_rollover_player.play()


func play_click() -> void:
	if _click != null and _click_player != null:
		_click_player.stream = _click
		_click_player.play()


func report() -> Dictionary:
	return _report.duplicate(true)


func _load_stream(asset_manager, relative_path: String) -> AudioStream:
	var entry := {"relative_path": relative_path, "found": false, "loaded": false}
	if asset_manager != null and asset_manager.is_available():
		var resolved: Dictionary = asset_manager.resolve_asset(relative_path)
		if bool(resolved.get("found", false)):
			entry["found"] = true
			var stream := AudioStreamWAV.load_from_file(str(resolved.get("resolved_path", "")))
			if stream != null:
				entry["loaded"] = true
				_report[relative_path] = entry
				return stream
	_report[relative_path] = entry
	return null
