@tool
@icon("./icon.svg")
extends EditorPlugin

const PLUGIN_NAME := "commands_export_plugin"
const PLUGIN_ICON := preload("./icon.svg")

var _current_inst:CommandsExportPlugin = null

func _get_plugin_icon():
	return PLUGIN_ICON

func _get_plugin_name():
	return PLUGIN_NAME

func _enter_tree():
	_try_init_plugin()

func _enable_plugin():
	_try_init_plugin()

func _disable_plugin():
	_try_deinit_plugin()

func _exit_tree():
	_try_deinit_plugin()

func _try_init_plugin():
	if _current_inst == null:
		_current_inst = CommandsExportPlugin.new()
		add_export_plugin(_current_inst)

func _try_deinit_plugin():
	if _current_inst != null:
		remove_export_plugin(_current_inst)
		_current_inst = null
