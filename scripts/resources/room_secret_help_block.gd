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
## Supports [b], [i], [u], [s], [color=#HEX], [bgcolor=#HEX], [font_size=N], [br] and [hr] formatting tags.
## Horizontal-rule options: [hr width=80% height=1 color=#B99A53 align=center].
## Room references use {operation:catalog:room_id} and are resolved when rendered.
## Operations: room (icon and name), icon (icon only), name (name only).
## Catalogs: secret, special. Room IDs must exist in their corresponding catalogs.
## Example: [u]{name:secret:ROOM_ID}[/u] or {room:special:ROOM_ID}.
@export_multiline var content_text: String = ""
## Enables the display for the title label above the specified text for the RULE and TIP block types.
@export var content_text_title_enabled: bool = true

@export_subgroup("Media", "content_media_")
## Static illustration displayed by IMAGE block type.
@export var content_media_image: Texture2D
## Frames reserved for animated illustrations displayed by ANIMATION block type.
@export var content_media_animation_frames: SpriteFrames
## Name of the SpriteFrames animation played by ANIMATION block type.
@export var content_media_animation_name: StringName = &"default"
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
			# Require an animation that can display at least its initial frame.
			if content_media_animation_frames == null:
				return false
			if not content_media_animation_frames.has_animation(content_media_animation_name):
				return false
			if content_media_animation_frames.get_frame_count(content_media_animation_name) == 0:
				return false
			
			return content_media_animation_frames.get_frame_texture(content_media_animation_name, 0) != null
			
		_:
			return false
