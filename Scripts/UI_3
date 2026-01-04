extends CanvasLayer

@export var game_path: NodePath = NodePath("")
@export var panel_margin: int = 10
@export var control_spacing: int = 5
@export var reroll_panel_margin_right: int = 20  # Extra margin for reroll panel
var game: Node = null

# --- UI nodes ---
@onready var panel_container: Container = get_node_or_null("PanelContainer")
@onready var panel: Panel = get_node_or_null("Panel")
@onready var main_vbox: VBoxContainer = get_node_or_null("Panel/VBox")
@onready var shop_panel: Panel = get_node_or_null("ShopPanel")
@onready var step_btn: Button = get_node_or_null("Panel/VBox/Row1/StepBtn")
@onready var play_toggle: Button = get_node_or_null("Panel/VBox/Row1/PlayToggle")
@onready var reset_btn: Button = get_node_or_null("Panel/VBox/Row1/ResetBtn")
@onready var speed: HSlider = get_node_or_null("Panel/VBox/Row2/Speed")
@onready var speed_val: Label = get_node_or_null("Panel/VBox/Row2/SpeedVal")
@onready var stats: Label = get_node_or_null("Panel/VBox/Stats")
@onready var gene_panel: Panel = get_node_or_null("GenePanel")
@onready var gene_list: ItemList = get_node_or_null("GenePanel/GeneRow/GeneList")
@onready var dup_btn: Button = get_node_or_null("GenePanel/GeneRow/GeneBtns/DupBtn")
@onready var rem_btn: Button = get_node_or_null("GenePanel/GeneRow/GeneBtns/RemBtn")
@onready var gold_label: Label = get_node_or_null("Panel/VBox/GoldLabel")

@onready var shop_btn0: Button = get_node_or_null("ShopPanel/ShopRow/ShopItem0/ShopBtn0")
@onready var shop_desc0: Label = get_node_or_null("ShopPanel/ShopRow/ShopItem0/ShopDesc0")
@onready var shop_btn1: Button = get_node_or_null("ShopPanel/ShopRow/ShopItem1/ShopBtn1")
@onready var shop_desc1: Label = get_node_or_null("ShopPanel/ShopRow/ShopItem1/ShopDesc1")
@onready var shop_btn2: Button = get_node_or_null("ShopPanel/ShopRow/ShopItem2/ShopBtn2")
@onready var shop_desc2: Label = get_node_or_null("ShopPanel/ShopRow/ShopItem2/ShopDesc2")
@onready var reroll_btn: Button = get_node_or_null("RerollPanel/RerollBtn")  # Changed back to RerollPanel
@onready var round_label: Label = get_node_or_null("Panel/VBox/RoundLabel")
@onready var item_box_panel: Panel = get_node_or_null("ItemBoxPanel")
@onready var item_box_container: Container = get_node_or_null("ItemBoxPanel/ItemBoxContainer")
@onready var reroll_panel: Panel = get_node_or_null("RerollPanel")  # Dedicated panel for reroll

# --- Constants for UI sizing ---
const MIN_BUTTON_WIDTH = 100
const MIN_BUTTON_HEIGHT = 40
const GENE_LIST_MIN_HEIGHT = 200
const GENE_ITEM_HEIGHT = 40  # Increased height for better visibility
const SHOP_BUTTON_MIN_WIDTH = 140
const SHOP_BUTTON_HEIGHT = 70
const ITEM_ICON_SIZE = 40
const GENE_COLOR_BAR_WIDTH = 30  # Width for color bar display
const REROLL_PANEL_WIDTH = 150
const REROLL_BTN_HEIGHT = 80
const SHOP_DESC_WIDTH = 300  # Ensure shop descriptions have enough width

# --- lifecycle ---
func _ready() -> void:
	print("[UI] ready")
	
	# Apply layout settings first
	_apply_layout_settings()
	
	# --- find game node (exported path takes precedence) ---
	if game_path != NodePath(""):
		game = get_node_or_null(game_path)
	if game == null:
		# Try to find an instance of the game by class (if available in the scene)
		for n in get_tree().get_nodes_in_group(""):
			if n.is_in_group("LifeRougeLike") or n.get_class() == "LifeRoguelike":
				game = n
				print("[UI] Found LifeRoguelike automatically at: ", n.get_path())
				break
	if game == null:
		push_error("[UI] LifeRoguelike not found. Set 'game_path' in the Inspector.")

	# --- sanity checks for important UI nodes ---
	_warn_if_null(step_btn, "StepBtn")
	_warn_if_null(play_toggle, "PlayToggle")
	_warn_if_null(reset_btn, "ResetBtn")
	_warn_if_null(speed, "Speed(HSlider)")
	_warn_if_null(speed_val, "SpeedVal(Label)")
	_warn_if_null(stats, "Stats(Label)")
	_warn_if_null(gene_list, "GeneList")
	_warn_if_null(item_box_container, "ItemBoxContainer")
	_warn_if_null(reroll_btn, "RerollBtn")
	_warn_if_null(reroll_panel, "RerollPanel")

	# Ensure shop descriptions have enough width
	_ensure_shop_description_width()

	# --- button text / tooltips / basic setup ---
	if step_btn:
		step_btn.text = "STEP"
		step_btn.tooltip_text = "Manually advances the simulation by one generation (Spacebar)."
		step_btn.pressed.connect(_on_step_pressed)
		step_btn.custom_minimum_size = Vector2(MIN_BUTTON_WIDTH, MIN_BUTTON_HEIGHT)
		step_btn.add_theme_font_size_override("font_size", 14)

	if play_toggle:
		play_toggle.toggle_mode = true
		play_toggle.text = "▶ PLAY"
		play_toggle.tooltip_text = "Toggle automatic simulation on/off."
		play_toggle.toggled.connect(_on_play_toggled)
		play_toggle.custom_minimum_size = Vector2(MIN_BUTTON_WIDTH, MIN_BUTTON_HEIGHT)
		play_toggle.add_theme_font_size_override("font_size", 14)

	if reset_btn:
		reset_btn.text = "RESET"
		reset_btn.tooltip_text = "Resets the board state, rounds, and economy."
		reset_btn.pressed.connect(_on_reset_pressed)
		reset_btn.custom_minimum_size = Vector2(MIN_BUTTON_WIDTH, MIN_BUTTON_HEIGHT)
		reset_btn.add_theme_font_size_override("font_size", 14)

	if speed:
		speed.value_changed.connect(_on_speed_changed)
		speed.custom_minimum_size = Vector2(200, 25)
		speed.value = 5  # Default speed

	if speed_val:
		speed_val.add_theme_font_size_override("font_size", 12)
		speed_val.custom_minimum_size = Vector2(80, 20)

	if dup_btn:
		dup_btn.text = "ADD GENE (+1)"
		dup_btn.tooltip_text = "Adds one instance of the selected gene to your pool."
		dup_btn.pressed.connect(_on_dup_gene)
		dup_btn.custom_minimum_size = Vector2(140, MIN_BUTTON_HEIGHT)
		dup_btn.add_theme_font_size_override("font_size", 12)

	if rem_btn:
		rem_btn.text = "REMOVE GENE (-1)"
		rem_btn.tooltip_text = "Permanently removes one instance of the selected gene from your pool."
		rem_btn.pressed.connect(_on_rem_gene)
		rem_btn.custom_minimum_size = Vector2(140, MIN_BUTTON_HEIGHT)
		rem_btn.add_theme_font_size_override("font_size", 12)

	# REROOLL BUTTON - in separate panel on far right
	if reroll_btn:
		reroll_btn.pressed.connect(_on_reroll_pressed)
		reroll_btn.custom_minimum_size = Vector2(REROLL_PANEL_WIDTH - 30, REROLL_BTN_HEIGHT)
		reroll_btn.add_theme_font_size_override("font_size", 16)
		
		# Update reroll button text based on game cost
		if game != null:
			var cost: int = 1
			if game.has_method("get_reroll_cost"):
				cost = game.get_reroll_cost()
			elif "reroll_cost" in game:
				cost = game.reroll_cost
				
			reroll_btn.text = "REROLL\n(%d G)" % cost
			reroll_btn.tooltip_text = "Reroll shop items for %d Gold." % cost
		else:
			reroll_btn.text = "REROLL\n(1 G)"
			reroll_btn.tooltip_text = "Reroll shop items for 1 Gold."

	# Style reroll panel
	if reroll_panel:
		_style_reroll_panel()

	# --- connect game signals ---
	if game != null:
		# Check and connect signals safely
		var signals_to_check = [
			"stepped",
			"gene_pool_changed", 
			"shop_changed",
			"gold_changed",
			"round_changed",
			"game_over",
			"item_box_changed"
		]
		
		for signal_name in signals_to_check:
			if game.has_signal(signal_name):
				print("[UI] Connecting signal: ", signal_name)
				game.connect(signal_name, Callable(self, "_on_" + signal_name))
			else:
				print("[UI] Signal not found: ", signal_name)

	# gene list setup
	if gene_list:
		gene_list.select_mode = ItemList.SELECT_SINGLE
		gene_list.max_columns = 1
		gene_list.fixed_column_width = 300
		gene_list.same_column_width = true
		gene_list.auto_height = true
		gene_list.item_selected.connect(_on_gene_selected)
		gene_list.item_activated.connect(_on_gene_item_activated)
		gene_list.custom_minimum_size = Vector2(300, GENE_LIST_MIN_HEIGHT)

	# shop buttons (connect with debug prints)
	_connect_shop_button(shop_btn0, 0)
	_connect_shop_button(shop_btn1, 1)
	_connect_shop_button(shop_btn2, 2)
	
	# Set shop button sizes
	if shop_btn0:
		shop_btn0.custom_minimum_size = Vector2(SHOP_BUTTON_MIN_WIDTH, SHOP_BUTTON_HEIGHT)
		shop_btn0.add_theme_font_size_override("font_size", 12)
	if shop_btn1:
		shop_btn1.custom_minimum_size = Vector2(SHOP_BUTTON_MIN_WIDTH, SHOP_BUTTON_HEIGHT)
		shop_btn1.add_theme_font_size_override("font_size", 12)
	if shop_btn2:
		shop_btn2.custom_minimum_size = Vector2(SHOP_BUTTON_MIN_WIDTH, SHOP_BUTTON_HEIGHT)
		shop_btn2.add_theme_font_size_override("font_size", 12)

	# initial refreshes
	_refresh_gene_pool()
	_update_gene_btns_enabled()
	_update_speed_label()
	_apply_speed_to_game()
	_update_round_label()
	_install_debug_flash()
	_refresh_item_box()
	
	# Initial gold update if game exists
	if game != null and gold_label:
		if "gold" in game:
			gold_label.text = "Gold: %d" % game.gold
		gold_label.add_theme_font_size_override("font_size", 14)
	
	if stats:
		stats.add_theme_font_size_override("font_size", 13)
	
	if round_label:
		round_label.add_theme_font_size_override("font_size", 12)
	
	# Force layout update
	await get_tree().process_frame
	_update_ui_layout()

# ---------------- Layout Helpers ----------------
func _apply_layout_settings() -> void:
	# Apply spacing and margin settings to containers
	if main_vbox:
		main_vbox.add_theme_constant_override("separation", control_spacing)
	
	if panel_container:
		panel_container.add_theme_constant_override("margin_left", panel_margin)
		panel_container.add_theme_constant_override("margin_top", panel_margin)
		panel_container.add_theme_constant_override("margin_right", panel_margin)
		panel_container.add_theme_constant_override("margin_bottom", panel_margin)

func _ensure_shop_description_width() -> void:
	# Make sure shop descriptions have enough width
	if shop_desc0:
		shop_desc0.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_desc0.custom_minimum_size = Vector2(SHOP_DESC_WIDTH, 0)
	if shop_desc1:
		shop_desc1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_desc1.custom_minimum_size = Vector2(SHOP_DESC_WIDTH, 0)
	if shop_desc2:
		shop_desc2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_desc2.custom_minimum_size = Vector2(SHOP_DESC_WIDTH, 0)

func _style_reroll_panel() -> void:
	if reroll_panel:
		# Style the reroll panel as a compact floating panel
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.15, 0.18, 0.22, 0.9)
		style_box.border_width_bottom = 2
		style_box.border_width_top = 2
		style_box.border_width_left = 2
		style_box.border_width_right = 2
		style_box.border_color = Color(0.3, 0.4, 0.5, 0.9)
		style_box.corner_radius_top_left = 10
		style_box.corner_radius_top_right = 10
		style_box.corner_radius_bottom_left = 10
		style_box.corner_radius_bottom_right = 10
		style_box.content_margin_left = 10
		style_box.content_margin_right = 10
		style_box.content_margin_top = 10
		style_box.content_margin_bottom = 10
		style_box.shadow_color = Color(0, 0, 0, 0.4)
		style_box.shadow_size = 6
		reroll_panel.add_theme_stylebox_override("panel", style_box)
		
		# Make the panel compact
		reroll_panel.custom_minimum_size = Vector2(REROLL_PANEL_WIDTH, REROLL_BTN_HEIGHT + 30)

func _update_ui_layout() -> void:
	# Update various UI element sizes and positions
	_update_stats_label()
	_update_gold_label()
	_update_round_label_display()
	_fit_gene_list()
	_fit_item_box()
	_position_reroll_panel()

func _position_reroll_panel() -> void:
	if reroll_panel:
		# Position the reroll panel on the far right side
		var viewport_size = get_viewport().size
		
		# Calculate position - far right with extra margin
		var panel_x = viewport_size.x - REROLL_PANEL_WIDTH - reroll_panel_margin_right
		
		# Position it at a good vertical spot (around middle-top)
		var panel_y = panel_margin + 150  # Below the main panel
		
		reroll_panel.position = Vector2(panel_x, panel_y)
		
		# Center the reroll button within the panel
		if reroll_btn:
			var btn_pos_x = (REROLL_PANEL_WIDTH - reroll_btn.custom_minimum_size.x) / 2
			var btn_pos_y = (reroll_panel.custom_minimum_size.y - reroll_btn.custom_minimum_size.y) / 2
			reroll_btn.position = Vector2(btn_pos_x, btn_pos_y)

func _update_stats_label() -> void:
	if stats:
		stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stats.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stats.custom_minimum_size = Vector2(0, 40)

func _update_gold_label() -> void:
	if gold_label:
		gold_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		gold_label.custom_minimum_size = Vector2(0, 30)

func _update_round_label_display() -> void:
	if round_label:
		round_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		round_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		round_label.custom_minimum_size = Vector2(0, 60)

func _fit_gene_list() -> void:
	if gene_list:
		# Calculate appropriate size for gene list
		var item_count = gene_list.get_item_count()
		var list_height = max(item_count * GENE_ITEM_HEIGHT, GENE_LIST_MIN_HEIGHT)
		gene_list.custom_minimum_size = Vector2(300, list_height)

func _fit_item_box() -> void:
	if item_box_container:
		# Set fixed size for item box container
		item_box_container.custom_minimum_size = Vector2(ITEM_ICON_SIZE * 5 + 10, ITEM_ICON_SIZE + 10)

# ---------------- Other Helpers ----------------
func _node_safe(path: String) -> Node:
	return get_node_or_null(path)

func _connect_shop_button(btn: Button, idx: int) -> void:
	if btn:
		print("[UI] connecting shop%d" % idx)
		btn.pressed.connect(func() -> void:
			print("[UI] shop%d pressed" % idx)
			_on_shop_buy(idx)
		)
	else:
		print("[UI] shop%d is null" % idx)

func _warn_if_null(node: Node, name: String) -> void:
	if node == null:
		push_warning("[UI] %s が見つかりません。ノードパスを確認してください。" % name)

# ---------------- Shop ----------------
func _on_shop_changed(new_shop: Array) -> void:
	# update three slots
	_update_shop_item(0, new_shop)
	_update_shop_item(1, new_shop)
	_update_shop_item(2, new_shop)

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
		var gene_kind: String = shop[idx]
		# Check if game has the method
		if game != null and game.has_method("get_gene_info"):
			var info: Dictionary = game.get_gene_info(gene_kind)
			var gene_name := String(info.get("name", gene_kind))
			var detail := String(info.get("desc", ""))
			var cost := int(info.get("cost", 3))

			btn.text = "%s\n(%dG)" % [gene_name, cost]
			btn.disabled = false
			if desc:
				desc.text = detail
				desc.autowrap_mode = TextServer.AUTOWRAP_WORD
				desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				desc.custom_minimum_size = Vector2(SHOP_DESC_WIDTH, 80)
				desc.add_theme_font_size_override("font_size", 11)
		else:
			btn.text = gene_kind
			btn.disabled = false
			if desc:
				desc.text = ""
	else:
		btn.text = "---"
		btn.disabled = true
		if desc:
			desc.text = ""

func _on_shop_buy(idx: int) -> void:
	if game == null:
		print("[UI] ゲームノードが見つかりません。")
		return
	if game.has_method("buy_gene"):
		var ok: bool = game.buy_gene(idx)
		if not ok:
			print("[UI] 購入失敗（お金不足 or インデックス不正）")
	else:
		print("[UI] Game doesn't have buy_gene method")

# ---------------- Economy / UI updates ----------------
func _on_gold_changed(new_gold: int) -> void:
	if gold_label:
		gold_label.text = "Gold: %d" % new_gold
	# Also update reroll button text to show current gold
	_update_reroll_button_text()

func _update_reroll_button_text() -> void:
	if reroll_btn and game != null:
		var cost: int = 1
		if game.has_method("get_reroll_cost"):
			cost = game.get_reroll_cost()
		elif "reroll_cost" in game:
			cost = game.reroll_cost
		
		var current_gold: int = 0
		if "gold" in game:
			current_gold = game.gold
		
		# Update button text with cost
		reroll_btn.text = "REROLL\n(%d G)" % cost
		reroll_btn.tooltip_text = "Reroll shop items for %d Gold.\nYou have: %d Gold" % [cost, current_gold]
		
		# Visual feedback if can't afford
		if current_gold < cost:
			reroll_btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
			reroll_btn.add_theme_color_override("font_pressed_color", Color(0.5, 0.5, 0.5))
			reroll_btn.add_theme_color_override("font_hover_color", Color(0.7, 0.7, 0.7))
		else:
			reroll_btn.remove_theme_color_override("font_color")
			reroll_btn.remove_theme_color_override("font_pressed_color")
			reroll_btn.remove_theme_color_override("font_hover_color")

func _on_reroll_pressed() -> void:
	print("[UI] Reroll pressed")
	if game and game.has_method("manual_roll_shop"):
		var success: bool = game.manual_roll_shop()
		if not success:
			print("[UI] リロール失敗（ゴールド不足）")
			# Visual feedback for failed reroll
			_flash_reroll_panel(Color(1.0, 0.3, 0.3, 0.4))
		else:
			# Visual feedback for successful reroll
			_flash_reroll_panel(Color(0.3, 1.0, 0.3, 0.4))
			# Update button text after successful reroll
			_update_reroll_button_text()
	else:
		print("[UI] Game doesn't have manual_roll_shop method")

func _flash_reroll_panel(color: Color) -> void:
	if reroll_panel:
		var original_style = reroll_panel.get_theme_stylebox("panel")
		if original_style is StyleBoxFlat:
			var flash_style = original_style.duplicate()
			flash_style.bg_color = color
			reroll_panel.add_theme_stylebox_override("panel", flash_style)
			
			await get_tree().create_timer(0.2).timeout
			reroll_panel.add_theme_stylebox_override("panel", original_style)

# ---------------- Game control ----------------
func _on_step_pressed() -> void:
	print("[UI] Step pressed")
	_flash_panel(Color(0.2, 0.8, 1.0, 0.25))
	if game and game.has_method("do_step"):
		game.do_step()
	elif game and game.has_method("step"):
		game.step()

func _on_play_toggled(pressed: bool) -> void:
	print("[UI] Play toggled: ", pressed)
	if play_toggle:
		play_toggle.text = "⏸ PAUSE" if pressed else "▶ PLAY"
	if pressed and speed and int(speed.value) == 0:
		speed.value = 5
	_update_speed_label()
	_apply_speed_to_game()
	_flash_panel(Color(0.4, 1.0, 0.4, 0.2))

func _on_reset_pressed() -> void:
	print("[UI] Reset pressed")
	_flash_panel(Color(1.0, 0.4, 0.4, 0.25))
	if game:
		if game.has_method("reset_board"):
			game.reset_board()
		elif game.has_method("reset"):
			game.reset()
	if stats:
		stats.text = "Turn 0    Score 0"
	# Update reroll button after reset
	_update_reroll_button_text()

func _on_speed_changed(_value: float) -> void:
	_update_speed_label()
	_apply_speed_to_game()
	_fit_gene_list()  # Update layout when speed changes

func _apply_speed_to_game() -> void:
	if game == null:
		return
	var steps_per_sec: float = 0.0
	if play_toggle and play_toggle.button_pressed and speed:
		steps_per_sec = float(speed.value)
	var interval := (1.0 / steps_per_sec) if steps_per_sec > 0.0 else 0.0
	
	# Try to set the interval property or call a method
	if "step_interval_sec" in game:
		game.step_interval_sec = interval
	elif game.has_method("set_step_interval"):
		game.set_step_interval(interval)
	
	print("[UI] set step_interval = ", interval)

func _update_speed_label() -> void:
	if speed_val and speed:
		speed_val.text = "%d steps/s" % int(speed.value)
		speed_val.custom_minimum_size = Vector2(100, 20)

# ---------------- Game events ----------------
func _on_game_stepped(turn: int, gained: int, total: int) -> void:
	if stats:
		stats.text = "Turn: %d\nScore: %d (+%d)" % [turn, total, gained]
	_update_round_label()

func _on_round_changed(_round: int, _target_score: int, _steps_remaining: int) -> void:
	_update_round_label()

func _update_round_label() -> void:
	if round_label == null or game == null:
		return

	# Safely access game properties
	var current_round: int = 0
	var target: int = 0
	var steps_in_round: int = 0
	var steps_per_round: int = 0
	var round_start_score: int = 0
	var current_score: int = 0
	
	# Try to get properties with safety checks
	if "round" in game:
		current_round = game.round
	if "target_score" in game:
		target = game.target_score
	if "steps_in_round" in game:
		steps_in_round = game.steps_in_round
	if "steps_per_round" in game:
		steps_per_round = game.steps_per_round
	if "round_start_score" in game:
		round_start_score = game.round_start_score
	if "score" in game:
		current_score = game.score

	var round_score: int = current_score - round_start_score
	var steps_remaining: int = steps_per_round - steps_in_round

	round_label.text = "Round: %d\nScore: %d/%d\nSteps: %d/%d" % [
		current_round, round_score, target, steps_remaining, steps_per_round
	]

func _on_game_over(round: int, final_score: int) -> void:
	if stats:
		stats.text = "GAME OVER\nRound: %d\nFinal Score: %d" % [round, final_score]
	if round_label:
		round_label.text = "GAME OVER\nRound: %d" % [round]
	print("[UI] Game Over - Round %d, Score %d" % [round, final_score])

# ---------------- Gene pool UI ----------------
func _on_gene_pool_changed(_pool: Array) -> void:
	_refresh_gene_pool()
	_fit_gene_list()  # Update layout when gene pool changes

func _on_gene_selected(_idx: int) -> void:
	_update_gene_btns_enabled()

func _on_gene_item_activated(index: int) -> void:
	if game == null:
		return
	# Check if delete token is selected
	var is_delete_selected: bool = false
	if "is_delete_token_selected" in game:
		is_delete_selected = game.is_delete_token_selected
	
	if is_delete_selected:
		var gene_type: String = gene_list.get_item_metadata(index)
		if gene_type != "" and game.has_method("apply_delete_token"):
			var success: bool = game.apply_delete_token(gene_type)
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
	if k != "" and game and game.has_method("duplicate_gene"):
		game.duplicate_gene(k)

func _on_rem_gene() -> void:
	var k := _selected_kind()
	if k != "" and game and game.has_method("remove_gene"):
		game.remove_gene(k)

func _update_gene_btns_enabled() -> void:
	var has_sel := (_selected_kind() != "")
	if dup_btn: dup_btn.disabled = not has_sel
	if rem_btn: rem_btn.disabled = not has_sel

func _refresh_gene_pool() -> void:
	if gene_list == null or game == null:
		print("[UI] _refresh_gene_pool: missing gene_list or game")
		return

	# Check if game has the method
	if not game.has_method("get_gene_counts"):
		print("[UI] Game doesn't have get_gene_counts method")
		return

	var counts: Dictionary = game.get_gene_counts()
	var total := 0
	for v in counts.values():
		total += int(v)

	gene_list.clear()
	if total == 0:
		gene_list.add_item("No genes in pool")
		gene_list.set_item_disabled(0, true)
		_update_gene_btns_enabled()
		return

	# Create list of keys EXCLUDING vanilla
	var keys := []
	for k in counts.keys():
		if k != "vanilla":  # SKIP VANILLA
			keys.append(k)
	keys.sort()  # Sort alphabetically

	if keys.size() == 0:
		gene_list.add_item("No special genes")
		gene_list.set_item_disabled(0, true)
		_update_gene_btns_enabled()
		return

	for k in keys:
		var n := int(counts.get(k, 0))
		var color: Color = Color.WHITE
		if game.has_method("get_kind_color"):
			color = game.get_kind_color(String(k))
		
		# Create a larger, more visible color bar
		var icon_size := GENE_ITEM_HEIGHT - 10
		var icon_image := Image.create(GENE_COLOR_BAR_WIDTH, icon_size, false, Image.FORMAT_RGBA8)
		
		# Fill with the gene color
		icon_image.fill(color)
		
		# Add a border for better visibility
		var border_color := Color(0.1, 0.1, 0.1, 1.0)
		for x in range(GENE_COLOR_BAR_WIDTH):
			icon_image.set_pixel(x, 0, border_color)
			icon_image.set_pixel(x, icon_size - 1, border_color)
		for y in range(icon_size):
			icon_image.set_pixel(0, y, border_color)
			icon_image.set_pixel(GENE_COLOR_BAR_WIDTH - 1, y, border_color)
		
		var icon_texture := ImageTexture.create_from_image(icon_image)
		
		# Create display text with gene name and count
		var display_text = "%s (%d)" % [k.capitalize(), n]
		
		# Add item with larger color bar
		var idx := gene_list.add_item(display_text, icon_texture)
		gene_list.set_item_metadata(idx, String(k))
		
		# Set both background and custom colors for maximum visibility
		gene_list.set_item_custom_bg_color(idx, color.darkened(0.3))
		gene_list.set_item_custom_fg_color(idx, Color.WHITE if color.v < 0.5 else Color.BLACK)
		
		# Set icon to be on the left and text properly aligned
		gene_list.set_item_icon_region(idx, Rect2(0, 0, GENE_COLOR_BAR_WIDTH, icon_size))

	_update_gene_btns_enabled()

# ---------------- Item box (delete tokens) ----------------
func _on_item_box_changed(_new_items: Dictionary) -> void:
	_refresh_item_box()

func _refresh_item_box() -> void:
	if item_box_container == null or game == null:
		print("[UI] _refresh_item_box: missing container or game")
		return

	# clear existing
	for child in item_box_container.get_children():
		child.queue_free()

	# Check if game has item_box property
	if not "item_box" in game:
		return
		
	var item_box: Dictionary = game.item_box
	if item_box.has("delete_token"):
		var count: int = int(item_box["delete_token"])
		for i in range(count):
			_create_delete_token_icon(i)
	
	_fit_item_box()  # Update layout after refreshing items

func _create_delete_token_icon(index: int) -> void:
	if item_box_container == null:
		return
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(ITEM_ICON_SIZE, ITEM_ICON_SIZE)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# draw simple red X on a dark background
	var icon_size := ITEM_ICON_SIZE - 4
	var icon_image := Image.create(icon_size, icon_size, false, Image.FORMAT_RGBA8)
	icon_image.fill(Color(0.2, 0.2, 0.2, 1.0))
	var x_color := Color(0.9, 0.2, 0.2, 1.0)
	var line_width := 3
	var margin := 6
	for i in range(icon_size - margin * 2):
		var x := margin + i
		var y := margin + i
		for w in range(line_width):
			if x + w < icon_size and y + w < icon_size:
				icon_image.set_pixel(x + w, y + w, x_color)
			if x - w >= 0 and y - w >= 0:
				icon_image.set_pixel(x - w, y - w, x_color)
	for i in range(icon_size - margin * 2):
		var x2 := icon_size - margin - i
		var y2 := margin + i
		for w in range(line_width):
			if x2 - w >= 0 and y2 + w < icon_size:
				icon_image.set_pixel(x2 - w, y2 + w, x_color)
			if x2 + w < icon_size and y2 - w >= 0:
				icon_image.set_pixel(x2 + w, y2 - w, x_color)

	# border
	var border_color := Color(0.1, 0.1, 0.1, 1.0)
	for x in range(icon_size):
		icon_image.set_pixel(x, 0, border_color)
		icon_image.set_pixel(x, icon_size - 1, border_color)
	for y in range(icon_size):
		icon_image.set_pixel(0, y, border_color)
		icon_image.set_pixel(icon_size - 1, y, border_color)

	var icon_texture := ImageTexture.create_from_image(icon_image)
	btn.icon = icon_texture
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.pressed.connect(_on_delete_token_clicked)
	item_box_container.add_child(btn)

func _on_delete_token_clicked() -> void:
	if game == null:
		return
	
	# Check if delete token functionality exists
	if not ("is_delete_token_selected" in game):
		return
	
	if game.is_delete_token_selected:
		if game.has_method("cancel_delete_token"):
			game.cancel_delete_token()
			print("[UI] 削除トークンの選択をキャンセルしました")
	else:
		if game.has_method("use_delete_token"):
			var success: bool = game.use_delete_token()
			if success:
				print("[UI] 削除トークンを選択しました。遺伝子をクリックして削除してください。")
			else:
				print("[UI] 削除トークンがありません")

# ---------------- Debug visuals ----------------
var _panel_style_backup: StyleBox = null
func _install_debug_flash() -> void:
	if panel == null:
		return
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

# ---------------- Viewport resize handling ----------------
func _on_viewport_size_changed() -> void:
	# Update UI layout when window is resized
	await get_tree().process_frame
	_update_ui_layout()
