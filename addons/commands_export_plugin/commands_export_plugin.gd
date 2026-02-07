@tool
@icon("res://addons/project_export_commands/icon.svg")
class_name CommandsExportPlugin
extends ToolEditorExportPlugin

## CommandsExportPlugin
## 
## A plugin using [ToolEditorExportPlugin] to provide the ability for CLI commands to be run during
## export. Requires the NovaTools plugin as a dependency.

## A list of class names that inherit form [EditorExportPlatformExtension]
## but should be supported by this plugin.
const EXTRA_SUPPORTED_CLASSES_NAMES := ["SourceEditorExportPlatform", "VideoEditorExportPlatform"]

func _get_name() -> String:
	return "A"
	#Intentionally chosen to come first when alphabetically sorted with the other export plugins.
	#This must always come first in order for pre and post export commands to run properly.

func _get_export_features(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	return PackedStringArray(["exportcommands"])

func _supports_platform(platform:EditorExportPlatform):
	return ((not platform.is_class("EditorExportPlatformExtension")) or
			EXTRA_SUPPORTED_CLASSES_NAMES.any(func (n): return platform.is_class(n))
		   )

func _get_export_option_visibility(platform: EditorExportPlatform, option: String) -> bool:
	if (not get_option("project_export_commands/run_commands") and
		option.begins_with("project_export_commands/") and
		option != "project_export_commands/run_commands"
	   ):
		return false
	return true

func _get_export_options(platform):
	if not _supports_platform(platform):
		return []
	return [
		{
			"option" : {
				"name" : "project_export_commands/run_commands",
				"type" : TYPE_BOOL,
			},
			"default_value" : false,
		},
		{
			"option" : {
				"name" : "project_export_commands/keep_open",
				"type" : TYPE_BOOL,
			},
			"default_value" : true,
		},
		{
			"option" : {
				"name": "project_export_commands/post_processing_commands",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_TYPE_STRING,
				"hint_string": "%d:%d:"%[TYPE_ARRAY, TYPE_STRING],
			},
			"default_value": []
		},
		{
			"option" : {
				"name": "project_export_commands/pre_processing_commands",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_TYPE_STRING,
				"hint_string": "%d:%d:"%[TYPE_ARRAY, TYPE_STRING],
			},
			"default_value": []
		}
	]

static func _normalize_export_path(path:String) -> String:
	var dir_or_file := ProjectSettings.globalize_path("res://").rstrip("/") + "/" + path.lstrip(".").lstrip("/").get_base_dir()
	return dir_or_file
	

static func _wrap_command(command:String = "", args:Array = [], cwd:String = "") -> String:
	if command.is_empty():
		return ""
	
	var com := ""
	if not cwd.is_empty():
		com += "cd %s &&" % [cwd]
	com += " %s " % [command]
	com += " ".join(args)
	return com.strip_edges()

static func _run_command_list(command_list:Variant = null) -> void:
	if not get_option("project_export_commands/run_commands"):
		return

	var cwd := _normalize_export_path(path)

	for command in command_list:
		var com := _wrap_command(command[0], command.slice(1), cwd)
		var keep_open = get_option("project_export_commands/keep_open")
		await NovaTools.launch_external_command_async(com, [], keep_open)

func _export_begin_tool(features, is_debug, path, flags):
	var cmds = get_option("project_export_commands/pre_processing_commands")
	_run_command_list(cmds)

func _export_end_tool(features, is_debug, path, flags):
	var cmds = get_option("project_export_commands/post_processing_commands")
	_run_command_list(cmds)
