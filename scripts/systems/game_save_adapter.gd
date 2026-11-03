class_name GameSaveAdapter
extends Node


var _save_providers: Dictionary[StringName, Object] = {}


func _ready() -> void:
	# Register save providers.
	register_save_provider(GameSettings)
	register_save_provider(GameState)
	
	# Register game save adapter inside the save manager.
	SaveManager.register_game_save_adapter(self)


func _exit_tree() -> void:
	# Unregister game save adapter from the save manager.
	SaveManager.unregister_game_save_adapter(self)


func register_save_provider(provider: Object) -> void:
	assert(provider != null)
	assert(provider.has_method("get_save_key"))
	assert(provider.has_method("capture_save_data"))
	assert(provider.has_method("restore_save_data"))
	assert(provider.has_method("capture_save_metadata"))
	
	var save_key: StringName = provider.get_save_key()
	
	assert(not save_key.is_empty())
	assert(not _save_providers.has(save_key))
	
	_save_providers[save_key] = provider


func unregister_save_provider(provider: Object) -> void:
	if provider == null:
		return
	
	var save_key: StringName = provider.get_save_key()
	
	if _save_providers.get(save_key) == provider:
		_save_providers.erase(save_key)


func capture_game_state() -> Dictionary:
	var game_state: Dictionary = {}
	
	for save_key: StringName in _save_providers:
		var provider: Object = _save_providers[save_key]
		
		game_state[save_key] = provider.capture_save_data()
	
	return game_state


func restore_game_state(game_state: Dictionary) -> void:
	# Initialize save restore process for each save provider.
	for save_key: StringName in _save_providers:
		var provider: Object = _save_providers[save_key]
		if provider.has_method("begin_save_restore"):
			provider.begin_save_restore()
	
	# Perform the save restore process for each save provider.
	for save_key: StringName in _save_providers:
		var provider: Object = _save_providers[save_key]
		
		if not game_state.has(save_key):
			push_warning("Save data does not contain provider '%s'." % save_key)
			continue
		
		provider.restore_save_data(game_state[save_key])
	
	# Finish save restore process for each save provider.
	for save_key: StringName in _save_providers:
		var provider: Object = _save_providers[save_key]
		if provider.has_method("finish_save_restore"):
			provider.finish_save_restore()


func capture_save_metadata() -> Array[Dictionary]:
	var save_metadata: Array[Dictionary] = []
	
	for save_key: StringName in _save_providers:
		var provider: Object = _save_providers[save_key]
		
		save_metadata.append_array(provider.capture_save_metadata())
	
	return save_metadata
