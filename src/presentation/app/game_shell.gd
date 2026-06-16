extends Node

## Game application shell: CS-styled main menu -> map select -> walkable map.
##
## Player-facing entry (res://scenes/app/Main.tscn), distinct from src/dev labs.
## Reuses src/core asset/map loading and the src/game authoritative session; it
## must not import dev-lab code. The CS look (background tiles, menu sounds,
## fonts) is loaded from the player's local install through the VFS, never
## bundled; only OpenStrike code (theme/loaders) is committed.
##
## Collision under the walkable map is still the non-parity Godot backend until
## the GoldSrc clipnode trace lands; the in-map overlay says so.

class_name OpenStrikeGameShell

const AssetManagerRef = preload("res://src/core/assets/asset_manager.gd")
const WalkableWorldRef = preload("res://src/presentation/app/walkable_world.gd")
const LocalConfigRef = preload("res://src/core/assets/goldsrc_local_config.gd")
const CSSchemeRef = preload("res://src/presentation/ui/cs_scheme.gd")
const CSUiSoundsRef = preload("res://src/presentation/ui/cs_ui_sounds.gd")
const CSBackgroundRef = preload("res://src/presentation/ui/cs_background.gd")

const MAPS_DIR := "maps"
const MAP_EXTENSIONS: Array[String] = ["bsp"]

var config_path := LocalConfigRef.DEFAULT_CONFIG_PATH

var _asset_manager = null
var _sounds = null
var _ui_layer: CanvasLayer = null
var _background: Control = null
var _screen_root: Control = null
var _world: Node3D = null
var _menu_theme: Theme = null
var _dialog_theme: Theme = null
var _map_group: ButtonGroup = null


func _ready() -> void:
	_apply_fullscreen()
	_asset_manager = AssetManagerRef.create_from_config_path(config_path)
	_menu_theme = CSSchemeRef.main_menu_theme()
	_dialog_theme = CSSchemeRef.dialog_theme()

	_sounds = CSUiSoundsRef.new()
	_sounds.configure(self, _asset_manager)

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "ShellUI"
	add_child(_ui_layer)

	_background = CSBackgroundRef.build(_asset_manager)
	if _background == null:
		_background = _fallback_background()
	_ui_layer.add_child(_background)

	show_main_menu()


func show_main_menu() -> void:
	_teardown_world()
	_set_ui_visible(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var screen := _new_screen()
	screen.theme = _menu_theme

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.anchor_left = 0.0
	column.anchor_right = 0.0
	column.anchor_top = 1.0
	column.anchor_bottom = 1.0
	column.grow_horizontal = Control.GROW_DIRECTION_END
	column.grow_vertical = Control.GROW_DIRECTION_BEGIN
	column.offset_left = 28.0
	column.offset_top = -360.0
	column.offset_bottom = -44.0
	screen.add_child(column)

	# Faithful CS main-menu item set; New Game and Quit are wired, the rest are
	# present-but-disabled until those flows exist.
	column.add_child(_menu_item("Random Server", Callable(), true))
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 22.0)
	column.add_child(spacer)
	column.add_child(_menu_item("New Game", show_map_select))
	column.add_child(_menu_item("Find Servers", Callable(), true))
	column.add_child(_menu_item("Settings", Callable(), true))
	column.add_child(_menu_item("Quit", _quit))


func show_map_select() -> void:
	_set_ui_visible(true)
	var screen := _new_screen()
	screen.theme = _dialog_theme

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)

	var window := PanelContainer.new()
	window.custom_minimum_size = Vector2(520.0, 470.0)
	center.add_child(window)

	var frame := VBoxContainer.new()
	frame.add_theme_constant_override("separation", 0)
	window.add_child(frame)

	# Title bar: "Create Server" with an X close button, like the CS dialog.
	var title_bar := PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", CSSchemeRef.title_bar_box())
	frame.add_child(title_bar)
	var title_row := HBoxContainer.new()
	title_bar.add_child(title_row)
	var title := Label.new()
	title.text = "Create Server"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	var close := Button.new()
	close.text = "X"
	close.flat = true
	close.pressed.connect(show_main_menu)
	if _sounds != null:
		_sounds.attach(close)
	title_row.add_child(close)

	# Body with margins inside the olive window.
	var body := MarginContainer.new()
	body.add_theme_constant_override("margin_left", 14)
	body.add_theme_constant_override("margin_right", 14)
	body.add_theme_constant_override("margin_top", 12)
	body.add_theme_constant_override("margin_bottom", 12)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(body)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	body.add_child(column)

	var map_label := Label.new()
	map_label.text = "Map"
	column.add_child(map_label)

	var maps := _scan_maps()
	if maps.is_empty():
		var note := Label.new()
		note.text = (
			"No maps found.\n"
			+ "Point user://local_goldsrc.json at an installed CS 1.6\n"
			+ "with a maps/ folder of .bsp files."
		)
		note.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(note)
	else:
		# Dark recessed list area with amber selectable rows (toggle group).
		var inset := PanelContainer.new()
		inset.add_theme_stylebox_override("panel", CSSchemeRef.list_inset_box())
		inset.size_flags_vertical = Control.SIZE_EXPAND_FILL
		column.add_child(inset)
		var scroll := ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		inset.add_child(scroll)
		var list := VBoxContainer.new()
		list.add_theme_constant_override("separation", 0)
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(list)

		_map_group = ButtonGroup.new()
		for map_index in maps.size():
			var map_entry: Dictionary = maps[map_index]
			var row := Button.new()
			row.text = str(map_entry.get("stem", map_entry.get("name", "map")))
			row.toggle_mode = true
			row.button_group = _map_group
			row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			row.set_meta("map_path", str(map_entry.get("relative_path", "")))
			CSSchemeRef.style_list_row(row)
			row.button_pressed = map_index == 0  # default-select first, like CS
			if _sounds != null:
				_sounds.attach(row)
			list.add_child(row)

	# Action buttons bottom-right: Start / Cancel, like Начало / Отмена.
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	if not maps.is_empty():
		var start := Button.new()
		start.text = "Start"
		start.pressed.connect(_start_selected_map)
		if _sounds != null:
			_sounds.attach(start)
		actions.add_child(start)
	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(show_main_menu)
	if _sounds != null:
		_sounds.attach(cancel)
	actions.add_child(cancel)


func _start_selected_map() -> void:
	if _map_group == null:
		return
	var selected := _map_group.get_pressed_button()
	if selected != null and selected.has_meta("map_path"):
		_start_map(str(selected.get_meta("map_path")))


func _menu_item(text: String, on_pressed: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.flat = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = disabled
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	if not disabled and on_pressed.is_valid():
		button.pressed.connect(on_pressed)
	if _sounds != null and not disabled:
		_sounds.attach(button)
	return button


func _scan_maps() -> Array[Dictionary]:
	if _asset_manager == null or _asset_manager.vfs == null or not _asset_manager.vfs.is_available():
		return []
	return _asset_manager.vfs.list_files(MAPS_DIR, MAP_EXTENSIONS)


func _start_map(map_path: String) -> void:
	if map_path == "":
		return
	_teardown_world()

	var world = WalkableWorldRef.new()
	world.name = "WalkableWorld"
	_world = world
	world.exit_requested.connect(show_main_menu)
	add_child(world)

	var started: Dictionary = world.start_map(_asset_manager, map_path)
	if not bool(started.get("ok", false)):
		_teardown_world()
		_show_load_error(map_path, started)
		return

	_set_ui_visible(false)


func _show_load_error(map_path: String, result: Dictionary) -> void:
	_set_ui_visible(true)
	var screen := _new_screen()
	screen.theme = _dialog_theme
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var note := Label.new()
	note.text = "Could not load %s\n%s" % [map_path, str(result.get("reason", "see diagnostics"))]
	column.add_child(note)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(show_map_select)
	if _sounds != null:
		_sounds.attach(back)
	column.add_child(back)


func _teardown_world() -> void:
	if _world != null:
		_world.queue_free()
		_world = null


func _set_ui_visible(visible: bool) -> void:
	if _ui_layer != null:
		_ui_layer.visible = visible


func _new_screen() -> Control:
	if _screen_root != null:
		_screen_root.queue_free()
		_screen_root = null
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_layer.add_child(root)
	_screen_root = root
	return root


func _fallback_background() -> Control:
	var rect := ColorRect.new()
	rect.color = Color(0.06, 0.07, 0.09, 1.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _apply_fullscreen() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	if window != null:
		window.mode = Window.MODE_FULLSCREEN


func _quit() -> void:
	get_tree().quit(0)
