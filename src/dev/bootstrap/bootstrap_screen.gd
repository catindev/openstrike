extends Control

# Bootstrap screen script that wires diagnostics into the main scene.

@onready var main_label: Label = $Label
@onready var diagnostics_label: Label = $DiagnosticsLabel

func _ready() -> void:
    # Load configuration (placeholder) to demonstrate import.
    var _config := ConfigLoader.load_config()
    # Obtain diagnostics from the utilities.
    var godot_version := Diagnostics.get_godot_version()
    var status := Diagnostics.get_status()
    # Log startup information.
    Logger.info("Bootstrap screen initialised with Godot version %s and diagnostics status %s" % [godot_version, status])
    # Update the main label with version and status.
    if main_label:
        main_label.text = "OpenStrike\n0.1.0-dev\nBootstrap project initialized\nNo Counter-Strike assets are bundled with OpenStrike\nGodot version: %s\nDiagnostics: %s" % [godot_version, status]
    # Update the diagnostics overlay label.
    if diagnostics_label:
        diagnostics_label.text = "Diagnostics: %s (Godot: %s)" % [status, godot_version]
