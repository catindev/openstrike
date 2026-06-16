extends RefCounted

## CS 1.6 menu look, reconstructed as values (not assets) from a licensed
## install's resource/ClientScheme.res and reference screenshots of the running
## game. Colors/insets/font-weight are facts about the look, not Valve asset
## bytes, so they are safe to ship. Glyphs come from the host system font.
##
## Two looks, per the real game:
##  - Main menu items: amber text, lower-left, transparent, brighten on hover.
##  - Dialogs (create-server window, where map choice lives): translucent
##    khaki-olive window with a title bar, tabs, dark fields, amber text
##    (255 176 0), hairline borders and beveled buttons.

class_name OpenStrikeCSScheme

# Main-menu text (from reference screenshots).
const MENU_TEXT := Color(238.0 / 255.0, 171.0 / 255.0, 35.0 / 255.0, 1.0)
const MENU_TEXT_HOVER := Color(1.0, 210.0 / 255.0, 62.0 / 255.0, 1.0)
const MENU_TEXT_DISABLED := Color(140.0 / 255.0, 114.0 / 255.0, 42.0 / 255.0, 1.0)
const MENU_TEXT_SHADOW := Color(0.0, 0.0, 0.0, 0.7)

# Dialog palette.
const AMBER := Color(1.0, 176.0 / 255.0, 0.0, 1.0)
const AMBER_BRIGHT := Color(1.0, 205.0 / 255.0, 0.0, 1.0)
const AMBER_DISABLED := Color(120.0 / 255.0, 96.0 / 255.0, 32.0 / 255.0, 1.0)
# Translucent khaki-green window, lighter/greener than near-black so the menu
# artwork shows through (matches the create-server screenshot).
const OLIVE_PANEL := Color(78.0 / 255.0, 89.0 / 255.0, 67.0 / 255.0, 248.0 / 255.0)
const OLIVE_TITLE := Color(57.0 / 255.0, 66.0 / 255.0, 47.0 / 255.0, 1.0)
const OLIVE_BUTTON := Color(76.0 / 255.0, 86.0 / 255.0, 63.0 / 255.0, 1.0)
const HAIRLINE := Color(160.0 / 255.0, 172.0 / 255.0, 136.0 / 255.0, 0.82)
const DARK_EDGE := Color(26.0 / 255.0, 31.0 / 255.0, 23.0 / 255.0, 0.85)
const FIELD_DARK := Color(46.0 / 255.0, 54.0 / 255.0, 38.0 / 255.0, 1.0)
const FIELD_DARK_DISABLED := Color(43.0 / 255.0, 49.0 / 255.0, 36.0 / 255.0, 1.0)

const FONT_FALLBACKS: PackedStringArray = ["Verdana", "DejaVu Sans", "Arial", "Noto Sans"]


static func menu_font() -> Font:
	var font := SystemFont.new()
	font.font_names = FONT_FALLBACKS
	font.font_weight = 400
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return font


## Theme for the main menu: transparent flat buttons, amber text with a dark
## shadow for legibility over the artwork, brightening on hover.
static func main_menu_theme(font_size: int = 30) -> Theme:
	var font := menu_font()
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = font_size

	theme.set_font("font", "Button", font)
	theme.set_font_size("font_size", "Button", font_size)
	theme.set_color("font_color", "Button", MENU_TEXT)
	theme.set_color("font_hover_color", "Button", MENU_TEXT_HOVER)
	theme.set_color("font_pressed_color", "Button", MENU_TEXT_HOVER)
	theme.set_color("font_focus_color", "Button", MENU_TEXT_HOVER)
	theme.set_color("font_hover_pressed_color", "Button", MENU_TEXT_HOVER)
	theme.set_color("font_disabled_color", "Button", MENU_TEXT_DISABLED)
	theme.set_color("font_outline_color", "Button", MENU_TEXT_SHADOW)
	theme.set_constant("outline_size", "Button", 2)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 2
	empty.content_margin_top = 4
	empty.content_margin_bottom = 4
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "Button", empty)

	theme.set_font("font", "Label", font)
	theme.set_color("font_color", "Label", MENU_TEXT)
	return theme


## Theme for the create-server style dialog window where map choice lives.
static func dialog_theme(font_size: int = 17) -> Theme:
	var font := menu_font()
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = font_size

	theme.set_stylebox("panel", "PanelContainer", _panel_box(OLIVE_PANEL))

	theme.set_font("font", "Label", font)
	theme.set_color("font_color", "Label", MENU_TEXT)
	theme.set_font_size("font_size", "Label", font_size)

	theme.set_font("font", "Button", font)
	theme.set_font_size("font_size", "Button", font_size)
	theme.set_color("font_color", "Button", MENU_TEXT)
	theme.set_color("font_hover_color", "Button", MENU_TEXT_HOVER)
	theme.set_color("font_pressed_color", "Button", MENU_TEXT_HOVER)
	theme.set_color("font_disabled_color", "Button", MENU_TEXT_DISABLED)
	theme.set_stylebox("normal", "Button", _beveled_box(OLIVE_BUTTON))
	theme.set_stylebox("hover", "Button", _beveled_box(OLIVE_BUTTON.lightened(0.12)))
	theme.set_stylebox("pressed", "Button", _beveled_box(OLIVE_BUTTON.darkened(0.12)))
	theme.set_stylebox("disabled", "Button", _beveled_box(OLIVE_BUTTON.darkened(0.25)))

	theme.set_font("font", "OptionButton", font)
	theme.set_font_size("font_size", "OptionButton", font_size)
	theme.set_color("font_color", "OptionButton", MENU_TEXT)
	theme.set_color("font_hover_color", "OptionButton", MENU_TEXT_HOVER)
	theme.set_color("font_pressed_color", "OptionButton", MENU_TEXT_HOVER)
	theme.set_color("font_disabled_color", "OptionButton", MENU_TEXT_DISABLED)
	theme.set_stylebox("normal", "OptionButton", _field_box(FIELD_DARK))
	theme.set_stylebox("hover", "OptionButton", _field_box(FIELD_DARK.lightened(0.07)))
	theme.set_stylebox("pressed", "OptionButton", _field_box(FIELD_DARK.darkened(0.06)))
	theme.set_stylebox("disabled", "OptionButton", _field_box(FIELD_DARK_DISABLED))

	theme.set_font("font", "LineEdit", font)
	theme.set_font_size("font_size", "LineEdit", font_size)
	theme.set_color("font_color", "LineEdit", MENU_TEXT)
	theme.set_color("font_uneditable_color", "LineEdit", MENU_TEXT_DISABLED)
	theme.set_stylebox("normal", "LineEdit", _field_box(FIELD_DARK))
	theme.set_stylebox("read_only", "LineEdit", _field_box(FIELD_DARK_DISABLED))

	return theme


## Olive window title-bar background (darker strip across the top).
static func title_bar_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = OLIVE_TITLE
	_apply_bevel(box, false)
	box.border_width_bottom = 1
	box.content_margin_left = 8
	box.content_margin_right = 5
	box.content_margin_top = 6
	box.content_margin_bottom = 5
	return box


static func style_combobox(option: OptionButton) -> void:
	option.custom_minimum_size = Vector2(260.0, 30.0)
	option.flat = false
	style_popup_menu(option.get_popup())


static func style_dialog_tab(button: Button, active: bool, disabled: bool) -> void:
	if button.text == "CPU Player Options":
		button.custom_minimum_size = Vector2(174.0, 36.0)
	else:
		button.custom_minimum_size = Vector2(118.0, 36.0)
	button.flat = false
	button.add_theme_color_override("font_color", AMBER if active else MENU_TEXT)
	button.add_theme_color_override("font_hover_color", AMBER_BRIGHT)
	button.add_theme_color_override("font_disabled_color", MENU_TEXT_DISABLED)
	var color := OLIVE_PANEL.lightened(0.05) if active else OLIVE_PANEL.darkened(0.05)
	if disabled:
		color = OLIVE_PANEL.darkened(0.09)
	button.add_theme_stylebox_override("normal", _tab_box(color, active))
	button.add_theme_stylebox_override("hover", _tab_box(color.lightened(0.08), active))
	button.add_theme_stylebox_override("pressed", _tab_box(color.darkened(0.08), active))
	button.add_theme_stylebox_override("disabled", _tab_box(color, active))


static func separator() -> ColorRect:
	var rect := ColorRect.new()
	rect.color = HAIRLINE
	rect.custom_minimum_size = Vector2(0.0, 1.0)
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return rect


static func style_popup_menu(popup: PopupMenu) -> void:
	if popup == null:
		return
	var font := menu_font()
	popup.add_theme_font_override("font", font)
	popup.add_theme_font_size_override("font_size", 17)
	popup.add_theme_color_override("font_color", MENU_TEXT)
	popup.add_theme_color_override("font_hover_color", MENU_TEXT_HOVER)
	popup.add_theme_color_override("font_disabled_color", MENU_TEXT_DISABLED)
	popup.add_theme_stylebox_override("panel", _field_box(FIELD_DARK))
	popup.add_theme_stylebox_override("hover", _selection_box())
	popup.add_theme_constant_override("v_separation", 1)
	popup.add_theme_constant_override("item_start_padding", 8)
	popup.add_theme_constant_override("item_end_padding", 8)


static func loading_panel_box() -> StyleBoxFlat:
	var box := _panel_box(OLIVE_PANEL)
	box.content_margin_left = 28
	box.content_margin_right = 28
	box.content_margin_top = 20
	box.content_margin_bottom = 20
	return box


static func progress_track_box() -> StyleBoxFlat:
	var box := _field_box(FIELD_DARK)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box


static func progress_segment_color() -> Color:
	return Color(218.0 / 255.0, 198.0 / 255.0, 77.0 / 255.0, 1.0)


static func field_dark_color() -> Color:
	return FIELD_DARK


static func amber_color() -> Color:
	return AMBER


static func _panel_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	_apply_bevel(box, false)
	box.set_border_width_all(1)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


static func _beveled_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	_apply_bevel(box, false)
	box.set_border_width_all(1)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


static func _field_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	_apply_bevel(box, true)
	box.set_border_width_all(1)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	return box


static func _selection_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(160.0 / 255.0, 146.0 / 255.0, 42.0 / 255.0, 1.0)
	box.border_color = Color(178.0 / 255.0, 166.0 / 255.0, 72.0 / 255.0, 1.0)
	box.set_border_width_all(1)
	box.anti_aliasing = false
	return box


static func _tab_box(color: Color, active: bool) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	_apply_bevel(box, false)
	box.border_width_left = 1
	box.border_width_top = 1
	box.border_width_right = 1
	box.border_width_bottom = 0 if active else 1
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 2
	box.content_margin_bottom = 2
	return box


static func _apply_bevel(box: StyleBoxFlat, recessed: bool) -> void:
	box.border_color = DARK_EDGE if recessed else HAIRLINE
	box.shadow_color = HAIRLINE if recessed else DARK_EDGE
	box.shadow_size = 1
	box.shadow_offset = Vector2(-1.0, -1.0) if recessed else Vector2(1.0, 1.0)
	box.anti_aliasing = false
