class_name Economy
extends RefCounted
## Puntos, tienda y pedidos del dron. Los créditos viven en SignalSystem
## (ventas de discos) y se pasan aquí al comprar.

signal points_changed(points: int)
signal purchase_failed(reason: String)

var points: int = 0
var orders: Array[Dictionary] = []
var store: Array[Dictionary] = []
var log: Array[String] = []
var last_bonus_week: int = 0


static func load_store(path: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("No se pudo abrir la tienda: " + path)
		return out
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		push_error("Tienda inválida: " + path)
		return out
	for entry in parsed:
		if entry is Dictionary:
			out.append(entry)
	return out


func setup(items: Array[Dictionary]) -> void:
	store.clear()
	for item in items:
		store.append(item)


func add_points(amount: int) -> void:
	points += amount
	points_changed.emit(points)


func find_item(item_id: String) -> Dictionary:
	for item in store:
		if String(item.get("id", "")) == item_id:
			return item
	return {}


## Devuelve {ok, credits, item, order, reason}. No cobra: calcula los créditos restantes.
func buy(item_id: String, credits: int) -> Dictionary:
	var item := find_item(item_id)
	if item.is_empty():
		return {"ok": false, "credits": credits, "reason": "Artículo desconocido"}
	var price := int(item.get("price", 0))
	if credits < price:
		purchase_failed.emit("Créditos insuficientes")
		return {"ok": false, "credits": credits, "reason": "Créditos insuficientes"}
	var order := {
		"id": String(item.get("id", "")),
		"name": String(item.get("name", "Pedido")),
		"price": price,
		"item_path": String(item.get("item_path", "")),
		"delivered": false,
	}
	orders.append(order)
	return {"ok": true, "credits": credits - price, "item": item, "order": order}


func pending_orders() -> int:
	var total := 0
	for order in orders:
		if not bool(order.get("delivered", false)):
			total += 1
	return total


func deliver_orders() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for order in orders:
		if not bool(order.get("delivered", false)):
			order["delivered"] = true
			out.append(order)
	return out


func pending_list() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for order in orders:
		if not bool(order.get("delivered", false)):
			out.append(order)
	return out


## Bonus semanal: 100 puntos por semana, una sola vez por semana.
func weekly_bonus(week: int) -> int:
	if week <= 0 or week <= last_bonus_week:
		return 0
	last_bonus_week = week
	add_points(100 * week)
	return 100 * week
