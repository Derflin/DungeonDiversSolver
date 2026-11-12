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
## Frames reserverd for animated illuustrations displayed by ANIMATION block type.
@export var content_media_animation_frames: SpriteFrames
## Optional caption displayed below an illustration for IMAGE and ANIMATION block types.
@export var content_media_caption: String = ""
