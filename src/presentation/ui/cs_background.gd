extends RefCounted

## Composes the CS 1.6 menu/loading background from the player's local install.
## GoldSrc stores it as a tile grid resource/background/<width>_<row>_<col>_loading.tga
## (rows 1..3 top-to-bottom, cols a..d left-to-right). Tiles are loaded through
## the VFS (never bundled); if any is missing the caller uses a flat fallback.

class_name OpenStrikeCSBackground

const TILE_DIR := "resource/background"
const WIDTH_CLASS := "800"
const ROWS: Array[String] = ["1", "2", "3"]
const COLS: Array[String] = ["a", "b", "c", "d"]


## Returns a full-rect TextureRect with the composed background, or null when
## the local tiles cannot be resolved/decoded.
static func build(asset_manager) -> TextureRect:
	if asset_manager == null or not asset_manager.is_available():
		return null

	var grid: Array = []
	for row in ROWS:
		var row_images: Array = []
		for col in COLS:
			var image := _load_tile(asset_manager, row, col)
			if image == null:
				return null
			row_images.append(image)
		grid.append(row_images)

	var col_widths: Array[int] = []
	for col_index in COLS.size():
		col_widths.append(int((grid[0][col_index] as Image).get_width()))
	var row_heights: Array[int] = []
	for row_index in ROWS.size():
		row_heights.append(int((grid[row_index][0] as Image).get_height()))

	var total_width := 0
	for width in col_widths:
		total_width += width
	var total_height := 0
	for height in row_heights:
		total_height += height
	if total_width <= 0 or total_height <= 0:
		return null

	var composed := Image.create(total_width, total_height, false, Image.FORMAT_RGBA8)
	var y_offset := 0
	for row_index in ROWS.size():
		var x_offset := 0
		for col_index in COLS.size():
			var tile := grid[row_index][col_index] as Image
			if tile.get_format() != Image.FORMAT_RGBA8:
				tile.convert(Image.FORMAT_RGBA8)
			composed.blit_rect(tile, Rect2i(0, 0, tile.get_width(), tile.get_height()), Vector2i(x_offset, y_offset))
			x_offset += col_widths[col_index]
		y_offset += row_heights[row_index]

	var texture_rect := TextureRect.new()
	texture_rect.texture = ImageTexture.create_from_image(composed)
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture_rect


static func _load_tile(asset_manager, row: String, col: String) -> Image:
	var relative_path := "%s/%s_%s_%s_loading.tga" % [TILE_DIR, WIDTH_CLASS, row, col]
	var resolved: Dictionary = asset_manager.resolve_asset(relative_path)
	if not bool(resolved.get("found", false)):
		return null
	var image := Image.new()
	if image.load(str(resolved.get("resolved_path", ""))) != OK:
		return null
	return image
