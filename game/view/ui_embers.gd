class_name UiEmbers
extends Control
## The opening's backdrop: the dark of a night, a low glow of fire along
## the bottom of the screen, and sparks rising slowly from it. The glow is
## drawn once a resize; the sparks are CPUParticles2D, no script per frame.
## `strength` 0..1 is how near the fire is (the title has a little, the
## night's cards more).

var strength := 1.0
var _sparks: CPUParticles2D


func _init(p_strength := 1.0) -> void:
	strength = p_strength
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	resized.connect(_on_resized)
	_sparks = CPUParticles2D.new()
	_sparks.amount = int(18 + 30 * strength)
	_sparks.lifetime = 7.0
	_sparks.preprocess = 7.0
	_sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_sparks.direction = Vector2(0, -1)
	_sparks.spread = 18.0
	_sparks.gravity = Vector2(0, -6)
	_sparks.initial_velocity_min = 14.0
	_sparks.initial_velocity_max = 38.0
	_sparks.angular_velocity_min = 0.0
	_sparks.scale_amount_min = 1.5
	_sparks.scale_amount_max = 3.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(Palette.UI_EMBER, 0.0))
	ramp.set_color(1, Color(Palette.UI_EMBER.darkened(0.3), 0.0))
	ramp.add_point(0.12, Color(1.0, 0.72, 0.35, 0.9))
	ramp.add_point(0.6, Color(Palette.UI_EMBER, 0.5))
	_sparks.color_ramp = ramp
	_sparks.local_coords = false
	add_child(_sparks)


func _on_resized() -> void:
	_sparks.position = Vector2(size.x / 2.0, size.y + 6.0)
	_sparks.emission_rect_extents = Vector2(size.x / 2.0, 4.0)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.UI_NIGHT)
	# The glow: a band rising from the bottom edge, strongest at the middle.
	var h := size.y * (0.35 + 0.25 * strength)
	var bottom := size.y
	var cols := 12
	for i in cols:
		var x0 := size.x * i / cols
		var x1 := size.x * (i + 1) / cols
		var m0 := 1.0 - absf((float(i) / cols) - 0.5) * 1.3
		var m1 := 1.0 - absf((float(i + 1) / cols) - 0.5) * 1.3
		var a := 0.32 * strength
		var hot := Color(Palette.UI_EMBER.darkened(0.25), a)
		var cold := Color(Palette.UI_EMBER.darkened(0.25), 0.0)
		draw_polygon(PackedVector2Array([Vector2(x0, bottom - h * m0), Vector2(x1, bottom - h * m1), Vector2(x1, bottom), Vector2(x0, bottom)]),
				PackedColorArray([cold, cold, Color(hot, a * m1), Color(hot, a * m0)]))
	# A darker vignette at the top corners, so the words sit in the light.
	var shade := Color(0, 0, 0, 0.35)
	var none := Color(0, 0, 0, 0)
	draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), Vector2(size.x, size.y * 0.3), Vector2(0, size.y * 0.3)]),
			PackedColorArray([shade, shade, none, none]))
