class_name RoomSecretHelpBlock
extends Resource


## Available content types used to build each secret room help description.
enum BlockType {
	NONE,
	RULE,
	TIP,
	IMAGE,
	ANIMATION,
}


## Determines how this help block will be rendered.
@export var block_type: BlockType = BlockType.NONE

@export_group("Content", "content_")
## Description text displayed by RULE and TIP block types.
@export_multiline var content_text: String = ""

@export_subgroup("Media", "content_media_")
## Static illustration displayed by IMAGE block type.
@export var content_media_image: Texture2D
## Frames reserved for animated illustrations displayed by ANIMATION block type.
@export var content_media_animation_frames: SpriteFrames
## Optional caption displayed below an illustration for IMAGE and ANIMATION block types.
@export var content_media_caption: String = ""


## Returns whether the block contains data supported by the current help renderer.
func has_renderable_content() -> bool:
	match block_type:
		BlockType.RULE, BlockType.TIP:
			# Ignore text blocks that contain only whitespace.
			return not content_text.strip_edges().is_empty()
			
		BlockType.IMAGE:
			# Static illustration require an assigned texture.
			return content_media_image != null
			
		BlockType.ANIMATION:
			# Animated illustration playback is not available in the current renderer.
			return false
			
		_:
			return false
