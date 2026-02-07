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

const COMMAND_SUBSTITUTION_TYPES:Array[StringName] = ["Export Path", "Export Directory", "Debug or Release", "Space Joined Features", "Comma Joined Features"]

func _get_name() -> String:
	return "A"
	#Intentionally chosen to come first when alphabetically sorted with the other export plugins.
	#This must always come first in order for pre and post export commands to run properly.

func _get_export_features(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	if _supports_platform(platform):
		return PackedStringArray(["exportcommands"])
	return PackedStringArray()

func _supports_platform(platform:EditorExportPlatform):
	if platform.is_class("EditorExportPlatformWeb"):
		# For some reason, web exports have a history of strange bugs with their post exporting methods. This is the temporary solution for this until godot patched this.
		return false

	if platform.is_class("EditorExportPlatformExtension"):
		return EXTRA_SUPPORTED_CLASSES_NAMES.any(func (n): return platform.is_class(n))

	return true

func _get_export_option_visibility(platform: EditorExportPlatform, option: String) -> bool:
	if not _supports_platform(platform):
		return false
	if not get_option("project_export_commands/run_commands"):
		if option.begins_with("project_export_commands/"):
			return option != "project_export_commands/run_commands"
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
			"update_visibility" : true,
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
				"name": "project_export_commands/pre_processing_commands",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_TYPE_STRING,
				"hint_string": "%d:%d/%d"%[TYPE_ARRAY, TYPE_STRING, PROPERTY_HINT_MULTILINE_TEXT],
			},
			"default_value": [["echo", "example"]]
		},
		{
			"option" : {
				"name": "project_export_commands/post_processing_commands",
				"type": TYPE_ARRAY,
				"hint": PROPERTY_HINT_TYPE_STRING,
				"hint_string": "%d:%d/%d"%[TYPE_ARRAY, TYPE_STRING, PROPERTY_HINT_MULTILINE_TEXT],
			},
			"default_value": [["echo", "example"]]
		},
		{
			"option" : {
				"name": "project_export_commands/command_text_substitution",
				"type": TYPE_DICTIONARY,
				"hint": PROPERTY_HINT_TYPE_STRING,
				"hint_string": "%d:;%d/%d:%s" % [TYPE_STRING, TYPE_STRING, PROPERTY_HINT_ENUM, ",".join(COMMAND_SUBSTITUTION_TYPES)],
			},
			"default_value": {"{CWD}" : "Export Directory"}
		}
	]

static func _format_command(command:Variant, subs:Dictionary = {}) -> String:
	var command_parts := []
	match typeof(command):
		TYPE_NIL:
			return ""
		TYPE_ARRAY:
			if command.is_empty():
				return ""
			command_parts = command.map(str)
		TYPE_PACKED_STRING_ARRAY:
			if command.is_empty():
				return ""
			command_parts = Array(command)
		TYPE_STRING, TYPE_STRING_NAME, TYPE_NODE_PATH:
			command = str(command)
			if command.is_empty():
				return ""
			elif " " in command:
				command_parts = Array(command.split(" "))
			else:
				command_parts = [command]
		_:
			push_warning("Export command is bad type: %s. Skipping..." % [type_string(typeof(command))])
			return ""

	command_parts = command_parts.map(func (s): return s.format(subs))

	return " ".join(command_parts).strip_edges()

func _run_command_list(command_list:Variant, features:PackedStringArray, is_debug:bool, path:String, flags:int) -> void:
	if not get_option("project_export_commands/run_commands"):
		return

	var export_path := NovaTools.normalize_path_absolute(path, false)
	var export_dir := NovaTools.normalize_path_absolute(path, false).get_base_dir()

	var subs := {}
	var sub_types = get_option("project_export_commands/command_text_substitution")
	if typeof(sub_types) == TYPE_DICTIONARY:
		for sub in sub_types.keys():
			match (str(sub_types[sub]).to_lower().strip_edges()):
				"export path":
					subs[sub] = export_path
				"export directory":
					subs[sub] = export_dir
				"debug or release":
					subs[sub] = "Debug" if is_debug else "Release"
				"space joined features":
					subs[sub] = " ".join(features)
				"comma joined features":
					subs[sub] = ",".join(features)
				_:
					push_warning("Command substitution type of '%s' not supported." % [sub_types[sub]])

	for command in command_list:
		var com := _format_command(command, subs)
		if com.is_empty():
			continue
		var keep_open = get_option("project_export_commands/keep_open")
		await NovaTools.launch_external_command_async(com, [], keep_open)

func _export_begin_tool(features, is_debug, path, flags):
	var cmds = get_option("project_export_commands/pre_processing_commands")
	_run_command_list(cmds, features, is_debug, path, flags)

func _export_end_tool(features, is_debug, path, flags):
	var cmds = get_option("project_export_commands/post_processing_commands")
	_run_command_list(cmds, features, is_debug, path, flags)
