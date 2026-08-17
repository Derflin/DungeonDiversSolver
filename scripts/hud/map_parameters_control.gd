class_name MapParametersControl
extends Control


var _map_parameter_entry = preload("res://scenes/hud/map_parameter_entry.tscn")


@onready var map_grid_settings_container := $DrawerAnchor/DrawerRoot/DrawerPanel/MarginContainer/ScrollContainer/VBoxContainer/MapGridSettingsContainer/VBoxContainer
@onready var map_secret_settings_container := $DrawerAnchor/DrawerRoot/DrawerPanel/MarginContainer/ScrollContainer/VBoxContainer/MapSecretSettingsContainer/VBoxContainer


func _ready() -> void:
	# Initialize static map grid size setting node
	var parameter_entry_map_grid_size := _map_parameter_entry.instantiate()
	
	parameter_entry_map_grid_size.name = "%s_%s" % [
		parameter_entry_map_grid_size.scene_file_path.get_file().get_basename(), 
		"map_grid_size",
	]
	
	map_grid_settings_container.add_child(parameter_entry_map_grid_size)
	
	parameter_entry_map_grid_size.initialize_map_grid_size()
	
	# Initialize dynamic map secret settings nodes
	var secret_room_type_kinds = GameData.room_secret_types.get_all_kinds()
	for secret_room_type_kind in secret_room_type_kinds:
		var secret_room_type_id = GameData.room_secret_types.get_type(secret_room_type_kind).get_id()
		
		var parameter_entry_secret_type_count_max := _map_parameter_entry.instantiate()
		
		parameter_entry_secret_type_count_max.name = "%s_%s_%s" % [
			parameter_entry_secret_type_count_max.scene_file_path.get_file().get_basename(), 
			"count_max",
			secret_room_type_id,
		]
		
		map_secret_settings_container.add_child(parameter_entry_secret_type_count_max)
		
		parameter_entry_secret_type_count_max.initialize_secret_type_count_max(secret_room_type_kind)
