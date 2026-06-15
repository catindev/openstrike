extends SceneTree

const PROFILE_PATH := "res://data/config/viewmodel_world_profile.json"
const ASSET_CATALOG_PATH := "res://data/assets/cs16_pilot_weapon_assets.json"
const EPSILON := 0.001

const MovementSettingsRef = preload("res://src/game/movement/cs_movement_settings.gd")
const ConfigLoaderRef = preload("res://src/core/config/config_loader.gd")
const ProfileRef = preload("res://src/core/units/viewmodel_world_profile.gd")
const OpenStrikeAssetManifestRef = preload("res://src/core/assets/asset_manifest.gd")

const DENIED_TRANSFORM_KEYS := [
	"model_scale",
	"model_position",
	"viewmodel_offset",
	"manual_fov",
	"weapon_camera_offset",
	"weapon_specific_transform",
]


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	var profile = ProfileRef.new()
	profile.load_from_file(PROFILE_PATH)

	if not _assert(profile.is_valid(), "viewmodel/world profile should load without diagnostics", profile.to_dictionary()):
		return 1
	if not _run_scale_checks(profile):
		return 1
	if not _run_coordinate_mapping_checks(profile):
		return 1
	if not _run_eye_height_checks(profile):
		return 1
	if not _run_fov_checks(profile):
		return 1
	if not _run_viewmodel_basis_correction_checks(profile):
		return 1
	if not _run_manifest_allowlist_checks():
		return 1
	if not _run_denylist_scan():
		return 1

	print("Viewmodel/world profile smoke passed.")
	return 0


func _run_scale_checks(profile) -> bool:
	var expected := {
		72.0: 1.8,
		64.0: 1.6,
		36.0: 0.9,
		30.0: 0.75,
		18.0: 0.45,
		12.0: 0.3,
	}
	for units in expected.keys():
		if not _assert(abs(profile.scaled_units(float(units)) - float(expected[units])) <= EPSILON, "GoldSrc unit scale should match profile-derived value", {
			"units": units,
			"expected": expected[units],
			"actual": profile.scaled_units(float(units)),
			"profile": profile.to_dictionary(),
		}):
			return false
	return true


func _run_coordinate_mapping_checks(profile) -> bool:
	return (
		_assert(profile.goldsrc_to_godot(Vector3(40.0, 0.0, 0.0)).is_equal_approx(Vector3(-1.0, 0.0, 0.0)), "GoldSrc X axis should map to Godot -X at loader scale", profile.to_dictionary())
		and _assert(profile.goldsrc_to_godot(Vector3(0.0, 40.0, 0.0)).is_equal_approx(Vector3(0.0, 0.0, 1.0)), "GoldSrc Y axis should map to Godot +Z at loader scale", profile.to_dictionary())
		and _assert(profile.goldsrc_to_godot(Vector3(0.0, 0.0, 40.0)).is_equal_approx(Vector3(0.0, 1.0, 0.0)), "GoldSrc Z axis should map to Godot +Y at loader scale", profile.to_dictionary())
		and _assert(abs(profile.mapping_determinant() - 1.0) <= EPSILON, "GoldSrc-to-Godot mapping should preserve orientation with determinant +1", {"determinant": profile.mapping_determinant()})
	)


func _run_eye_height_checks(profile) -> bool:
	var cvars = ConfigLoaderRef.load_default_cvars()
	var settings = MovementSettingsRef.new()
	settings.apply_cvars(cvars)

	var stand_half_hull: float = settings.stand_height * 0.5
	var duck_half_hull: float = settings.duck_height * 0.5
	var stand_eye_units: float = stand_half_hull + profile.view_offset_stand
	var duck_eye_units: float = duck_half_hull + profile.view_offset_duck
	return (
		_assert(abs(stand_eye_units - 64.0) <= EPSILON, "standing effective eye height should be derived from hull plus VEC_VIEW", {"stand_eye_units": stand_eye_units, "settings": settings.to_dictionary(), "profile": profile.to_dictionary()})
		and _assert(abs(duck_eye_units - 30.0) <= EPSILON, "ducked effective eye height should be derived from hull plus VEC_DUCK_VIEW", {"duck_eye_units": duck_eye_units, "settings": settings.to_dictionary(), "profile": profile.to_dictionary()})
		and _assert(abs(profile.scaled_units(stand_eye_units) - 1.6) <= EPSILON, "standing eye height should scale to 1.6 Godot units", profile.to_dictionary())
		and _assert(abs(profile.scaled_units(duck_eye_units) - 0.75) <= EPSILON, "ducked eye height should scale to 0.75 Godot units", profile.to_dictionary())
	)


func _run_fov_checks(profile) -> bool:
	var expected_vertical_fov: float = profile.derive_vertical_fov(90.0, 4.0 / 3.0)
	var horizontal_at_16_9: float = profile.derive_horizontal_fov(expected_vertical_fov, 16.0 / 9.0)
	var wrong_keep_width_vertical: float = profile.derive_vertical_fov(90.0, 16.0 / 9.0)
	var world_camera := Camera3D.new()
	var viewmodel_camera := Camera3D.new()
	profile.apply_to_camera(world_camera)
	profile.apply_to_camera(viewmodel_camera, true)

	var ok := (
		_assert(abs(expected_vertical_fov - 73.739795) <= EPSILON, "vertical FOV should be derived from 90 horizontal at 4:3", {"expected_vertical_fov": expected_vertical_fov})
		and _assert(abs(horizontal_at_16_9 - 106.260205) <= 0.01, "KEEP_HEIGHT profile should produce Hor+ horizontal FOV at 16:9", {"horizontal_at_16_9": horizontal_at_16_9})
		and _assert(abs(wrong_keep_width_vertical - 58.7155) <= EPSILON, "smoke should recognize the KEEP_WIDTH 16:9 trap value", {"wrong_keep_width_vertical": wrong_keep_width_vertical})
		and _assert(world_camera.keep_aspect == Camera3D.KEEP_HEIGHT, "world camera must use KEEP_HEIGHT", {"keep_aspect": world_camera.keep_aspect})
		and _assert(viewmodel_camera.keep_aspect == Camera3D.KEEP_HEIGHT, "viewmodel camera must use KEEP_HEIGHT", {"keep_aspect": viewmodel_camera.keep_aspect})
		and _assert(abs(world_camera.fov - expected_vertical_fov) <= EPSILON, "world camera fov should use derived vertical FOV", {"camera_fov": world_camera.fov, "expected": expected_vertical_fov})
		and _assert(abs(viewmodel_camera.fov - expected_vertical_fov) <= EPSILON, "viewmodel default fov should match world projection", {"camera_fov": viewmodel_camera.fov, "expected": expected_vertical_fov})
		and _assert(abs(world_camera.fov - wrong_keep_width_vertical) > 1.0, "world camera must not be fed the KEEP_WIDTH trap value", {"camera_fov": world_camera.fov, "wrong_keep_width_vertical": wrong_keep_width_vertical})
	)
	world_camera.free()
	viewmodel_camera.free()
	return ok


func _run_viewmodel_basis_correction_checks(profile) -> bool:
	var correction: Transform3D = profile.viewmodel_basis_correction_transform()
	var basis := correction.basis
	var corrected_forward: Vector3 = basis * Vector3(0.0, 0.0, 1.0)
	var corrected_up: Vector3 = basis * Vector3.UP
	var determinant := basis.determinant()
	return (
		_assert(str(profile.viewmodel_basis_correction) == ProfileRef.VIEWMODEL_BASIS_ROTATE_Y_180, "viewmodel basis correction should record the shared MDL runtime orientation calibration", profile.to_dictionary())
		and _assert(corrected_forward.is_equal_approx(Vector3(0.0, 0.0, -1.0)), "viewmodel basis correction should put goldsrc-godot positive Z in front of Godot cameras", {"corrected_forward": corrected_forward})
		and _assert(corrected_up.is_equal_approx(Vector3.UP), "viewmodel basis correction should preserve up direction", {"corrected_up": corrected_up})
		and _assert(abs(determinant - 1.0) <= EPSILON, "viewmodel basis correction should preserve handedness and scale", {"determinant": determinant})
		and _assert(correction.origin.is_equal_approx(Vector3.ZERO), "viewmodel basis correction must not introduce a position offset", {"origin": correction.origin})
	)


func _run_manifest_allowlist_checks() -> bool:
	var manifest = OpenStrikeAssetManifestRef.new()
	manifest.load_from_file(ASSET_CATALOG_PATH)
	if not _assert(manifest.is_valid(), "pilot catalog should satisfy the closed manifest entry allow-list", manifest.to_dictionary()):
		return false

	var bad_manifest = OpenStrikeAssetManifestRef.new()
	bad_manifest.configure_from_dictionary({
		"assets": {
			"weapon.ak47.viewmodel": {
				"type": "view_model",
				"path": "models/v_ak47.mdl",
				"model_scale": 1.5,
			},
		},
	}, "viewmodel_profile_bad_manifest")
	return (
		_assert(not bad_manifest.is_valid(), "manifest should reject per-weapon transform top-level keys", bad_manifest.to_dictionary())
		and _assert(_has_diagnostic(bad_manifest.diagnostics, "asset_reference_unknown_key"), "manifest should report unknown top-level key diagnostics", bad_manifest.to_dictionary())
	)


func _run_denylist_scan() -> bool:
	var roots := [
		"res://data",
		"res://scenes",
		"res://src",
	]
	for root in roots:
		if not _scan_root_for_denied_terms(root):
			return false
	return true


func _scan_root_for_denied_terms(root: String) -> bool:
	var dir := DirAccess.open(root)
	if dir == null:
		return true

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry == "":
			break
		if entry.begins_with("."):
			continue
		var path := root.path_join(entry)
		if dir.current_is_dir():
			if not _scan_root_for_denied_terms(path):
				return false
			continue
		if not _should_scan_file(path):
			continue
		if path == "res://src/dev/smoke/viewmodel_world_profile_smoke.gd":
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var text := file.get_as_text()
		for term in DENIED_TRANSFORM_KEYS:
			if text.find(term) == -1:
				continue
			return _assert(false, "committed data/code must not contain per-weapon transform keys", {
				"path": path,
				"term": term,
			})
	return true


func _should_scan_file(path: String) -> bool:
	var extension := path.get_extension().to_lower()
	return ["gd", "tscn", "tres", "json"].has(extension)


func _has_diagnostic(entries: Array, code: String) -> bool:
	for entry in entries:
		if entry is Dictionary and str(entry.get("code", "")) == code:
			return true
	return false


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
