extends CanvasLayer

@export var game_path: NodePath
var game: Node = null


@onready var panel: Panel                    = get_node_or_null("Panel")
@onready var shop_panel: Panel                = get_node_or_null("ShopPanel")
@onready var step_btn: Button                = get_node_or_null("Panel/VBox/Row1/StepBtn")
@onready var play_toggle: Button             = get_node_or_null("Panel/VBox/Row1/PlayToggle")
@onready var reset_btn: Button               = get_node_or_null("Panel/VBox/Row1/ResetBtn")
@onready var speed: HSlider                  = get_node_or_null("Panel/VBox/Row2/Speed")
@onready var speed_val: Label                = get_node_or_null("Panel/VBox/Row2/SpeedVal")
@onready var stats: Label                    = get_node_or_null("Panel/VBox/Stats")
@onready var gene_list: ItemList      = get_node_or_null("GenePanel/GeneRow/GeneList")
@onready var dup_btn: Button          = get_node_or_null("GenePanel/GeneRow/GeneBtns/DupBtn")
@onready var rem_btn: Button          = get_node_or_null("GenePanel/GeneRow/GeneBtns/RemBtn")
@onready var gold_label: Label = get_node_or_null("Panel/VBox/GoldLabel")
#@onready var shop0: Button = get_node_or_null("Panel/VBox/ShopRow/Shop0")
#@onready var shop1: Button = get_node_or_null("Panel/VBox/ShopRow/Shop1")
#@onready var shop2: Button = get_node_or_null("Panel/VBox/ShopRow/Shop2")

@onready var shop_btn0: Button = get_node_or_null("ShopPanel/ShopRow/ShopItem0/ShopBtn0")
@onready var shop_desc0: Label = get_node_or_null("ShopPanel/ShopRow/ShopItem0/ShopDesc0")
@onready var shop_btn1: Button = get_node_or_null("ShopPanel/ShopRow/ShopItem1/ShopBtn1")
@onready var shop_desc1: Label = get_node_or_null("ShopPanel/ShopRow/ShopItem1/ShopDesc1")
@onready var shop_btn2: Button = get_node_or_null("ShopPanel/ShopRow/ShopItem2/ShopBtn2")
@onready var shop_desc2: Label = get_node_or_null("ShopPanel/ShopRow/ShopItem2/ShopDesc2")
@onready var reroll_btn: Button = get_node_or_null("ShopPanel/RerollBtn")
@onready var round_label: Label = get_node_or_null("Panel/VBox/RoundLabel")
@onready var item_box_container: Container = get_node_or_null("ItemBoxPanel/ItemBoxContainer")  # アイテムボックスのコンテナ



#$@onready var stats = $Stats
func _ready() -> void:
	print("[UI] ready")

	# --- game ノードの取得（優先順：export → 自動探索）---
	if game_path != NodePath(""):
		game = get_node_or_null(game_path)
	if game == null:
		# class_name が LifeRoguelike のノードを自動探索
		for n in get_tree().get_nodes_in_group(""):
			# Godot 4: is キーワードで型チェック可（スクリプトに class_name が必要）
			if n is LifeRougeLike:
				game = n
				print("[UI] Found LifeRoguelike automatically at: ", n.get_path())
				break
	if game == null:
		push_error("[UI] LifeRoguelike が見つかりません。game_path を Inspector で設定してください。")

	# --- UI ノード存在チェック ---
	_warn_if_null(step_btn,    "StepBtn")
	_warn_if_null(play_toggle, "PlayToggle")
	_warn_if_null(reset_btn,   "ResetBtn")
	_warn_if_null(speed,       "Speed(HSlider)")
	_warn_if_null(speed_val,   "SpeedVal(Label)")
	_warn_if_null(stats,       "Stats(Label)")

	# --- シグナル接続（存在するものだけ）---
	if game and game.has_signal("stepped"):
		game.connect("stepped", Callable(self, "_on_game_stepped"))

	if step_btn:
		step_btn.pressed.connect(_on_step_pressed)
	if play_toggle:
		play_toggle.toggle_mode = true
		play_toggle.text = "▶︎"
		play_toggle.toggled.connect(_on_play_toggled)
	if reset_btn:
		reset_btn.pressed.connect(_on_reset_pressed)
	if speed:
		speed.value_changed.connect(_on_speed_changed)

	if game and game.has_signal("gene_pool_changed"):
		game.connect("gene_pool_changed", Callable(self, "_on_gene_pool_changed"))
	if gene_list:
		gene_list.select_mode = ItemList.SELECT_SINGLE
		gene_list.item_selected.connect(_on_gene_selected)
		# 遺伝子リストのアイテムクリック時に削除トークンが選択されていれば削除
		gene_list.item_activated.connect(_on_gene_item_activated)
		# ItemListのアイテム高さを設定（アイコンが見やすくなるように）
		# Godot 4では、アイコンがある場合、アイテムの高さは自動調整される
		print("[UI] gene_list item count after setup: ", gene_list.get_item_count())
		print("[UI] gene_list initial size: ", gene_list.size)
	if dup_btn:
		dup_btn.pressed.connect(_on_dup_gene)
	if rem_btn:
		rem_btn.pressed.connect(_on_rem_gene)



	_refresh_gene_pool()  # 初期描画
	_update_gene_btns_enabled()
	
	# 初期表示
	_update_speed_label()
	_apply_speed_to_game()
	
	# 初期ラウンド情報の表示
	_update_round_label()

	# デバッグ：ボタンが押されたら Panel の色を一瞬フラッシュ（ハンドラが走ってるか可視化）
	_install_debug_flash()
	
	# アイテムボックスの初期描画
	_refresh_item_box()
	if game and game.has_signal("shop_changed"):
		game.connect("shop_changed", Callable(self, "_on_shop_changed"))
	if game and game.has_signal("gold_changed"):
		game.connect("gold_changed", Callable(self, "_on_gold_changed"))
	if game and game.has_signal("round_changed"):
		game.connect("round_changed", Callable(self, "_on_round_changed"))
	if game and game.has_signal("game_over"):
		game.connect("game_over", Callable(self, "_on_game_over"))
	if game and game.has_signal("item_box_changed"):
		game.connect("item_box_changed", Callable(self, "_on_item_box_changed"))
	
	# アイテムボックスの初期描画（シグナル接続後）
	_refresh_item_box()
	
	# リロールボタンの接続
	if reroll_btn:
		reroll_btn.pressed.connect(_on_reroll_pressed)
		# リロールボタンのテキストにコストを表示
		if game:
			var cost: int = game.get("reroll_cost") if game.has_method("get") else 1
			reroll_btn.text = "Reroll (%dG)" % cost

	# --- ショップボタン接続（デバッグ出力つき） ---
	print("[UI] shop nodes:", shop_btn0, shop_btn1, shop_btn2)

	if shop_btn0:
		print("[UI] connecting shop0 pressed -> _on_shop_buy(0) : ", shop_btn0)
		shop_btn0.pressed.connect(func() -> void:
			print("[UI] shop0 pressed")
			_on_shop_buy(0)
		)
	else:
		print("[UI] shop0 is null")

	if shop_btn1:
		print("[UI] connecting shop1 pressed -> _on_shop_buy(1) : ", shop_btn1)
		shop_btn1.pressed.connect(func() -> void:
			print("[UI] shop1 pressed")
			_on_shop_buy(1)
		)
	else:
		print("[UI] shop1 is null")

	if shop_btn2:
		print("[UI] connecting shop2 pressed -> _on_shop_buy(2) : ", shop_btn2)
		shop_btn2.pressed.connect(func() -> void:
			print("[UI] shop2 pressed")
			_on_shop_buy(2)
		)
	else:
		print("[UI] shop2 is null")

# 売り場が更新されたら3スロットを描画
func _on_shop_changed(new_shop: Array) -> void:
	_update_shop_item(0, new_shop)
	_update_shop_item(1, new_shop)
	_update_shop_item(2, new_shop)

# 各スロットを更新
func _update_shop_item(idx: int, shop: Array) -> void:
	var btn: Button
	var desc: Label
	match idx:
		0: btn = shop_btn0; desc = shop_desc0
		1: btn = shop_btn1; desc = shop_desc1
		2: btn = shop_btn2; desc = shop_desc2
	if btn == null:
		return

	if idx < shop.size():
		var gene_kind: String = shop[idx]                                  # ← ここで gene_kind を宣言
		var info: Dictionary = game.call("get_gene_info", gene_kind)        # ← self でなく game.call
		var gene_name := String(info.get("name", gene_kind))
		var detail := String(info.get("desc", ""))
		var cost := int(info.get("cost", 3))

		btn.text = "%s (%dG)" % [gene_name, cost]
		btn.disabled = false
		if desc:
			desc.text = detail
	else:
		btn.text = "---"
		btn.disabled = true
		if desc:
			desc.text = ""

# ゴールド表示
func _on_gold_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % new_gold

# クリックで購入
func _on_shop_buy(idx: int) -> void:
	print("test2")
	if game == null:
		print("[UI] ゲームノードが見つかりません。")
		return
	var ok: bool = game.call("buy_gene", idx)   # ← self でなく game.call
	if not ok:
		print("[UI] 購入失敗（お金不足 or インデックス不正）")

func _on_experience_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "gold: %d" % new_gold

func _warn_if_null(node: Node, name: String) -> void:
	if node == null:
		push_warning("[UI] " + name + " が見つかりません。ノードパスを確認してください。")

# =============== ハンドラ ===============
func _on_step_pressed() -> void:
	print("[UI] Step pressed")
	_flash_panel(Color(0.2, 0.8, 1.0, 0.25))
	if game:
		game.call_deferred("do_step")  # 安全のため deferred 呼び出し

func _on_play_toggled(pressed: bool) -> void:
	print("[UI] Play toggled: ", pressed)
	if play_toggle:
		play_toggle.text = "⏸" if pressed else "▶︎"
	if pressed and speed and int(speed.value) == 0:
		speed.value = 5  # 0 だと動かないので初期値
	_update_speed_label()
	_apply_speed_to_game()
	_flash_panel(Color(0.4, 1.0, 0.4, 0.2))



func _on_reset_pressed() -> void:
	print("[UI] Reset pressed")
	_flash_panel(Color(1.0, 0.4, 0.4, 0.25))
	if game:
		game.call_deferred("reset_board")
	if stats:
		stats.text = "Turn 0   Score 0"

func _on_speed_changed(_value: float) -> void:
	print("[UI] Speed changed: ", _value)
	_update_speed_label()
	_apply_speed_to_game()

func _on_game_stepped(turn: int, gained: int, total: int) -> void:
	if stats:
		stats.text = "Turn {0}   Score {1} ( +{2} )".format([turn, total, gained])
		#stats.text = "Turn %d   Score %d ( +%d )" +str(turn) +str(total) +str(gained)
		#$Stats.text = "Turn %d   Score %d ( +%d )" % [turn, total, gained]
	# ステップごとにラウンド情報も更新
	_update_round_label()

func _on_round_changed(_round: int, _target_score: int, _steps_remaining: int) -> void:
	"""ラウンド情報が更新されたときのハンドラ"""
	_update_round_label()

func _update_round_label() -> void:
	"""ラウンド情報のラベルを更新する"""
	if round_label == null or game == null:
		return
	
	# ゲームオブジェクトから直接プロパティを取得
	# gameはLifeRougeLike型なので、直接プロパティにアクセス可能
	var current_round: int = game.round
	var target: int = game.target_score
	var steps_in_round: int = game.steps_in_round
	var steps_per_round: int = game.steps_per_round
	var round_start_score: int = game.round_start_score
	var current_score: int = game.score
	
	# ラウンド内のスコアを計算（ラウンド開始時からの増分）
	var round_score: int = current_score - round_start_score
	
	var steps_remaining: int = steps_per_round - steps_in_round
	
	round_label.text = "Round {0}   Score: {1}/{2}   Steps: {3}/{4}".format([
		current_round, round_score, target, steps_remaining, steps_per_round
	])



func _on_game_over(round: int, final_score: int) -> void:
	"""ゲームオーバー時のハンドラ"""
	if stats:
		stats.text = "GAME OVER   Round {0}   Final Score: {1}".format([round, final_score])
	if round_label:
		round_label.text = "GAME OVER - Round {0}".format([round])
	print("[UI] Game Over - Round %d, Score %d" % [round, final_score])

func _on_reroll_pressed() -> void:
	"""リロールボタンが押されたときのハンドラ"""
	print("[UI] Reroll pressed")
	if game:
		var success: bool = game.call("manual_roll_shop")
		if not success:
			print("[UI] リロール失敗（ゴールド不足）")
		else:
			# リロール成功時、ボタンのテキストを更新（コストが変わった場合に備えて）
			if reroll_btn and game:
				var cost: int = game.get("reroll_cost") if game.has_method("get") else 1
				reroll_btn.text = "Reroll (%dG)" % cost

# =============== ゲーム制御 ===============
func _apply_speed_to_game() -> void:
	if game == null:
		return
	var steps_per_sec: float = 0.0
	if play_toggle and play_toggle.button_pressed and speed:
		steps_per_sec = float(speed.value)
	var interval := (1.0 / steps_per_sec) if steps_per_sec > 0.0 else 0.0
	game.set("step_interval_sec", interval)
	print("[UI] set step_interval_sec = ", interval)

func _update_speed_label() -> void:
	if speed_val and speed:
		speed_val.text = "%d step/s" % int(speed.value)

# =============== デバッグ可視化 ===============
var _panel_style_backup: StyleBox = null
func _install_debug_flash() -> void:
	if panel == null:
		return
	# 背景が完全透明だと見えないので最低限の StyleBox を用意
	if panel.get_theme_stylebox("panel") == null:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.1, 0.1, 0.1, 0.85)
		sb.border_width_all = 1
		sb.border_color = Color(1,1,1,0.2)
		panel.add_theme_stylebox_override("panel", sb)

func _flash_panel(col: Color) -> void:
	if panel == null:
		return
	var sb := panel.get_theme_stylebox("panel")
	if sb is StyleBoxFlat:
		var flat := sb as StyleBoxFlat
		var before := flat.bg_color
		flat.bg_color = col
		await get_tree().create_timer(0.08).timeout
		flat.bg_color = before

func _on_gene_pool_changed(_pool: Array) -> void:
	print("[UI] _on_gene_pool_changed() called with pool: ", _pool)
	_refresh_gene_pool()

func _on_gene_selected(_idx: int) -> void:
	_update_gene_btns_enabled()

func _on_gene_item_activated(index: int) -> void:
	"""遺伝子リストのアイテムがダブルクリックまたはアクティベートされたとき"""
	if game == null:
		return
	
	# 削除トークンが選択されているか確認
	if game.is_delete_token_selected:
		var gene_type: String = gene_list.get_item_metadata(index)
		if gene_type != "":
			var success: bool = game.call("apply_delete_token", gene_type)
			if success:
				print("[UI] 遺伝子 %s を削除しました" % gene_type)
			else:
				print("[UI] 遺伝子の削除に失敗しました")

func _selected_kind() -> String:
	if gene_list == null:
		return ""
	var sel := gene_list.get_selected_items()
	if sel.is_empty():
		return ""
	return String(gene_list.get_item_metadata(sel[0]))

func _on_dup_gene() -> void:
	var k := _selected_kind()
	if k != "" and game:
		game.call("duplicate_gene", k)

func _on_rem_gene() -> void:
	var k := _selected_kind()
	if k != "" and game:
		game.call("remove_gene", k)

func _update_gene_btns_enabled() -> void:
	var has_sel := (_selected_kind() != "")
	if dup_btn: dup_btn.disabled = not has_sel
	if rem_btn: rem_btn.disabled = not has_sel

func _refresh_gene_pool() -> void:
	"""現在持っている遺伝子を色付き四角で表示する"""
	print("[UI] _refresh_gene_pool() called")
	
	if gene_list == null:
		print("[UI] ERROR: gene_list is null")
		return
	
	if game == null:
		print("[UI] ERROR: game is null")
		return
	
	print("[UI] gene_list type: ", gene_list.get_class())
	print("[UI] game type: ", game.get_class())
	
	var counts: Dictionary = game.call("get_gene_counts")
	print("[UI] gene counts: ", counts)
	
	var total := 0
	for v in counts.values():
		total += int(v)
	print("[UI] total genes: ", total)

	gene_list.clear()
	print("[UI] gene_list cleared")

	# 遺伝子がない場合
	if total == 0:
		print("[UI] No genes to display")
		_update_gene_btns_enabled()
		return

	# 表示順：vanilla を先頭、その後に特殊をアルファベット順
	var keys := []
	if counts.has("vanilla"):
		keys.append("vanilla")
	for k in counts.keys():
		if k != "vanilla":
			keys.append(k)
	keys.sort_custom(func(a,b): return String(a) < String(b))
	print("[UI] gene keys (sorted): ", keys)

	# 各遺伝子の個数分だけ色付き四角を追加
	var item_count := 0
	for k in keys:
		var n := int(counts.get(k, 0))
		print("[UI] Processing gene: %s, count: %d" % [k, n])
		
		var color: Color = game.call("get_kind_color", String(k))
		print("[UI] Gene color: ", color)
		
		# 色付きのアイコン画像を生成（色付き四角として表示）
		var icon_size := 20  # アイコンのサイズ
		var icon_image := Image.create(icon_size, icon_size, false, Image.FORMAT_RGBA8)
		icon_image.fill(color)
		
		# 枠線を追加（見分けやすくするため）
		var border_color := Color(0.2, 0.2, 0.2, 1.0)  # 濃いグレーの枠線
		var border_width := 1  # 枠線の太さ
		
		# 上辺と下辺
		for x in range(icon_size):
			for w in range(border_width):
				if x < icon_size and w < icon_size:
					icon_image.set_pixel(x, w, border_color)  # 上辺
					icon_image.set_pixel(x, icon_size - 1 - w, border_color)  # 下辺
		
		# 左辺と右辺
		for y in range(icon_size):
			for w in range(border_width):
				if y < icon_size and w < icon_size:
					icon_image.set_pixel(w, y, border_color)  # 左辺
					icon_image.set_pixel(icon_size - 1 - w, y, border_color)  # 右辺
		
		var icon_texture := ImageTexture.create_from_image(icon_image)
		
		# 個数分だけアイテムを追加（各アイテムが色付き四角）
		for i in range(n):
			# アイコンを設定してアイテムを追加（アイコンが色付き四角として表示される）
			var idx := gene_list.add_item("", icon_texture)
			print("[UI] Added item at index %d for gene %s with icon" % [idx, k])
			gene_list.set_item_metadata(idx, String(k))
			# 背景色も設定（念のため）
			gene_list.set_item_custom_bg_color(idx, color)
			# フォアグラウンド色も設定
			gene_list.set_item_custom_fg_color(idx, color)
			item_count += 1
	
	print("[UI] Total items added to gene_list: ", item_count)
	print("[UI] gene_list item count: ", gene_list.get_item_count())
	print("[UI] gene_list size: ", gene_list.size)
	print("[UI] gene_list visible: ", gene_list.visible)
	print("[UI] gene_list rect: ", gene_list.get_rect())
	
	# ItemListのアイテム高さを確認（Godot 4ではアイテム高さは自動調整されるが、確認のため）
	if gene_list.get_item_count() > 0:
		print("[UI] First item text: '%s'" % gene_list.get_item_text(0))
		print("[UI] First item bg color: ", gene_list.get_item_custom_bg_color(0))

	_update_gene_btns_enabled()

# ===== アイテムボックス関連 =====
func _on_item_box_changed(_new_items: Dictionary) -> void:
	"""アイテムボックスが更新されたときのハンドラ"""
	_refresh_item_box()

func _refresh_item_box() -> void:
	"""アイテムボックスを更新する"""
	print("[UI] _refresh_item_box() called")
	print("[UI] item_box_container: ", item_box_container)
	print("[UI] game: ", game)
	if item_box_container == null:
		print("[UI] ERROR: item_box_container is null!")
		return
	if game == null:
		print("[UI] ERROR: game is null!")
		return
	
	# 既存の子ノードを削除
	for child in item_box_container.get_children():
		child.queue_free()
	
	var item_box: Dictionary = game.item_box
	print("[UI] Refreshing item box: ", item_box)
	
	# 削除トークンを表示
	if item_box.has("delete_token"):
		var count: int = item_box["delete_token"]
		for i in range(count):
			_create_delete_token_icon(i)

func _create_delete_token_icon(index: int) -> void:
	"""削除トークンのアイコンを作成"""
	if item_box_container == null:
		return
	
	# ボタンを作成
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(30, 30)
	
	# 削除トークンのアイコン画像を生成（赤いXマーク）
	var icon_size := 24
	var icon_image := Image.create(icon_size, icon_size, false, Image.FORMAT_RGBA8)
	icon_image.fill(Color(0.2, 0.2, 0.2, 1.0))  # 背景色（濃いグレー）
	
	# Xマークを描画（赤色）
	var x_color := Color(0.9, 0.2, 0.2, 1.0)  # 赤色
	var line_width := 2
	var margin := 4
	
	# 左上から右下への線
	for i in range(icon_size - margin * 2):
		var x := margin + i
		var y := margin + i
		if x < icon_size and y < icon_size:
			for w in range(line_width):
				if x + w < icon_size and y + w < icon_size:
					icon_image.set_pixel(x + w, y + w, x_color)
				if x - w >= 0 and y - w >= 0:
					icon_image.set_pixel(x - w, y - w, x_color)
	
	# 右上から左下への線
	for i in range(icon_size - margin * 2):
		var x := icon_size - margin - i
		var y := margin + i
		if x >= 0 and y < icon_size:
			for w in range(line_width):
				if x - w >= 0 and y + w < icon_size:
					icon_image.set_pixel(x - w, y + w, x_color)
				if x + w < icon_size and y - w >= 0:
					icon_image.set_pixel(x + w, y - w, x_color)
	
	# 枠線を追加
	var border_color := Color(0.1, 0.1, 0.1, 1.0)
	var border_width := 1
	for x in range(icon_size):
		for w in range(border_width):
			if x < icon_size and w < icon_size:
				icon_image.set_pixel(x, w, border_color)
				icon_image.set_pixel(x, icon_size - 1 - w, border_color)
	for y in range(icon_size):
		for w in range(border_width):
			if y < icon_size and w < icon_size:
				icon_image.set_pixel(w, y, border_color)
				icon_image.set_pixel(icon_size - 1 - w, y, border_color)
	
	var icon_texture := ImageTexture.create_from_image(icon_image)
	btn.icon = icon_texture
	
	# クリック時の処理
	btn.pressed.connect(func():
		_on_delete_token_clicked()
	)
	
	item_box_container.add_child(btn)
	print("[UI] Created delete token icon %d" % index)

func _on_delete_token_clicked() -> void:
	"""削除トークンのアイコンがクリックされたとき"""
	if game == null:
		return
	
	# 削除トークンが既に選択されている場合はキャンセル
	if game.is_delete_token_selected:
		game.call("cancel_delete_token")
		print("[UI] 削除トークンの選択をキャンセルしました")
	else:
		# 削除トークンを選択
		var success: bool = game.call("use_delete_token")
		if success:
			print("[UI] 削除トークンを選択しました。遺伝子をクリックして削除してください。")
		else:
			print("[UI] 削除トークンがありません")
