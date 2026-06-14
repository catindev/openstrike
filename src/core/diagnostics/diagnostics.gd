extends Node

class_name Diagnostics

static func get_godot_version() -> String:
    # Returns the Godot engine version string.
    var version_info = Engine.get_version_info()
    if version_info is Dictionary:
        if version_info.has("string"):
            return version_info["string"]
        var major = str(version_info.get("major", ""))
        var minor = str(version_info.get("minor", ""))
        var patch = str(version_info.get("patch", ""))
        return "%s.%s.%s" % [major, minor, patch]
    return "unknown"

static func get_status() -> String:
    # Returns a simple diagnostics status. Placeholder for future checks.
    return "OK"
