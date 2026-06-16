extends RefCounted

## CS 1.6 menu look, reconstructed as values (not assets) from a licensed
## install's resource/ClientScheme.res and reference screenshots of the running
## game. Colors/insets/font-weight are facts about the look, not Valve asset
## bytes, so they are safe to ship. Glyphs come from the host system font.
##
## Two looks, per the real game:
##  - Main menu items: light-grey text, lower-left, transparent, brighten on
##    hover. NOT amber.
##  - Dialogs (create-server window, where map choice lives): translucent
##    khaki-olive window with a title bar, dark inset list area, amber text
##    (255 176 0), amber selection bar, beveled amber-bordered buttons.

class_name OpenStrikeCSScheme

# Main-menu text (from reference screenshots).
const MENU_TEXT := Color(210.0 / 255.0, 210.0 / 255.0, 210.0 / 255.0, 1.0)
const MENU_TEXT_HOVER := Color(1.0, 1.0, 1.0, 1.0)
const MENU_TEXT_DISABLED := Color(120.0 / 255.0, 120.0 / 255.0, 120.0 / 255.0, 1.0)
const MENU_TEXT_SHADOW := Color(0.0, 0.0, 0.0, 0.7)

# Dialog palette.
const AMBER := Color(1.0, 176.0 / 255.0, 0.0, 1.0)
const AMBER_BRIGHT := Color(1.0, 205.0 / 255.0, 0.0, 1.0)
const AMBER_DISABLED := Color(120.0 / 255.0, 96.0 / 255.0, 32.0 / 255.0, 1.0)
const SELECTION_BAR := Color(1.0, 176.0 / 255.0, 0.0, 110.0 / 255.0)
# Translucent khaki-green window, lighter/greener than near-black so the menu
# artwork shows through (matches the create-server screenshot).
const OLIVE_PANEL := Color(84.0 / 255.0, 92.0 / 255.0, 68.0 / 255.0, 206.0 / 255.0)
const OLIVE_TITLE := Color(62.0 / 255.0, 68.0 / 255.0, 48.0 / 255.0, 236.0 / 255.0)
const OLIVE_BUTTON := Color(98.0 / 255.0, 106.0 / 255.0, 78.0 / 255.0, 1.0)
const LIST_INSET := Color(28.0 / 255.0, 32.0 / 255.0, 22.0 / 255.0, 200.0 / 255.0)
const BORDER := Color(188.0 / 255.0, 112.0 / 255.0, 0.0, 180.0 / 255.0)

const FONT_FALLBACKS: PackedStringArray = ["Verdana", "DejaVu Sans", "Arial", "Noto Sans"]


static func menu_font() -> Font:
	var font := SystemFont.new()
	font.font_names = FONT_FALLBACKS
	font.font_weight = 600
	font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return font


## Theme for the main menu: transparent flat buttons, light-grey text with a
## dark shadow for legibility over the artwork, brightening to white on hover.
static func main_menu_theme(font_size: int = 22) -> Theme:
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
	theme.set_constant("outline_size", "Button", 3)
	var empty := StyleBoxEmpty.new()
	empty.content_margin_left = 2
	empty.content_margin_top = 3
	empty.content_margin_bottom = 3
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		theme.set_stylebox(state, "Button", empty)

	theme.set_font("font", "Label", font)
	theme.set_color("font_color", "Label", MENU_TEXT)
	return theme


## Theme for the create-server style dialog window where map choice lives.
static func dialog_theme(font_size: int = 18) -> Theme:
	var font := menu_font()
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = font_size

	theme.set_stylebox("panel", "PanelContainer", _panel_box(OLIVE_PANEL))

	theme.set_font("font", "Label", font)
	theme.set_color("font_color", "Label", AMBER)

	theme.set_font("font", "Button", font)
	theme.set_font_size("font_size", "Button", font_size)
	theme.set_color("font_color", "Button", AMBER)
	theme.set_color("font_hover_color", "Button", AMBER_BRIGHT)
	theme.set_color("font_pressed_color", "Button", AMBER_BRIGHT)
	theme.set_color("font_disabled_color", "Button", AMBER_DISABLED)
	theme.set_stylebox("normal", "Button", _beveled_box(OLIVE_BUTTON))
	theme.set_stylebox("hover", "Button", _beveled_box(OLIVE_BUTTON.lightened(0.12)))
	theme.set_stylebox("pressed", "Button", _beveled_box(OLIVE_BUTTON.darkened(0.12)))
	theme.set_stylebox("disabled", "Button", _beveled_box(OLIVE_BUTTON.darkened(0.25)))

	return theme


## Olive window title-bar background (darker strip across the top).
static func title_bar_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = OLIVE_TITLE
	box.border_color = BORDER
	box.border_width_bottom = 1
	box.content_margin_left = 10
	box.content_margin_right = 6
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box


## Dark inset box behind the map list (CS list boxes are a dark recessed area).
static func list_inset_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = LIST_INSET
	box.border_color = BORDER
	box.set_border_width_all(1)
	box.content_margin_left = 4
	box.content_margin_right = 4
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box


## Flat amber-text row for the map list: transparent normal, translucent amber
## selection bar on hover and while selected (toggle). The CS list highlight.
static func style_list_row(button: Button) -> void:
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_color_override("font_color", AMBER)
	button.add_theme_color_override("font_hover_color", AMBER_BRIGHT)
	button.add_theme_color_override("font_pressed_color", AMBER_BRIGHT)
	var normal := StyleBoxEmpty.new()
	normal.content_margin_left = 6
	normal.content_margin_top = 2
	normal.content_margin_bottom = 2
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("focus", normal)
	var bar := StyleBoxFlat.new()
	bar.bg_color = SELECTION_BAR
	bar.content_margin_left = 6
	bar.content_margin_top = 2
	bar.content_margin_bottom = 2
	button.add_theme_stylebox_override("hover", bar)
	button.add_theme_stylebox_override("pressed", bar)


static func _panel_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = BORDER
	box.set_border_width_all(1)
	box.content_margin_left = 0
	box.content_margin_right = 0
	box.content_margin_top = 0
	box.content_margin_bottom = 0
	return box


static func _beveled_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = BORDER
	box.set_border_width_all(1)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 5
	box.content_margin_bottom = 5
	return box
