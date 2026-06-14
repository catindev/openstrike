extends SceneTree

const MATRIX_PATH := "res://gen/coverage_status_matrix.json"
const SCHEMA_PATH := "res://data/schemas/coverage_status.schema.json"
const GENERATOR_PATH := "res://gen/generate.py"

const VALUE_VERIFIED_CONFIDENCE := ["local_verified", "synthetic_verified"]
const VALUE_VERIFIED_ALLOWED_STAGES := ["parsed", "semantic_mapped", "orchestration_ready"]
const HUMAN_ORIGIN_CONFIDENCE := ["hand_seeded", "manual_unverified"]
const HUMAN_ORIGIN_ALLOWED_STAGES := ["semantic_mapped", "orchestration_ready"]


func _init() -> void:
	var exit_code := _run()
	quit(exit_code)


func _run() -> int:
	if not _run_generator_check():
		return 1

	var matrix := _load_json(MATRIX_PATH)
	if matrix.is_empty():
		return 1
	var schema := _load_json(SCHEMA_PATH)
	if schema.is_empty():
		return 1

	if not _validate_matrix_pairs_against_schema(matrix, schema):
		return 1
	if not _validate_fixture_pairs_against_schema(schema):
		return 1
	if not _validate_invariants_directly(matrix, schema):
		return 1

	print("Coverage status smoke passed.")
	return 0


func _run_generator_check() -> bool:
	var output: Array = []
	var generator_path := ProjectSettings.globalize_path(GENERATOR_PATH)
	var exit_code := OS.execute("python3", PackedStringArray([generator_path, "--check"]), output, true)
	if exit_code == 0:
		return true
	return _assert(false, "coverage status generated artifacts should be up to date", {
		"exit_code": exit_code,
		"output": output,
	})


func _load_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open JSON file: %s" % path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("JSON file must be an object: %s" % path)
		return {}
	return parsed


func _validate_matrix_pairs_against_schema(matrix: Dictionary, schema: Dictionary) -> bool:
	var stages := _string_array(matrix.get("stages", []))
	var allowed = matrix.get("allowed", {})
	if not allowed is Dictionary:
		return _assert(false, "coverage status matrix allowed field must be a dictionary", matrix)

	for stage in stages:
		var allowed_confidence := _string_array((allowed as Dictionary).get(stage, []))
		for confidence in allowed_confidence:
			if not _assert(_schema_allows(schema, stage, confidence), "matrix pair must be allowed by generated schema", {
				"stage": stage,
				"confidence": confidence,
			}):
				return false

	return true


func _validate_fixture_pairs_against_schema(schema: Dictionary) -> bool:
	var valid_pairs: Array[Dictionary] = [
		{"stage": "unknown", "confidence": "none"},
		{"stage": "source_missing", "confidence": "local_verified_absence"},
		{"stage": "source_found", "confidence": "unverified_read"},
		{"stage": "parsed", "confidence": "local_verified"},
		{"stage": "semantic_mapped", "confidence": "hand_seeded"},
		{"stage": "orchestration_ready", "confidence": "manual_unverified"},
		{"stage": "blocked", "confidence": "unverified_read"},
	]
	for pair in valid_pairs:
		if not _assert(_schema_allows(schema, str(pair["stage"]), str(pair["confidence"])), "fixture pair should validate", pair):
			return false

	var invalid_pairs: Array[Dictionary] = [
		{"stage": "unknown", "confidence": "hand_seeded"},
		{"stage": "source_missing", "confidence": "local_verified"},
		{"stage": "source_missing", "confidence": "unverified_read"},
		{"stage": "source_found", "confidence": "local_verified"},
		{"stage": "source_found", "confidence": "hand_seeded"},
		{"stage": "parsed", "confidence": "manual_unverified"},
		{"stage": "orchestration_ready", "confidence": "local_verified_absence"},
	]
	for pair in invalid_pairs:
		if not _assert(not _schema_allows(schema, str(pair["stage"]), str(pair["confidence"])), "fixture pair should be rejected", pair):
			return false

	return true


func _validate_invariants_directly(matrix: Dictionary, schema: Dictionary) -> bool:
	var stages := _string_array(matrix.get("stages", []))

	for confidence in VALUE_VERIFIED_CONFIDENCE:
		for stage in stages:
			if _schema_allows(schema, stage, confidence) and not VALUE_VERIFIED_ALLOWED_STAGES.has(stage):
				return _assert(false, "verified confidence must not be allowed before parsed/intent stages", {
					"stage": stage,
					"confidence": confidence,
				})

	for stage in stages:
		if _schema_allows(schema, stage, "local_verified_absence") and stage != "source_missing":
			return _assert(false, "verified absence must only be allowed on source_missing", {
				"stage": stage,
				"confidence": "local_verified_absence",
			})

	for confidence in HUMAN_ORIGIN_CONFIDENCE:
		for stage in stages:
			if _schema_allows(schema, stage, confidence) and not HUMAN_ORIGIN_ALLOWED_STAGES.has(stage):
				return _assert(false, "human-origin confidence must only be allowed on intent stages", {
					"stage": stage,
					"confidence": confidence,
				})

	return true


func _schema_allows(schema: Dictionary, stage: String, confidence: String) -> bool:
	var properties = schema.get("properties", {})
	if not properties is Dictionary:
		return false

	var stage_property = (properties as Dictionary).get("stage", {})
	var confidence_property = (properties as Dictionary).get("confidence", {})
	if not stage_property is Dictionary or not confidence_property is Dictionary:
		return false

	if not _string_array((stage_property as Dictionary).get("enum", [])).has(stage):
		return false
	if not _string_array((confidence_property as Dictionary).get("enum", [])).has(confidence):
		return false

	var all_of = schema.get("allOf", [])
	if not all_of is Array:
		return false

	for raw_rule in all_of:
		if not raw_rule is Dictionary:
			continue
		var rule := raw_rule as Dictionary
		var rule_stage := _rule_stage(rule)
		if rule_stage != stage:
			continue
		return _string_array(_rule_confidence_values(rule)).has(confidence)

	return false


func _rule_stage(rule: Dictionary) -> String:
	var raw_if = rule.get("if", {})
	if not raw_if is Dictionary:
		return ""
	var raw_properties = (raw_if as Dictionary).get("properties", {})
	if not raw_properties is Dictionary:
		return ""
	var raw_stage = (raw_properties as Dictionary).get("stage", {})
	if not raw_stage is Dictionary:
		return ""
	return str((raw_stage as Dictionary).get("const", ""))


func _rule_confidence_values(rule: Dictionary) -> Array:
	var raw_then = rule.get("then", {})
	if not raw_then is Dictionary:
		return []
	var raw_properties = (raw_then as Dictionary).get("properties", {})
	if not raw_properties is Dictionary:
		return []
	var raw_confidence = (raw_properties as Dictionary).get("confidence", {})
	if not raw_confidence is Dictionary:
		return []
	return (raw_confidence as Dictionary).get("enum", [])


func _string_array(value) -> Array[String]:
	var result: Array[String] = []
	if not value is Array:
		return result
	for item in value:
		result.append(str(item))
	return result


func _assert(condition: bool, message: String, context = null) -> bool:
	if condition:
		return true
	push_error("%s: %s" % [message, JSON.stringify(context)])
	return false
