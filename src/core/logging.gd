extends Node

class_name Logger

static func info(msg: String) -> void:
    # Prints informational messages
    print("[INFO] %s" % msg)

static func warn(msg: String) -> void:
    # Prints warning messages
    push_warning("[WARN] %s" % msg)

static func error(msg: String) -> void:
    # Prints error messages
    push_error("[ERROR] %s" % msg)
