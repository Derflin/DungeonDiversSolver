class_name HUDLayoutCoordinator
extends Control


## Selects which HUD element keeps its preferred layout when space is limited.
enum LayoutPriority { NONE, SOLVER_MENU, PARAMETERS_DRAWER }


@export_group("Layout Coordination")
@export var layout_priority: LayoutPriority = LayoutPriority.NONE
## Minimum gap between the prioritized control and the other HUD control.
@export_range(0.0, 64.0, 1.0) var layout_spacing: float = 0.0

@export_group("HUD Controls")
@export var map_solver_control: MapSolverControl
@export var map_parameters_control: MapParametersControl


#region Initialization

func _ready() -> void:
	# Link the layout notifications without creating direct references between hud controls.
	if not is_instance_valid(map_solver_control) or not is_instance_valid(map_parameters_control):
		push_warning("HUDLayoutCoordinator: Assign the MapSolverControl and MapParametesControl controls instances in the inspector.")
		return
	
	map_solver_control.menu_layout_changed.connect(_on_solver_menu_layout_changed)
	map_parameters_control.drawer_layout_changed.connect(_on_drawer_layout_changed)
	
	# Apply the configured priority after both HUD components complete initialization.
	call_deferred("_apply_layout_priority")

#endregion


#region Layout Coordination

## Applies a single layout priority without allowing reciprocal layout dependencies.
func _apply_layout_priority() -> void:
	if not is_instance_valid(map_solver_control) or not is_instance_valid(map_parameters_control):
		return
	
	match layout_priority:
		LayoutPriority.SOLVER_MENU:
			# Solver uses its normal centered width, while drawer yields vertical space.
			map_solver_control.set_layout_reserved_side_width(0.0)
			map_parameters_control.set_layout_reserved_top_height(
				map_solver_control.get_menu_reserved_bottom() + layout_spacing
			)
			
		LayoutPriority.PARAMETERS_DRAWER:
			# Drawer keeps its normal vertical space, while solver yields centered width.
			map_parameters_control.set_layout_reserved_top_height(0.0)
			map_solver_control.set_layout_reserved_side_width(
				map_parameters_control.get_collapsed_drawer_width() + layout_spacing
			)
			
		LayoutPriority.NONE:
			map_solver_control.set_layout_reserved_side_width(0.0)
			map_parameters_control.set_layout_reserved_top_height(0.0)


## Updates the drawer only when the solver menu controls the layout priority.
func _on_solver_menu_layout_changed() -> void:
	if layout_priority == LayoutPriority.SOLVER_MENU:
		_apply_layout_priority()


## Updates the solver menu only when the parameters drawer controls the priority.
func _on_drawer_layout_changed() -> void:
	if layout_priority == LayoutPriority.PARAMETERS_DRAWER:
		_apply_layout_priority()

#endregion
