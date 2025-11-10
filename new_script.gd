extends Node2D
class_name LifeRoguelike

@export var cols: int = 20
@export var rows: int = 14
@export var cell_px: int = 28

@export var birth_score: int = 1
@export var draw_grid: bool = true
@export var step_interval_sec: float = 0.0

var gene_pool: Array[String] = [
	"vanilla","vanilla","vanilla","vanilla","vanilla","vanilla","photosyn"
]

const SPECIAL_COLORS := {
	"photosyn": Color(0.2, 0.85, 0.35),
	"explode":  Color(0.95, 0.35, 0.2),
	"guardian": Color(0.35, 0.65, 0.95),
	"copy":     Color(0.9, 0.8, 0.2),
}

var alive: Array
var kind: Array
var next_alive: Array
var next_kind: Array
var age: Array

var rng := RandomNumberGenerator.new()
var score: int = 0
var turn: int = 0

var birth_list: Array[Vector2i] = []
var death_list: Array[Vector2i] = []
var kill_queue: Array[Vector2i] = []

signal stepped(turn: int, gained_score: int, total_score: int)
signal gene_pool_changed(new_pool: Array)

func _ready() -> void:
	rng.randomize()
	_init_arrays()
	seed_random_board(0.18)
	queue_redraw()

var _timer_accum := 0.0
func _process(delta: float) -> void:
	if step_interval_sec > 0.0:
		_timer_accum += delta
		if _timer_accum >= step_interval_sec:
			_timer_accum = 0.0
			do_step()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		do_step()
	if event.is_action_pressed("ui_cancel"):
		reset_board()

# ===== ユーティリティ =====
func duplicate_gene(key: String) -> void:
	if key == "vanilla" or SPECIAL_COLORS.has(key):
		gene_pool.append(key)
		emit_signal("gene_pool_changed", gene_pool)

func remove_gene(key: String) -> void:
	var idx := gene_pool.find(key)
	if idx != -1:
		gene_pool.remove_at(idx)
		emit_signal("gene_pool_changed", gene_pool)

func set_gene_pool(new_pool: Array[String]) -> void:
	gene_pool = new_pool.duplicate()
	emit_signal("gene_pool_changed", gene_pool)

# ===== 初期化 =====
func _init_arrays() -> void:
	alive = []
	kind = []
	age = []
	next_alive = []
	next_kind = []
	for x in range(cols):
		alive.append([])
		kind.append([])
		age.append([])
		next_alive.append([])
		next_kind.append([])
		for y in range(rows):
			alive[x].append(false)
			kind[x].append("vanilla")
			age[x].append(0)
			next_alive[x].append(false)
			next_kind[x].append("vanilla")

func seed_random_board(fill_ratio: float = 0.2) -> void:
	for x in range(cols):
		for y in range(rows):
			var a := rng.randf() < fill_ratio
			alive[x][y] = a
			age[x][y] = 1 if a else 0
			kind[x][y] = "vanilla"
	score = 0
	turn = 0
	queue_redraw()

func reset_board() -> void:
	_init_arrays()
	seed_random_board(0.18)
	queue_redraw()

# ===== 進行 =====
func do_step() -> void:
	turn += 1
	var gained := _advance_generation()
	score += gained
	emit_signal("stepped", turn, gained, score)
	queue_redraw()

func _advance_generation() -> int:
	birth_list.clear()
	death_list.clear()
	kill_queue.clear()
	var gained_score := 0

	# 次世代の決定（通常のライフゲーム規則）
	for x in range(cols):
		for y in range(rows):
			var n := _alive_neighbors(x, y)
			if alive[x][y]:
				next_alive[x][y] = (n == 2 or n == 3)
				next_kind[x][y] = kind[x][y]
			else:
				if n == 3:
					next_alive[x][y] = true
					next_kind[x][y] = _draw_gene()
					birth_list.append(Vector2i(x, y))
				else:
					next_alive[x][y] = false
					next_kind[x][y] = "vanilla"

	# 誕生フック＋出生スコア
	for v in birth_list:
		gained_score += birth_score
		gained_score += _on_birth(next_kind[v.x][v.y], v.x, v.y)

	# 自然死候補
	for x in range(cols):
		for y in range(rows):
			if alive[x][y] and not next_alive[x][y]:
				death_list.append(Vector2i(x, y))

	# 生存フック
	for x in range(cols):
		for y in range(rows):
			if alive[x][y] and next_alive[x][y]:
				gained_score += _on_survive(kind[x][y], x, y)

	# 死亡フック
	for v in death_list:
		gained_score += _on_death(kind[v.x][v.y], v.x, v.y)

	# 強制死亡適用
	for v in kill_queue:
		if is_inside(v.x, v.y):
			next_alive[v.x][v.y] = false

	# 状態確定
	for x in range(cols):
		for y in range(rows):
			var was_alive: bool = alive[x][y]
			var now_alive: bool = next_alive[x][y]
			alive[x][y] = now_alive
			if now_alive:
				kind[x][y] = next_kind[x][y]
				age[x][y] = (age[x][y] + 1) if was_alive else 1
			else:
				kind[x][y] = "vanilla"
				age[x][y] = 0

	return gained_score

# ===== 補助 =====
func _draw_gene() -> String:
	if gene_pool.is_empty():
		return "vanilla"
	var idx := rng.randi_range(0, gene_pool.size() - 1)
	return String(gene_pool[idx])

func _alive_neighbors(x: int, y: int) -> int:
	var c := 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if is_inside(nx, ny) and alive[nx][ny]:
				c += 1
	return c

func is_inside(x: int, y: int) -> bool:
	return x >= 0 and x < cols and y >= 0 and y < rows

# ===== 特殊効果フック =====
func _on_birth(k: String, x: int, y: int) -> int:
	match k:
		"copy":
			var neigh: Array[Vector2i] = []
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := x + dx
					var ny := y + dy
					if is_inside(nx, ny):
						neigh.append(Vector2i(nx, ny))
			neigh.shuffle()
			for v in neigh:
				if next_alive[v.x][v.y]:
					next_kind[v.x][v.y] = "copy"
					return 1
			return 0
		_:
			return 0

func _on_survive(k: String, x: int, y: int) -> int:
	match k:
		"photosyn":
			return 2
		_:
			return 0

func _on_death(k: String, x: int, y: int) -> int:
	match k:
		"explode":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := x + dx
					var ny := y + dy
					if is_inside(nx, ny):
						kill_queue.append(Vector2i(nx, ny))
			return 3
		"guardian":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := x + dx
					var ny := y + dy
					if is_inside(nx, ny) and not next_alive[nx][ny]:
						next_alive[nx][ny] = true
						return 1
			return 1
		_:
			return 0

# ===== 描画 =====
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(cols * cell_px, rows * cell_px)), Color(0.08, 0.08, 0.1))

	if draw_grid:
		for x in range(cols + 1):
			var p := x * cell_px
			draw_line(Vector2(p, 0), Vector2(p, rows * cell_px), Color(0.18, 0.18, 0.22), 1.0)
		for y in range(rows + 1):
			var p2 := y * cell_px
			draw_line(Vector2(0, p2), Vector2(cols * cell_px, p2), Color(0.18, 0.18, 0.22), 1.0)

	for x in range(cols):
		for y in range(rows):
			if alive[x][y]:
				var k: String = kind[x][y]
				var color := Color(0.92, 0.92, 0.95)
				if SPECIAL_COLORS.has(k):
					color = SPECIAL_COLORS[k]
				var rect := Rect2(x * cell_px + 1, y * cell_px + 1, cell_px - 2, cell_px - 2)
				draw_rect(rect, color)
