extends Node2D
class_name LifeRougeLike

@export var cols: int = 20
@export var rows: int = 14
@export var cell_px: int = 28

@export var birth_score: int = 1
@export var draw_grid: bool = true
@export var step_interval_sec: float = 0.0
@export var steps_per_round: int = 10  # 1ラウンドあたりのステップ数
@export var base_target_score: int = 50  # 基本目標スコア
@export var reroll_cost: int = 1  # リロールのコスト
# ショップで使う表示用の情報
const GENE_INFO := {
	"photosyn": {
		"name": "光合成セル",
		"desc": "生存するたびにスコア+2を得る。",
		"cost": 2,
	},
	"guardian": {
		"name": "守護セル",
		"desc": "死亡時に隣接セル1つを救う。スコア+1。",
		"cost": 3,
	},
	"explode": {
		"name": "爆発セル",
		"desc": "死亡時に周囲を巻き込んで倒す。スコア+3。",
		"cost": 4,
	},
	"copy": {
		"name": "コピーセル",
		"desc": "誕生時に隣接セル1つを自分と同じにする。スコア+1。",
		"cost": 3,
	},
}

# アイテム情報（遺伝子ではないアイテム）
const ITEM_INFO := {
	"delete_token": {
		"name": "削除トークン",
		"desc": "遺伝子を1つ削除できるアイテム。",
		"cost": 2,
		"type": "item",
	},
}

# 遺伝子プール：各遺伝子の種類を文字列として保持
# 例：["vanilla", "vanilla", "vanilla", "copy"] → 3/4で無個性、1/4でコピー
var gene_pool: Array[String] = []




signal experience_changed(new_xp: int)  # UI等に通知するためのシグナル

# お金
var gold: int = 10
signal gold_changed(new_gold: int)

# 売り場に並べられる遺伝子の全候補
const GENE_CANDIDATES := [
	"photosyn",
	"guardian",
	"explode",
	"copy",
	# 必要ならここにどんどん追加
]

# 売り場に並べられるアイテムの全候補
const ITEM_CANDIDATES := [
	"delete_token",
	# 必要ならここにどんどん追加
]

# 現在の売り場（常に最大3つを並べる、遺伝子とアイテムが混在）
var shop_genes: Array[String] = []
var purchased_genes_this_round: Array[String] = []  # このラウンドで購入した遺伝子
signal shop_changed(new_shop: Array)

# アイテムボックス（保持しているアイテム）
var item_box: Dictionary = {}  # {"delete_token": 2} のようにアイテム名と個数を保持
signal item_box_changed(new_items: Dictionary)

# 削除トークンが選択されているか
var is_delete_token_selected: bool = false


func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	emit_signal("gold_changed", gold)
	print("[GOLD] +%d → %d" % [amount, gold])

func spend_gold(amount: int) -> bool:
	if amount <= 0:
		return true
	if gold < amount:
		return false
	gold -= amount
	emit_signal("gold_changed", gold)
	return true


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

var level: int =1
const XP_PER_LEVEL := 50
signal stepped(turn: int, gained_score: int, total_score: int)
signal gene_pool_changed(new_pool: Array)

# ラウンド制関連
var round: int = 1
var steps_in_round: int = 0
var round_start_score: int = 0  # ラウンド開始時のスコア
var target_score: int = 0  # 現在のラウンドの目標スコア
var is_game_over: bool = false
signal round_changed(round: int, target_score: int, steps_remaining: int)
signal game_over(round: int, final_score: int)

func _ready() -> void:
	rng.randomize()
	# 遺伝子プールの初期化（デフォルトで6個の無個性遺伝子）
	initialize_gene_pool(6)
	_init_arrays()
	seed_random_board(0.18)
	# ラウンドの初期化
	start_new_round()
	roll_shop()
	# 初期ゴールドを UI に通知
	emit_signal("gold_changed", gold)
	# 初期の遺伝子プール状態を通知（UI が一覧を描画するため）
	emit_signal("gene_pool_changed", gene_pool)
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

func get_gene_info(kind: String) -> Dictionary:
	if GENE_INFO.has(kind):
		return GENE_INFO[kind]
	# アイテムの場合はアイテム情報を返す
	if ITEM_INFO.has(kind):
		return ITEM_INFO[kind]
	# 未定義の遺伝子でも落ちないようにデフォルトを返す
	return {
		"name": kind,
		"desc": "説明は未設定です。",
		"cost": 2,
	}

func get_item_info(item_name: String) -> Dictionary:
	"""アイテム情報を取得"""
	if ITEM_INFO.has(item_name):
		return ITEM_INFO[item_name]
	return {
		"name": item_name,
		"desc": "説明は未設定です。",
		"cost": 2,
		"type": "item",
	}

func is_item(item_name: String) -> bool:
	"""指定された名前がアイテムかどうかを判定"""
	return ITEM_INFO.has(item_name)

func is_gene(item_name: String) -> bool:
	"""指定された名前が遺伝子かどうかを判定"""
	return GENE_INFO.has(item_name) or item_name == "vanilla"


# ===== 遺伝子プール管理関数 =====

# 遺伝子プールを初期化（n個の無個性遺伝子から開始）
func initialize_gene_pool(vanilla_count: int) -> void:
	"""初期化時にn個の無個性遺伝子を設定する"""
	gene_pool.clear()
	for i in range(vanilla_count):
		gene_pool.append("vanilla")
	emit_signal("gene_pool_changed", gene_pool)
	print("[GENE] 遺伝子プールを初期化: 無個性 x%d" % vanilla_count)

# 遺伝子をプールに追加
func add_gene_to_pool(gene_type: String) -> void:
	"""遺伝子をプールに追加する"""
	if gene_type == "vanilla" or SPECIAL_COLORS.has(gene_type):
		gene_pool.append(gene_type)
		emit_signal("gene_pool_changed", gene_pool)
		print("[GENE] 遺伝子を追加: %s (現在の総数: %d)" % [gene_type, gene_pool.size()])
	else:
		push_warning("[GENE] 無効な遺伝子タイプ: %s" % gene_type)

# 遺伝子をプールから削除（最初に見つかったものを1つ削除）
func remove_gene_from_pool(gene_type: String) -> bool:
	"""遺伝子をプールから1つ削除する（見つかった場合）"""
	var idx := gene_pool.find(gene_type)
	if idx != -1:
		gene_pool.remove_at(idx)
		emit_signal("gene_pool_changed", gene_pool)
		print("[GENE] 遺伝子を削除: %s (現在の総数: %d)" % [gene_type, gene_pool.size()])
		return true
	return false

# ===== アイテム関連の関数 =====
func use_delete_token() -> bool:
	"""削除トークンを使用可能にする（選択状態にする）"""
	if item_box.get("delete_token", 0) > 0:
		is_delete_token_selected = true
		print("[ITEM] 削除トークンを選択しました")
		return true
	return false

func cancel_delete_token() -> void:
	"""削除トークンの選択をキャンセル"""
	is_delete_token_selected = false
	print("[ITEM] 削除トークンの選択をキャンセルしました")

func apply_delete_token(gene_type: String) -> bool:
	"""削除トークンを使用して遺伝子を削除"""
	if not is_delete_token_selected:
		return false
	if item_box.get("delete_token", 0) <= 0:
		return false
	
	# 遺伝子を削除
	var success := remove_gene_from_pool(gene_type)
	if success:
		# 削除トークンを消費
		item_box["delete_token"] = item_box.get("delete_token", 0) - 1
		if item_box["delete_token"] <= 0:
			item_box.erase("delete_token")
			is_delete_token_selected = false
		emit_signal("item_box_changed", item_box)
		print("[ITEM] 削除トークンを使用して遺伝子 %s を削除しました" % gene_type)
	return success

# 特定の遺伝子の個数を取得
func get_gene_count(gene_type: String) -> int:
	"""特定の遺伝子の個数を返す"""
	var count := 0
	for g in gene_pool:
		if g == gene_type:
			count += 1
	return count

# 遺伝子プールの総数を取得
func get_total_gene_count() -> int:
	"""遺伝子プールの総数を返す"""
	return gene_pool.size()

# 特定の遺伝子の確率を取得（0.0～1.0）
func get_gene_probability(gene_type: String) -> float:
	"""特定の遺伝子が選ばれる確率を返す（0.0～1.0）"""
	if gene_pool.is_empty():
		return 0.0
	var count := get_gene_count(gene_type)
	return float(count) / float(gene_pool.size())

# 後方互換性のための関数（既存コードとの互換性）
func duplicate_gene(key: String) -> void:
	"""既存コードとの互換性のため（add_gene_to_pool のエイリアス）"""
	add_gene_to_pool(key)

func remove_gene(key: String) -> void:
	"""既存コードとの互換性のため（remove_gene_from_pool のエイリアス）"""
	remove_gene_from_pool(key)

func set_gene_pool(new_pool: Array[String]) -> void:
	"""遺伝子プールを完全に置き換える"""
	gene_pool = new_pool.duplicate()
	emit_signal("gene_pool_changed", gene_pool)
	print("[GENE] 遺伝子プールを設定: 総数 %d" % gene_pool.size())

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
	gold = 10
	round = 1
	steps_in_round = 0
	is_game_over = false
	start_new_round()
	roll_shop()
# ===== ラウンド管理 =====
func start_new_round() -> void:
	"""新しいラウンドを開始する"""
	round_start_score = score
	target_score = base_target_score + (round - 1) * 20  # ラウンドごとに目標スコアを増加
	steps_in_round = 0
	# 購入済み遺伝子の記録は不要（何度でも購入可能）
	emit_signal("round_changed", round, target_score, steps_per_round - steps_in_round)
	print("[ROUND] ラウンド %d 開始 - 目標スコア: %d (現在: %d)" % [round, target_score, score])

func check_round_completion() -> void:
	"""ラウンド終了時の処理"""
	if steps_in_round >= steps_per_round:
		var round_score := score - round_start_score
		if round_score < target_score:
			# ゲームオーバー
			is_game_over = true
			emit_signal("game_over", round, score)
			print("[GAME OVER] ラウンド %d で目標スコア未達成 (目標: %d, 獲得: %d)" % [round, target_score, round_score])
		else:
			# 次のラウンドへ
			# ラウンド終了時にスコアを0にリセット
			score = 0
			round += 1
			start_new_round()
			# ステップごとにリロールするため、ここでのリロールは不要

# ===== 進行 =====
func do_step() -> void:
	if is_game_over:
		return  # ゲームオーバー時は進行しない
	
	turn += 1
	steps_in_round += 1
	var gained := _advance_generation()
	score += gained
	emit_signal("stepped", turn, gained, score)
	emit_signal("round_changed", round, target_score, steps_per_round - steps_in_round)
	queue_redraw()
	
	# ステップごとにショップをリロール
	roll_shop()
	
	# ラウンド終了チェック
	check_round_completion()

# 指定量の経験値を増加させる

func roll_shop(num: int = 3) -> void:
	"""ショップをリロールする（遺伝子とアイテムからランダムに選択）"""
	var pool := GENE_CANDIDATES.duplicate()
	# アイテムも候補に追加
	pool.append_array(ITEM_CANDIDATES)
	pool.shuffle()
	shop_genes = []
	for i in range(min(num, pool.size())):
		shop_genes.append(pool[i])
	emit_signal("shop_changed", shop_genes)
	print("[SHOP] リロール: ", shop_genes)

# index: 0,1,2 など、shop_genes のインデックス
func buy_gene(index: int) -> bool:
	if is_game_over:
		return false
	if index < 0 or index >= shop_genes.size():
		return false

	var selected_kind: String = shop_genes[index]
	
	# アイテムか遺伝子かを判定
	if is_item(selected_kind):
		# アイテムの購入処理
		var info: Dictionary = get_item_info(selected_kind)
		var cost: int = int(info.get("cost", 3))
		
		if not spend_gold(cost):
			print("[SHOP] Not enough gold.")
			return false
		
		# アイテムボックスに追加
		item_box[selected_kind] = item_box.get(selected_kind, 0) + 1
		emit_signal("item_box_changed", item_box)
		
		# 購入したアイテムをショップから削除（買い切り）
		var shop_idx := shop_genes.find(selected_kind)
		if shop_idx != -1:
			shop_genes.remove_at(shop_idx)
			emit_signal("shop_changed", shop_genes)
		
		print("[SHOP] bought item: %s (cost %d)" % [selected_kind, cost])
		return true
	else:
		# 遺伝子の購入処理（既存の処理）
		var info: Dictionary = get_gene_info(selected_kind)
		var cost: int = int(info.get("cost", 3))

		if not spend_gold(cost):
			print("[SHOP] Not enough gold.")
			return false

		add_gene_to_pool(selected_kind)
		
		# 購入した遺伝子をショップから削除（買い切り）
		var shop_idx := shop_genes.find(selected_kind)
		if shop_idx != -1:
			shop_genes.remove_at(shop_idx)
			emit_signal("shop_changed", shop_genes)
		
		print("[SHOP] bought gene: %s (cost %d)" % [selected_kind, cost])
		return true

# リロールボタン用の関数
func manual_roll_shop() -> bool:
	"""手動でショップをリロールする（ゴールドを消費）"""
	if is_game_over:
		return false
	if not spend_gold(reroll_cost):
		print("[SHOP] リロールに必要なゴールドが不足しています (必要: %dG)" % reroll_cost)
		return false
	roll_shop()
	print("[SHOP] リロールしました (コスト: %dG)" % reroll_cost)
	return true



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
					# 遺伝子プールから遺伝子を選択
					var drawn_gene := _draw_gene()
					if drawn_gene != "":
						# 遺伝子プールに遺伝子がある場合のみセルを生まれさせる
						next_alive[x][y] = true
						next_kind[x][y] = drawn_gene
						birth_list.append(Vector2i(x, y))
					else:
						# 遺伝子プールが空の場合はセルを生まれさせない
						next_alive[x][y] = false
						next_kind[x][y] = "vanilla"
				else:
					next_alive[x][y] = false
					next_kind[x][y] = "vanilla"

	# 誕生フック＋出生スコア
	for v in birth_list:
		gained_score += birth_score
		gained_score += _on_birth(next_kind[v.x][v.y], v.x, v.y)
		add_gold(1)
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
	"""遺伝子プールからランダムに遺伝子を選択する。プールが空の場合は空文字列を返す"""
	if gene_pool.is_empty():
		return ""  # 遺伝子プールが空の場合は空文字列を返す
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
			return _guardian_effect(x, y)
		_:
			return 0

# ===== 特殊セル効果実装 =====
func _guardian_effect(x: int, y: int) -> int:
	"""守護セルの効果：死亡時に隣接する死亡セル1つを生存状態に復活させる"""
	var dead_neighbors: Array[Vector2i] = []
	
	# 隣接する死亡セルをリストアップ
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := x + dx
			var ny := y + dy
			if is_inside(nx, ny) and not next_alive[nx][ny]:
				dead_neighbors.append(Vector2i(nx, ny))
	
	# 死亡セルが見つかった場合、ランダムに1つ選んで復活させる
	if dead_neighbors.size() > 0:
		dead_neighbors.shuffle()
		var target := dead_neighbors[0]
		# 遺伝子プールから遺伝子を選択
		var drawn_gene := _draw_gene()
		if drawn_gene != "":
			# 遺伝子プールに遺伝子がある場合のみ復活させる
			next_alive[target.x][target.y] = true
			next_kind[target.x][target.y] = drawn_gene
			return 1  # スコア+1
		else:
			# 遺伝子プールが空の場合は復活させない
			return 1  # 守護セルが死亡したことによるスコア+1（復活はしない）
	
	# 救えるセルがない場合でもスコア+1（守護セルが死亡したことによる）
	return 1

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

# ① 遺伝子の集計を返す
func get_gene_counts() -> Dictionary:
	var d := {}
	for g in gene_pool:
		d[g] = (d.get(g, 0) + 1)
	return d

# ② 色を問い合わせる（UI用）
func get_kind_color(k: String) -> Color:
	if SPECIAL_COLORS.has(k):
		return SPECIAL_COLORS[k]
	return Color(0.85, 0.85, 0.9)  # vanilla 等の既定色
