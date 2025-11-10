extends Node

signal shop_changed(new_shop : Array)
signal gene_pool_changed()
signal gold_changed(new_gold : int)



# 遺伝子定義
var gene_defs: Dictionary = {
    "vanilla": {"name":"Vanilla", "desc":"標準の遺伝子。特別な効果は無し。", "cost":0},
    "fastdivide": {"name":"Fast Divide", "desc":"分裂確率が上がる。", "cost":5},
    "resistant": {"name":"Resistant", "desc":"死亡率を下げる。", "cost":7}
}

# 所有している遺伝子カウント（初期は vanilla 多め）
var gene_counts: Dictionary = {"vanilla": 50}
var shop_genes: Array[String] = []    # 現在の売り場（kind の配列）
var gold: int = 50

func _ready() -> void:
    _gen_shop()
    emit_signal("gene_pool_changed")
    emit_signal("gold_changed", gold)

# UI が呼ぶ：遺伝子情報を返す
func get_gene_info(kind: String) -> Dictionary:
    return gene_defs.get(kind, {})

# UI が呼ぶ：現在の遺伝子カウントを返す（コピー）
func get_gene_counts() -> Dictionary:
    return gene_counts.duplicate()

# UI が呼ぶ：色を返す（単純実装）
func get_kind_color(kind: String) -> Color:
    match kind:
        "vanilla": return Color(1,1,1)
        "fastdivide": return Color(0.6,1,0.6)
        "resistant": return Color(1,0.8,0.6)
        _: return Color(0.8,0.8,0.8)

# 購入処理（UI から index で呼ばれる）
func buy_gene(idx: int) -> bool:
    if idx < 0 or idx >= shop_genes.size():
        return false
    var kind: String = shop_genes[idx]
    var info := get_gene_info(kind)
    var cost := int(info.get("cost", 1))
    if gold < cost:
        return false
    gold -= cost
    gene_counts[kind] = int(gene_counts.get(kind, 0)) + 1
    emit_signal("gold_changed", gold)
    emit_signal("gene_pool_changed")
    # ショップ更新（例：購入で補充）
    _gen_shop()
    emit_signal("shop_changed", shop_genes)
    return true

# 複製 / 削除（UI のボタン用）
func duplicate_gene(kind: String) -> void:
    gene_counts[kind] = int(gene_counts.get(kind, 0)) + 1
    emit_signal("gene_pool_changed")

func remove_gene(kind: String) -> void:
    var n := int(gene_counts.get(kind, 0))
    if n > 0:
        gene_counts[kind] = n - 1
        emit_signal("gene_pool_changed")

# ショップ生成（ランダム）
func _gen_shop() -> void:
    var keys := gene_defs.keys()
    # 重複を避けつつランダムに3つ選ぶ（vanilla を混ぜるかは自由）
    shop_genes.clear()
    var pool := keys.duplicate()
    pool.shuffle()
    for i in range(3):
        if i < pool.size():
            shop_genes.append(pool[i])
    emit_signal("shop_changed", shop_genes)

# （ゲーム本体が呼ぶ）遺伝子の効果を Board や Cell に反映するためのフック例
# 実際の効果適用は遊び方に合わせて拡張してください
func apply_effects_to_cell(cell: Node) -> void:
    # 例: fastdivide を持っていれば分裂確率を上げるなど
    # cell 側で期待するプロパティ／メソッドに合わせて実装する
    if int(gene_counts.get("fastdivide", 0)) > 0:
        if cell.has_method("modify_reproduction_rate"):
            cell.call("modify_reproduction_rate", 1.2)
    if int(gene_counts.get("resistant", 0)) > 0:
        if cell.has_method("modify_death_chance"):
            cell.call("modify_death_chance", 0.8)