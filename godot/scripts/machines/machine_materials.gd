class_name MachineMaterials
extends RefCounted
## Materiales de las máquinas de la estación. Todo generado en runtime: sin assets externos.
##
## Pintura desgastada, acero cepillado, baquelita, goma, vidrio, chapa de aviso y escalas
## impresas (perillas y vúmetro). Las texturas se cachean por clave: se generan una vez.

static var _cache: Dictionary = {}

## Chapa pintada del chasis, beige industrial.
static func body() -> StandardMaterial3D:
	return _cached("body", func() -> StandardMaterial3D:
		var mat := _paint(Color(0.5, 0.47, 0.39), 11, 0.65)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.7, 0.7, 0.7)
		return mat)


## Chapa pintada de los paneles de frente, verde oliva apagado.
static func panel() -> StandardMaterial3D:
	return _cached("panel", func() -> StandardMaterial3D:
		var mat := _paint(Color(0.2, 0.22, 0.19), 23, 0.75)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(0.9, 0.9, 0.9)
		return mat)


## Plástico oscuro de frente de instrumentos y cubiertas.
static func dark_panel() -> StandardMaterial3D:
	return _cached("dark_panel", func() -> StandardMaterial3D:
		var mat := _paint(Color(0.075, 0.08, 0.075), 31, 0.35)
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(1.4, 1.4, 1.4)
		return mat)


## Goma de la cubierta de controles.
static func deck() -> StandardMaterial3D:
	return _cached("deck", func() -> StandardMaterial3D:
		var mat := _paint(Color(0.055, 0.06, 0.055), 47, 0.2)
		mat.roughness = 0.94
		mat.metallic = 0.0
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(2.2, 2.2, 2.2)
		return mat)


## Acero cepillado claro.
static func steel() -> StandardMaterial3D:
	return _cached("steel", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.66, 0.67, 0.64)
		mat.albedo_texture = _brushed_texture(0.66, 0.67, 0.64, 3)
		mat.metallic = 0.72
		mat.roughness = 0.42
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(1.6, 1.6, 1.6)
		return mat)


## Acero oscuro de herrajes, bisagras y culatas.
static func dark_steel() -> StandardMaterial3D:
	return _cached("dark_steel", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.16, 0.17, 0.18)
		mat.albedo_texture = _brushed_texture(0.15, 0.16, 0.17, 5)
		mat.metallic = 0.6
		mat.roughness = 0.55
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3(1.8, 1.8, 1.8)
		return mat)


## Baquelita de perillas y mangos.
static func bakelite() -> StandardMaterial3D:
	return _cached("bakelite", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.095)
		mat.roughness = 0.38
		mat.metallic = 0.0
		return mat)


## Baquelita con estrías: se ve girar la perilla al girarla.
static func knurled() -> StandardMaterial3D:
	return _cached("knurled", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.13, 0.13, 0.12)
		mat.albedo_texture = _knurl_texture()
		mat.roughness = 0.44
		mat.metallic = 0.05
		return mat)


## Placas grabadas y chapa clara.
static func cream() -> StandardMaterial3D:
	return _cached("cream", func() -> StandardMaterial3D:
		var mat := _paint(Color(0.76, 0.73, 0.6), 59, 0.8)
		mat.roughness = 0.72
		mat.metallic = 0.0
		return mat)


## Goma roja de mando: mangos de palanca y remates de seguridad.
static func red_grip() -> StandardMaterial3D:
	return _cached("red_grip", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.4, 0.085, 0.055)
		mat.roughness = 0.58
		mat.metallic = 0.0
		return mat)


## Goma negra mate: mangos, patas, guardas.
static func rubber() -> StandardMaterial3D:
	return _cached("rubber", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.045, 0.045, 0.045)
		mat.roughness = 0.97
		mat.metallic = 0.0
		return mat)


## Chapa de aviso a rayas.
static func warning() -> StandardMaterial3D:
	return _cached("warning", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = _warning_texture()
		mat.roughness = 0.7
		mat.metallic = 0.0
		return mat)


## Pequeños LEDs. Se devuelve un material nuevo por llamada: la emisión cambia en juego.
static func led(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color.darkened(0.55)
	mat.roughness = 0.25
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.4
	return mat


## Puntero iluminado de perillas: plástico blanco que se lee en penumbra.
static func pointer() -> StandardMaterial3D:
	return _cached("pointer", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.86, 0.86, 0.8)
		mat.roughness = 0.35
		mat.emission_enabled = true
		mat.emission = Color(0.32, 0.33, 0.3)
		mat.emission_energy_multiplier = 0.35
		return mat)


## Reflejo de vidrio sobre la pantalla: apenas un velo diagonal.
static func glass() -> StandardMaterial3D:
	return _cached("glass", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = _glass_texture()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return mat)


## Líneas de barrido y viñeta para superponer al CRT.
static func scanlines() -> StandardMaterial3D:
	return _cached("scanlines", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = _scanline_texture()
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return mat)


## Escala del vúmetro: fondo crema con arco, marcas y zona roja.
static func vu_dial() -> StandardMaterial3D:
	return _cached("vu_dial", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_texture = _vu_texture()
		return mat)


static func _cached(key: String, factory: Callable) -> StandardMaterial3D:
	if not _cache.has(key):
		_cache[key] = factory.call()
	return _cache[key] as StandardMaterial3D


static func _paint(base: Color, seed_value: int, grime: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = base
	mat.albedo_texture = _paint_texture(base, seed_value, grime)
	mat.roughness = 0.74
	mat.metallic = 0.12
	return mat


# --- Texturas ------------------------------------------------------------------

static func _paint_texture(base: Color, seed_value: int, grime: float) -> ImageTexture:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var blotch := FastNoiseLite.new()
	blotch.seed = seed_value
	blotch.frequency = 0.014
	blotch.fractal_octaves = 4
	var grain := FastNoiseLite.new()
	grain.seed = seed_value + 91
	grain.frequency = 0.42
	for y in size:
		for x in size:
			var big := 0.5 + 0.5 * blotch.get_noise_2d(float(x), float(y))
			var dust := 0.5 + 0.5 * grain.get_noise_2d(float(x), float(y))
			var shade := 0.84 + 0.22 * big + 0.07 * dust
			var low := smoothstep(0.45, 1.0, float(y) / float(size))
			shade *= 1.0 - grime * 0.3 * low
			image.set_pixel(x, y, Color(base.r * shade, base.g * shade, base.b * shade, 1.0))
	_scratches(image, seed_value, 34)
	_chips(image, seed_value, 18)
	return ImageTexture.create_from_image(image)


static func _scratches(image: Image, seed_value: int, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7 + 1
	var size := image.get_width()
	for i in count:
		var from := Vector2(rng.randf() * size, rng.randf() * size)
		var length := rng.randf_range(6.0, 42.0)
		var angle := rng.randf() * TAU
		var scratch := image.get_pixel(int(from.x) % size, int(from.y) % size).lightened(0.16)
		_draw_line(image, from, from + Vector2(cos(angle), sin(angle)) * length,
			Color(scratch.r, scratch.g, scratch.b, 1.0), 1)


static func _chips(image: Image, seed_value: int, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 13 + 5
	var size := image.get_width()
	for i in count:
		var center := Vector2(rng.randf() * size, rng.randf() * size)
		var radius := rng.randf_range(1.5, 5.0)
		for y in range(maxi(0, int(center.y - radius)), mini(size, int(center.y + radius) + 1)):
			for x in range(maxi(0, int(center.x - radius)), mini(size, int(center.x + radius) + 1)):
				if Vector2(x, y).distance_to(center) <= radius:
					var under := image.get_pixel(x, y).darkened(0.32)
					image.set_pixel(x, y, Color(under.r, under.g, under.b, 1.0))


static func _brushed_texture(r: float, g: float, b: float, seed_value: int) -> ImageTexture:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var streak := FastNoiseLite.new()
	streak.seed = seed_value
	streak.frequency = 0.02
	for y in size:
		for x in size:
			var fine := 0.5 + 0.5 * streak.get_noise_2d(float(x) * 6.0, float(y) * 0.6)
			var shade := 0.82 + 0.3 * fine
			image.set_pixel(x, y, Color(r * shade, g * shade, b * shade, 1.0))
	return ImageTexture.create_from_image(image)


static func _knurl_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for x in size:
		var ridge := 0.5 + 0.5 * sin(float(x) / float(size) * TAU * 26.0)
		var shade := 0.55 + 0.55 * ridge
		for y in size:
			var wear := 1.0 - 0.06 * absf(float(y) / float(size) - 0.5)
			image.set_pixel(x, y, Color(0.13 * shade * wear, 0.13 * shade * wear,
				0.125 * shade * wear, 1.0))
	return ImageTexture.create_from_image(image)


static func _warning_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var stripe := int(floor((float(x) + float(y)) / 16.0)) % 2 == 0
			var shade := 0.86 + 0.14 * sin(float(x + y) * 0.3)
			var color := Color(0.82, 0.62, 0.06) if stripe else Color(0.08, 0.08, 0.07)
			image.set_pixel(x, y, Color(color.r * shade, color.g * shade, color.b * shade, 1.0))
	return ImageTexture.create_from_image(image)


static func _glass_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var position := Vector2(x, y)
			var diagonal := position.x + position.y
			var band := smoothstep(float(size) * 0.15, float(size) * 0.55, diagonal)
			band *= 1.0 - smoothstep(float(size) * 1.1, float(size) * 1.7, diagonal)
			var edge := clampf(1.0 - position.distance_to(center) / (float(size) * 0.62), 0.0, 1.0)
			var alpha := 0.015 + 0.06 * band + 0.03 * (1.0 - edge)
			image.set_pixel(x, y, Color(0.5, 0.68, 0.6, clampf(alpha, 0.0, 0.1)))
	return ImageTexture.create_from_image(image)


static func _scanline_texture() -> ImageTexture:
	var size := 128
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size, size) * 0.5
	for y in size:
		for x in size:
			var line_alpha := 0.3 if (y % 3 == 0) else 0.0
			var edge := clampf(
				Vector2(x, y).distance_to(center) / (float(size) * 0.7), 0.0, 1.4)
			var vignette := smoothstep(0.45, 1.2, edge) * 0.5
			var alpha := clampf(line_alpha + vignette, 0.0, 0.62)
			image.set_pixel(x, y, Color(0.0, 0.02, 0.015, alpha))
	return ImageTexture.create_from_image(image)


static func _vu_texture() -> ImageTexture:
	var width := 256
	var height := 160
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			var shade := 0.78 + 0.1 * sin(float(x) * 0.4)
			image.set_pixel(x, y, Color(0.82 * shade, 0.78 * shade, 0.62 * shade, 1.0))
	var center := Vector2(width * 0.5, height * 1.05)
	var radius := height * 0.92
	for i in 21:
		var ratio := float(i) / 20.0
		var angle := lerpf(-1.05, 1.05, ratio) - PI * 0.5
		var direction := Vector2(cos(angle), sin(angle))
		var color := Color(0.12, 0.11, 0.1, 0.95)
		if ratio > 0.8:
			color = Color(0.75, 0.14, 0.1, 1.0)
		_draw_line(image, center + direction * radius * 0.66,
			center + direction * radius * 0.8, color, 3 if i % 5 == 0 else 1)
	_draw_line(image, center + Vector2(-radius * 0.86, -radius * 0.22),
		center + Vector2(radius * 0.86, -radius * 0.22), Color(0.1, 0.1, 0.09, 0.9), 2)
	return ImageTexture.create_from_image(image)


static func _draw_line(image: Image, from: Vector2, to: Vector2, color: Color,
		thickness: int) -> void:
	var size := image.get_width()
	var steps := maxi(2, int(from.distance_to(to) * 2.0))
	for step in steps + 1:
		var point := from.lerp(to, float(step) / float(steps))
		for offset_x in range(-thickness / 2 - 1, thickness / 2 + 2):
			for offset_y in range(-thickness / 2 - 1, thickness / 2 + 2):
				var x := int(round(point.x)) + offset_x
				var y := int(round(point.y)) + offset_y
				if x >= 0 and y >= 0 and x < size and y < image.get_height():
					image.set_pixel(x, y, color)
