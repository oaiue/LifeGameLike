extends Node2D

# ローグライク×ライフゲーム
# Godot 4.x / GDScript

# === 設定パラメータ ===
@export var cols: int = 20
@export var rows: int = 14
@export var initial_fill_rate: float = 0.18
@export var birth_score: int = 1
@export var step_interval_sec: float = 0.0  # >0で自動ステップ

# === 描画設定 ===
@export var cell_size: int = 30
@export var border_width: int = 1

# === 特殊セル色設定 ===
const SPECIAL_COLORS = {
	"vanilla": Color.WHITE,
	"photosyn": Color.GREEN,
	"explode": Color.RED,
	"guardian": Color.BLUE,
	"copy": Color.YELLOW
}

# === 状態変数 ===
var alive: Array[Array] = []         # alive[x][y]: bool
var kind: Array[Array] = []          # kind[x][y]: String
var age: Array[Array] = []           # age[x][y]: int
var next_alive: Array[Array] = []    # 次世代用
var next_kind: Array[Array] = []     # 次世代用

var turn: int = 0
var score: int = 0
var rng: RandomNumberGenerator

# === 遺伝子プール ===
var gene_pool: Array[String] = []

# === 副作用バッファ ===
var kill_queue: Array[Vector2i] = []
var protect_queue: Array[Vector2i] = []
var convert_queue: Array[Dictionary] = []

# === 自動ステップ用タイマー ===
var auto_timer: float = 0.0

# === シグナル ===
signal gene_pool_changed(new_pool: Array[String])
signal score_changed(new_score: int)
signal turn_changed(new_turn: int)

func _ready() -> void:
	rng = RandomNumberGenerator.new()
	rng.randomize()
	
	# 初期遺伝子プール設定
	_setup_initial_gene_pool()
	
	# 盤面初期化
	_initialize_board()
	_reset_game()
	
	print("LifeRoguelike initialized!")
	print("Controls: Enter = Step, Esc = Reset")
	print("Gene pool: ", gene_pool)

func _setup_initial_gene_pool() -> void:
	"""初期遺伝子プールの設定"""
	gene_pool.clear()
	
	# vanilla x6, photosyn x1 の初期構成
	for i in 6:
		gene_pool.append("vanilla")
	gene_pool.append("photosyn")
	
	gene_pool_changed.emit(gene_pool)

func _initialize_board() -> void:
	"""盤面配列の初期化"""
	alive.clear()
	kind.clear()
	age.clear()
	next_alive.clear()
	next_kind.clear()
	
	for x in cols:
		alive.append([])
		kind.append([])
		age.append([])
		next_alive.append([])
		next_kind.append([])
		
		for y in rows:
			alive[x].append(false)
			kind[x].append("vanilla")
			age[x].append(0)
			next_alive[x].append(false)
			next_kind[x].append("vanilla")

func _reset_game() -> void:
	"""ゲームリセット"""
	turn = 0
	score = 0
	
	# 盤面をランダム充填
	for x in cols:
		for y in rows:
			var is_alive: bool = rng.randf() < initial_fill_rate
			alive[x][y] = is_alive
			age[x][y] = 0
			
			if is_alive:
				kind[x][y] = _pick_random_gene()
			else:
				kind[x][y] = "vanilla"
	
	_clear_queues()
	queue_redraw()
	
	turn_changed.emit(turn)
	score_changed.emit(score)

func _input(event: InputEvent) -> void:
	"""入力処理"""
	if event.is_action_pressed("ui_accept"):
		do_step()
	elif event.is_action_pressed("ui_cancel"):
		_reset_game()

func _process(delta: float) -> void:
	"""自動ステップ処理"""
	if step_interval_sec > 0.0:
		auto_timer += delta
		if auto_timer >= step_interval_sec:
			auto_timer = 0.0
			do_step()

func do_step() -> void:
	"""1ステップ実行"""
	_clear_queues()
	_calculate_next_generation()
	_apply_side_effects()
	_apply_next_generation()
	
	turn += 1
	turn_changed.emit(turn)
	score_changed.emit(score)
	queue_redraw()

func _calculate_next_generation() -> void:
	"""次世代計算（標準ライフゲームルール）"""
	var birth_count: int = 0
	
	for x in cols:
		for y in rows:
			var neighbors: int = _count_neighbors(x, y)
			var was_alive: bool = alive[x][y]
			var cell_kind: String = kind[x][y]
			
			# ライフゲームルール適用
			var will_be_alive: bool = false
			
			if was_alive:
				# 生存条件: 2または3近傍
				will_be_alive = (neighbors == 2 or neighbors == 3)
			else:
				# 誕生条件: ちょうど3近傍
				will_be_alive = (neighbors == 3)
			
			next_alive[x][y] = will_be_alive
			
			# 状態変化による処理
			if was_alive and will_be_alive:
				# 生存継続
				next_kind[x][y] = cell_kind
				_on_survive(cell_kind, x, y)
				
			elif not was_alive and will_be_alive:
				# 新規誕生
				var new_kind: String = _pick_random_gene()
				next_kind[x][y] = new_kind
				birth_count += 1
				_on_birth(new_kind, x, y)
				
			elif was_alive and not will_be_alive:
				# 死亡
				next_kind[x][y] = "vanilla"
				_on_death(cell_kind, x, y)
				
			else:
				# 死亡継続
				next_kind[x][y] = "vanilla"
	
	# 出生スコア加算
	score += birth_count * birth_score

func _apply_side_effects() -> void:
	"""副作用バッファの適用"""
	# 強制死滅処理
	for pos in kill_queue:
		if is_inside(pos.x, pos.y):
			next_alive[pos.x][pos.y] = false
			next_kind[pos.x][pos.y] = "vanilla"
	
	# 保護処理（生存に強制変更）
	for pos in protect_queue:
		if is_inside(pos.x, pos.y):
			next_alive[pos.x][pos.y] = true
			if next_kind[pos.x][pos.y] == "vanilla":
				next_kind[pos.x][pos.y] = _pick_random_gene()
	
	# 変換処理
	for conv in convert_queue:
		var pos: Vector2i = conv["pos"]
		var new_kind: String = conv["kind"]
		if is_inside(pos.x, pos.y) and next_alive[pos.x][pos.y]:
			next_kind[pos.x][pos.y] = new_kind

func _apply_next_generation() -> void:
	"""次世代を現在に適用"""
	for x in cols:
		for y in rows:
			alive[x][y] = next_alive[x][y]
			kind[x][y] = next_kind[x][y]
			
			if alive[x][y]:
				age[x][y] += 1
			else:
				age[x][y] = 0

# === 特殊セル効果フック ===

func _on_birth(cell_kind: String, x: int, y: int) -> void:
	"""誕生時フック"""
	match cell_kind:
		"copy":
			# 隣接生存セル1つを自分と同種に変換
			var neighbors = _get_neighbor_positions(x, y)
			var live_neighbors: Array[Vector2i] = []
			
			for pos in neighbors:
				if is_inside(pos.x, pos.y) and next_alive[pos.x][pos.y]:
					live_neighbors.append(pos)
			
			if live_neighbors.size() > 0:
				var target: Vector2i = live_neighbors[rng.randi() % live_neighbors.size()]
				convert_queue.append({"pos": target, "kind": cell_kind})
				score += 1

func _on_survive(cell_kind: String, x: int, y: int) -> void:
	"""生存時フック"""
	match cell_kind:
		"photosyn":
			# 生存ごとに+2点
			score += 2

func _on_death(cell_kind: String, x: int, y: int) -> void:
	"""死亡時フック"""
	match cell_kind:
		"explode":
			# 周囲8マスを強制死滅、+3点
			var neighbors = _get_neighbor_positions(x, y)
			for pos in neighbors:
				kill_queue.append(pos)
			score += 3
			
		"guardian":
			# 隣接1マスを保護、+1点
			var neighbors = _get_neighbor_positions(x, y)
			var dead_neighbors: Array[Vector2i] = []
			
			for pos in neighbors:
				if is_inside(pos.x, pos.y) and not next_alive[pos.x][pos.y]:
					dead_neighbors.append(pos)
			
			if dead_neighbors.size() > 0:
				var target: Vector2i = dead_neighbors[rng.randi() % dead_neighbors.size()]
				protect_queue.append(target)
				score += 1

# === ユーティリティ関数 ===

func _count_neighbors(x: int, y: int) -> int:
	"""8近傍の生存数をカウント"""
	var count: int = 0
	var neighbors = _get_neighbor_positions(x, y)
	
	for pos in neighbors:
		if is_inside(pos.x, pos.y) and alive[pos.x][pos.y]:
			count += 1
	
	return count

func _get_neighbor_positions(x: int, y: int) -> Array[Vector2i]:
	"""8近傍の座標リストを取得"""
	var neighbors: Array[Vector2i] = []
	
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			neighbors.append(Vector2i(x + dx, y + dy))
	
	return neighbors

func is_inside(x: int, y: int) -> bool:
	"""座標が盤面内かチェック"""
	return x >= 0 and x < cols and y >= 0 and y < rows

func _pick_random_gene() -> String:
	"""遺伝子プールからランダム選択"""
	if gene_pool.is_empty():
		return "vanilla"
	return gene_pool[rng.randi() % gene_pool.size()]

func _clear_queues() -> void:
	"""副作用バッファをクリア"""
	kill_queue.clear()
	protect_queue.clear()
	convert_queue.clear()

# === 遺伝子操作API ===

func duplicate_gene(gene_kind: String) -> void:
	"""指定遺伝子を1つ複製"""
	gene_pool.append(gene_kind)
	gene_pool_changed.emit(gene_pool)
	print("Gene duplicated: ", gene_kind, " (pool size: ", gene_pool.size(), ")")

func remove_gene(gene_kind: String) -> void:
	"""指定遺伝子を1つ削除"""
	var index: int = gene_pool.find(gene_kind)
	if index >= 0:
		gene_pool.remove_at(index)
		gene_pool_changed.emit(gene_pool)
		print("Gene removed: ", gene_kind, " (pool size: ", gene_pool.size(), ")")
	else:
		print("Gene not found for removal: ", gene_kind)

func set_gene_pool(new_pool: Array[String]) -> void:
	"""遺伝子プールを置き換え"""
	gene_pool = new_pool.duplicate()
	gene_pool_changed.emit(gene_pool)
	print("Gene pool replaced: ", gene_pool)

func get_gene_pool() -> Array[String]:
	"""現在の遺伝子プールを取得"""
	return gene_pool.duplicate()

# === 描画処理 ===

func _draw() -> void:
	"""盤面描画"""
	var total_width: int = cols * cell_size
	var total_height: int = rows * cell_size
	
	# 背景
	draw_rect(Rect2(0, 0, total_width, total_height), Color.BLACK)
	
	# セル描画
	for x in cols:
		for y in rows:
			var rect = Rect2(
				x * cell_size + border_width,
				y * cell_size + border_width,
				cell_size - border_width * 2,
				cell_size - border_width * 2
			)
			
			if alive[x][y]:
				var cell_kind: String = kind[x][y]
				var color: Color = SPECIAL_COLORS.get(cell_kind, Color.WHITE)
				draw_rect(rect, color)
			else:
				draw_rect(rect, Color.DARK_GRAY)
	
	# グリッド線
	for x in range(cols + 1):
		var start_pos = Vector2(x * cell_size, 0)
		var end_pos = Vector2(x * cell_size, total_height)
		draw_line(start_pos, end_pos, Color.GRAY, border_width)
	
	for y in range(rows + 1):
		var start_pos = Vector2(0, y * cell_size)
		var end_pos = Vector2(total_width, y * cell_size)
		draw_line(start_pos, end_pos, Color.GRAY, border_width)

# === デバッグ・テスト用関数 ===

func get_cell_info(x: int, y: int) -> Dictionary:
	"""指定座標のセル情報を取得"""
	if not is_inside(x, y):
		return {}
	
	return {
		"alive": alive[x][y],
		"kind": kind[x][y],
		"age": age[x][y],
		"neighbors": _count_neighbors(x, y)
	}

func set_cell(x: int, y: int, is_alive: bool, cell_kind: String = "vanilla") -> void:
	"""指定座標にセルを設定（テスト用）"""
	if is_inside(x, y):
		alive[x][y] = is_alive
		kind[x][y] = cell_kind if is_alive else "vanilla"
		age[x][y] = 0
		queue_redraw()

func get_statistics() -> Dictionary:
	"""統計情報を取得"""
	var stats = {
		"turn": turn,
		"score": score,
		"total_alive": 0,
		"by_kind": {}
	}
	
	for x in cols:
		for y in rows:
			if alive[x][y]:
				stats["total_alive"] += 1
				var cell_kind: String = kind[x][y]
				if not stats["by_kind"].has(cell_kind):
					stats["by_kind"][cell_kind] = 0
				stats["by_kind"][cell_kind] += 1
	
	return stats

# === 将来拡張用の設計メモ ===
# 
# 1. 新特殊セル追加テンプレート:
#    - SPECIAL_COLORS に色追加
#    - _on_birth/_on_survive/_on_death の match文に処理追加
#    - 必要に応じて新しいキューを追加
#
# 2. スコア倍率システム:
#    - 連鎖カウンターを追加
#    - _calculate_next_generation で連鎖数計算
#    - スコア計算時に倍率適用
#
# 3. アイテムUI:
#    - CanvasLayer に UI シーン追加
#    - duplicate_gene/remove_gene を UI から呼び出し
#    - ターン終了時にランダム選択肢を表示
#
# 4. セーブシステム:
#    - rng.seed, gene_pool, turn, score を JSON で保存
#    - 盤面状態（alive, kind, age）も保存対象
#    - FileAccess.open で読み書き実装
#
# 5. パフォーマンス最適化:
#    - 大きな盤面では dirty フラグで部分更新
#    - マルチスレッドで次世代計算を並列化
#    - ViewportTexture で描画キャッシュ
