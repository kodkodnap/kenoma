class_name SignalArt
extends RefCounted
## Imagen original de cada señal, generada en runtime (sin assets externos).

const SIZE := 64


static func texture_for(def: SignalDef) -> ImageTexture:
	var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	if def == null:
		return ImageTexture.create_from_image(image)
	var rng := RandomNumberGenerator.new()
	rng.seed = def.image_seed
	for y in SIZE:
		for x in SIZE:
			var wave := 0.5 + 0.5 * sin(float(x) * 0.31 + float(y) * 0.17 + float(def.image_seed))
			var value := clampf(wave * 0.65 + rng.randf() * 0.35, 0.0, 1.0)
			var color := Color(0.08 + 0.55 * value, 0.16 + 0.7 * value, 0.28 + 0.5 * value)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
