extends RefCounted

class_name OpenStrikeBspReaderDiagnostic

const SEVERITY_ERROR := "error"
const SEVERITY_WARNING := "warning"

var severity := SEVERITY_ERROR
var code := ""
var lump := ""
var field := ""
var message := ""
var expected = null
var actual = null


func configure(
	diagnostic_severity: String,
	diagnostic_code: String,
	diagnostic_lump: String,
	diagnostic_field: String,
	diagnostic_message: String,
	diagnostic_expected = null,
	diagnostic_actual = null
) -> void:
	severity = diagnostic_severity
	code = diagnostic_code
	lump = diagnostic_lump
	field = diagnostic_field
	message = diagnostic_message
	expected = diagnostic_expected
	actual = diagnostic_actual


func is_error() -> bool:
	return severity == SEVERITY_ERROR


func to_dictionary() -> Dictionary:
	return {
		"severity": severity,
		"code": code,
		"lump": lump,
		"field": field,
		"message": message,
		"expected": expected,
		"actual": actual,
	}
