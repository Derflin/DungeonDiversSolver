class_name MapSolverPlacementExplanation
extends RefCounted


## Index of the placement type configuration that produced this explanation.
## This identifies individual entries, even when multiple entries use the same placement type.
var placement_type_index: int = -1

## Used to represent straight connections between map coordinates.
## Each entry contains:
## [br]- [code]"from"[/code]: [code]Vector2i[/code] -> Starting map coordinates.
## [br]- [code]"to"[/code]: [code]Vector2i[/code] -> Ending map coordinates.
## [br]- [code]"value"[/code]: [code]float[/code] -> Optional numeric annotation.
## [br]- [code]"show_value"[/code]: [code]bool[/code] -> Whether the numeric annotation is displayed.
## [br]= [code]"highlight_rooms"[/code]: [code]bool[/code] -> Whether to highlight existing rooms along this straight segment.
## [br]- [code]"highlight_to_room"[/code]: [code]bool[/code] -> Whether the room at the [code]"to"[/code] coordinates should be highlighted.
## [br]- [code]"fallback_room_coords"[/code]: [code]Vector2i[/code] -> Map coordinates for which the numeric annotation would be displayed if it fails to be displayed over the default placement over line.
var segments: Array[Dictionary] = []

## Used to represent ordered routes connecting map coordinates.
## Each entry contains:
## [br]- [code]"coords"[/code]: [code]Array[Vector2i][/code] -> Ordered map coordinates.
## [br]- [code]"value"[/code]: [code]float[/code] -> Optional numeric annotation.
## [br]- [code]"show_value"[/code]: [code]bool[/code] -> Whether the numeric annotation is displayed.
var paths: Array[Dictionary] = []

## Used to represent numerical values associated with individual map coordinates.
## Each entry contains:
## [br]- [code]"coords"[/code]: [code]Vector2i[/code] -> Map coordinates.
## [br]- [code]"value"[/code]: [code]float[/code] -> Associated numerical value.
var room_values: Array[Dictionary] = []


## Checks and returns bool value indicating if there is any visual data that could be displayed for the placement explanation.
func has_visuals() -> bool:
	return not segments.is_empty() or not paths.is_empty() or not room_values.is_empty()


#region Save Data Serialization
# These functions convert this object's persistent state to and from save data.

## Captures this object's persistent state as serializable save data.
func capture_save_data() -> Dictionary:
	return {
		"placement_type_index": placement_type_index,
		"segments": segments.duplicate(true),
		"paths": paths.duplicate(true),
		"room_values": room_values.duplicate(true),
	}

## Restores this object's persistent state from previously captured save data.
func restore_save_data(data: Dictionary) -> void:
	placement_type_index = int(data.get("placement_type_index", -1))
	
	segments.clear()
	for entry in data.get("segments", []):
		segments.append((entry as Dictionary).duplicate(true))
	
	paths.clear()
	for entry in data.get("paths", []):
		paths.append((entry as Dictionary).duplicate(true))
	
	room_values.clear()
	for entry in data.get("room_values", []):
		room_values.append((entry as Dictionary).duplicate(true))

#endregion
