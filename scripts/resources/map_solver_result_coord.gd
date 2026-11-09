class_name MapSolverResultCoord
extends RefCounted


var coords: Vector2i = Vector2i(-1, -1)
var calculated_weight: float = -1
var probability: float = 1.0
var priority_group: int = 0
var text_color: Color = Color.WHITE
var placement_explanations: Array[MapSolverPlacementExplanation] = []


func _init(_coords: Vector2i = Vector2i.ZERO, _calculated_weight: float = -1, _probability: float = 1.0) -> void:
	coords = _coords
	calculated_weight = _calculated_weight
	probability = _probability


func add_placement_explanation(explanation: MapSolverPlacementExplanation) -> void:
	placement_explanations.append(explanation)


#region Save Data Serialization
# These functions convert this object's persistent state to and from save data.

## Captures this object's persistent state as serializable save data.
func capture_save_data() -> Dictionary:
	var saved_explanations: Array = []
	for explanation: MapSolverPlacementExplanation in placement_explanations:
		saved_explanations.append(explanation.capture_save_data())
	
	return {
		"coords": coords,
		"calculated_weight": calculated_weight,
		"probability": probability,
		"priority_group": priority_group,
		"text_color": text_color,
		"placement_explanations": saved_explanations,
	}

## Restores this object's persistent state from previously captured save data.
func restore_save_data(data: Dictionary) -> void:
	coords = data["coords"]
	calculated_weight = data["calculated_weight"]
	probability = data["probability"]
	priority_group = data.get("priority_group", 0)
	text_color = data["text_color"]
	
	placement_explanations.clear()
	for saved_explanation in data.get("placement_explanations", []):
		var explanation := MapSolverPlacementExplanation.new()
		explanation.restore_save_data(saved_explanation)
		placement_explanations.append(explanation)

#endregion
