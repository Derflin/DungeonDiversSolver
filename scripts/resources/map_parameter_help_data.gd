class_name MapParameterHelpData
extends Resource


@export_group("Display", "display_")
## Title shown in the header of the associated parameter help panel.
@export var display_name: String = ""
## Static icon shown beside the title of the associated help panel.
@export var display_icon: Texture2D

@export_group("Help", "help_")
## Ordered content blocks used to build the parameter help description.
@export var help_blocks: Array[RoomSecretHelpBlock] = []


## Returns whether at least one assigned help block contains displayable content.
func has_help_content() -> bool:
	# Check every configured block for content supported by the help renderer.
	for block: RoomSecretHelpBlock in help_blocks:
		if block != null and block.has_renderable_content():
			return true
	
	return false
