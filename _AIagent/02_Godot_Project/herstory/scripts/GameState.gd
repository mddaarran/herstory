extends Node
## GameState：全局唯一状态容器（autoload）
## 负责：显式 State、隐藏数值、种子随机数与数值结算
##
## 显式 State 字段在 UI 上以"财政 / GDP / 人口 / 军力 / 领土"显示
## 隐藏数值不显示精确数字，只以区间文本反馈（HIDDEN_META.bands）

# ---------- 显式 State ----------
var treasury: int = 0           # 财政（万两）
var population: int = 0         # 人口（千）
var gdp: int = 0                # GDP
var military: int = 0           # 军力
var territory: int = 0          # 领土

## 5 个公开资产值的显示名与固定顺序 —— 卡片（目标行 / 趋势标签）唯一数据源。
## 注：Sidebar.gd、GoalSelectPage.gd、Main.gd、Main_legacy.gd 内各有一份历史副本，
##     本次未一并收敛，新增代码一律从这里取。
const ASSET_LABELS := {
	"treasury": "财政",
	"gdp": "GDP",
	"population": "人口",
	"military": "军力",
	"territory": "领土",
}
const ASSET_ORDER := ["treasury", "gdp", "population", "military", "territory"]

const STATE_CONFIG_PATH := "res://data/state_config.json"
const MAJOR_EVENTS_PATH := "res://data/major_events.json"
var STATE_CONFIG: Dictionary = {}

## 预言正文（全局唯一，不随君主目标改变）。
## 唯一数据源 = data/major_events.json 的 prophecy 字段（主策划案 6.4），UI 不再另存副本。
var prophecy_text: String = ""
var selected_goal_id: String = ""
var selected_goal: Dictionary = {}

# ---------- 隐藏数值（不显示精确数字，只给区间文本） ----------
var civilian_support: int = 55  # 平民支持度
var noble_support: int = 50     # 旧姓支持度
var radiation_risk: int = 20    # 土地辐射风险
var plague_progress: int = 0    # 火穗锈病进度 0-10（2026-09-02 由 0-3 改为 0-10）
var agrarian_support: int = 50  # 德墨忒尔农业支持度
var guild_support: int = 50     # 同业公会支持度
var fuel_reserve: int = 400     # 火籽储备（库存量）
var wealth_gap: int = 40        # 贫富差距（越高越糟）
var literacy_rate: int = 20     # 识字率
var female_literacy: int = 8    # 女性识字率
var legitimacy: int = 50        # 女帝合法性
var labor_health: int = 60      # 劳工健康
var female_support: int = 45    # 女子支持率
var technology: int = 20        # 科技水平（2026-09-03 新增：Excel 全量表 Z 列，初值待主策回填）

## 锈病进度上限（2026-09-02：由 3 改为 10）
const PLAGUE_CAP := 10

# ---------- 隐藏数值元数据：区间 / 初值 / 四档区间文本（低 → 高） ----------
## 注意：Excel State词典的初值与上下限仍标"待定"，以下为 Demo 暂用值，待主策回填。
var HIDDEN_META: Dictionary = {
	"civilian_support": {"cn": "民间",     "min": 0, "max": 100, "init": 55,
		"bands": ["民怨沸腾", "民间观望", "民众基本支持", "万民归心"]},
	"noble_support":    {"cn": "旧姓",     "min": 0, "max": 100, "init": 50,
		"bands": ["旧姓准备抵制", "旧姓暂时观望", "旧姓愿意配合", "旧姓倾力相助"]},
	"radiation_risk":   {"cn": "土地",     "min": 0, "max": 100, "init": 20,
		"bands": ["土地状况稳定", "田地出现疲态", "辐射风险明显", "土地接近崩溃"]},
	"plague_progress":  {"cn": "锈病",     "min": 0, "max": PLAGUE_CAP, "init": 0,
		"bands": ["无锈病征兆", "零星锈斑", "锈病蔓延", "锈病失控"]},
	"agrarian_support": {"cn": "DM农业", "min": 0, "max": 100, "init": 50,
		"bands": ["DM农业抗命", "DM农业观望", "DM农业配合", "DM农业鼎力"]},
	"guild_support":    {"cn": "同业公会", "min": 0, "max": 100, "init": 50,
		"bands": ["同业公会抵制", "同业公会观望", "同业公会配合", "同业公会鼎力"]},
	"fuel_reserve":     {"cn": "火籽储备", "min": 0, "max": 999, "init": 400,
		"bands": ["火籽见底", "火籽偏紧", "火籽充足", "火籽充盈"]},
	"wealth_gap":       {"cn": "贫富差距", "min": 0, "max": 100, "init": 40,
		"bands": ["贫富尚均", "贫富渐分", "贫富悬殊", "贫富断裂"]},
	"literacy_rate":    {"cn": "识字率",   "min": 0, "max": 100, "init": 20,
		"bands": ["识字者寥寥", "识字者渐多", "识字者过半", "识字成风"]},
	"female_literacy":  {"cn": "女识字率", "min": 0, "max": 100, "init": 8,
		"bands": ["女子几不识字", "女子识字渐开", "女子识字过半", "女子识字成风"]},
	"legitimacy":       {"cn": "合法性",   "min": 0, "max": 100, "init": 50,
		"bands": ["合法性动摇", "合法性待考", "合法性稳固", "合法性与日俱增"]},
	"labor_health":     {"cn": "劳工健康", "min": 0, "max": 100, "init": 60,
		"bands": ["劳工病骨支离", "劳工健康堪忧", "劳工尚可支撑", "劳工身强体健"]},
	"female_support":   {"cn": "女子",     "min": 0, "max": 100, "init": 45,
		"bands": ["女子失望", "女子观望", "女子感念", "女子归心"]},
	"technology":       {"cn": "技艺",     "min": 0, "max": 100, "init": 20,
		"bands": ["工艺粗疏", "匠作渐精", "工艺可观", "百工竞巧"]},
}

# ---------- 帝王能力（建卡提供修正；事件方案只声明用哪种能力） ----------
const DEFAULT_ABILITY_MOD := {
	"insight": 0,      # 洞察
	"influence": 0,    # 驭人（英文 ID 与 events.json 对齐，原名 persuasion 已废弃）
	"majesty": 0,      # 威仪
}

## 能力等级上限。建卡只发 2 点，剩余靠危机成长累积至此上限。
## 本常量是能力上限的**唯一来源**，CharacterBuildPage.gd 直接引用它（不再另存副本）。
const ABILITY_CAP := 10

# 本局由建卡页面确定的能力修正。事件判定只读取这里的运行时值。
var ability_modifiers: Dictionary = DEFAULT_ABILITY_MOD.duplicate()
## 危机成功后获得的成长点。当前沿用建卡结构，自动加到本次危机使用的能力。
var ability_points: int = 0

# ---------- 回合与随机 ----------
var round_number: int = 1
var use_fixed_seed: bool = false   # 测试模式：固定种子可复现
var fixed_seed: int = 42
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_load_state_config()
	_load_prophecy()
	reset()
	if use_fixed_seed:
		rng.seed = fixed_seed

## 预言正文：唯一数据源 = major_events.json 的 prophecy 字段（主策划案 6.4）。
## 读取失败时保留空串，由展示方兜底，不阻塞启动。
func _load_prophecy() -> void:
	var file := FileAccess.open(MAJOR_EVENTS_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取 Major 事件配置: " + MAJOR_EVENTS_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Major 事件配置格式错误: " + MAJOR_EVENTS_PATH)
		return
	prophecy_text = str(parsed.get("prophecy", ""))

func _load_state_config() -> void:
	var file := FileAccess.open(STATE_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("无法读取 State 配置: " + STATE_CONFIG_PATH)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("State 配置格式错误: " + STATE_CONFIG_PATH)
		return
	STATE_CONFIG = parsed
	for key in STATE_CONFIG:
		var meta: Dictionary = STATE_CONFIG[key]
		if HIDDEN_META.has(key):
			var merged: Dictionary = HIDDEN_META[key].duplicate()
			merged["min"] = int(meta.get("min", merged.get("min", 0)))
			merged["max"] = int(meta.get("max", merged.get("max", 100)))
			merged["init"] = int(meta.get("initial", merged.get("init", 0)))
			HIDDEN_META[key] = merged
		else:
			_set_visible_initial(key, int(meta.get("initial", 0)))

func _set_visible_initial(key: String, value: int) -> void:
	match key:
		"treasury": treasury = value
		"population": population = value
		"gdp": gdp = value
		"military": military = value
		"territory": territory = value

func roll_d6() -> int:
	return rng.randi_range(1, 6)

## 一次性投两枚 d6
func roll_2d6() -> Array:
	return [roll_d6(), roll_d6()]

## 取某个隐藏数值的当前值（key 不在表里时返回 0）
func hidden_value(key: String) -> int:
	match key:
		"civilian_support": return civilian_support
		"noble_support": return noble_support
		"radiation_risk": return radiation_risk
		"plague_progress": return plague_progress
		"agrarian_support": return agrarian_support
		"guild_support": return guild_support
		"fuel_reserve": return fuel_reserve
		"wealth_gap": return wealth_gap
		"literacy_rate": return literacy_rate
		"female_literacy": return female_literacy
		"legitimacy": return legitimacy
		"labor_health": return labor_health
		"female_support": return female_support
		"technology": return technology
	return 0

## 统一数值结算入口；key 不存在时忽略
func apply_effects(effects: Dictionary) -> void:
	for key in effects:
		var v: int = int(effects[key])
		match key:
			"treasury", "population", "gdp", "military", "territory":
				_set_visible_effect(key, v)
			_:
				# 其余一律按隐藏数值处理，区间取自 HIDDEN_META
				if HIDDEN_META.has(key):
					set_hidden(key, hidden_value(key) + v)

## 按 HIDDEN_META 的区间写回某个隐藏数值
func set_hidden(key: String, value: int) -> void:
	var meta: Dictionary = HIDDEN_META.get(key, {})
	if meta.is_empty():
		return
	var v: int = clampi(value, int(meta["min"]), int(meta["max"]))
	match key:
		"civilian_support": civilian_support = v
		"noble_support": noble_support = v
		"radiation_risk": radiation_risk = v
		"plague_progress": plague_progress = v
		"agrarian_support": agrarian_support = v
		"guild_support": guild_support = v
		"fuel_reserve": fuel_reserve = v
		"wealth_gap": wealth_gap = v
		"literacy_rate": literacy_rate = v
		"female_literacy": female_literacy = v
		"legitimacy": legitimacy = v
		"labor_health": labor_health = v
		"female_support": female_support = v
		"technology": technology = v

func _set_visible_effect(key: String, delta: int) -> void:
	var meta: Dictionary = STATE_CONFIG.get(key, {})
	var lo := int(meta.get("min", 0))
	var hi := int(meta.get("max", 99999))
	match key:
		"treasury": treasury = clampi(treasury + delta, lo, hi)
		"population": population = clampi(population + delta, lo, hi)
		"gdp": gdp = clampi(gdp + delta, lo, hi)
		"military": military = clampi(military + delta, lo, hi)
		"territory": territory = clampi(territory + delta, lo, hi)

func reset() -> void:
	_set_visible_initial("treasury", int(STATE_CONFIG.get("treasury", {}).get("initial", 800)))
	_set_visible_initial("population", int(STATE_CONFIG.get("population", {}).get("initial", 1200)))
	_set_visible_initial("gdp", int(STATE_CONFIG.get("gdp", {}).get("initial", 950)))
	_set_visible_initial("military", int(STATE_CONFIG.get("military", {}).get("initial", 9816)))
	_set_visible_initial("territory", int(STATE_CONFIG.get("territory", {}).get("initial", 96000)))
	for key in HIDDEN_META:
		set_hidden(key, int(HIDDEN_META[key]["init"]))
	round_number = 1
	ability_modifiers = DEFAULT_ABILITY_MOD.duplicate()
	ability_points = 0

# ---------- 隐藏数值 -> 文本区间（不显示数字） ----------

## 通用区间文本：按 HIDDEN_META.bands 四档切分
func tier_text(state_key: String) -> String:
	var meta: Dictionary = HIDDEN_META.get(state_key, {})
	if meta.is_empty():
		return ""
	var bands: Array = meta["bands"]
	var lo: float = float(meta["min"])
	var hi: float = float(meta["max"])
	var ratio: float = 0.0
	if hi > lo:
		ratio = (float(hidden_value(state_key)) - lo) / (hi - lo)
	var idx: int = 0
	if ratio >= 0.80:
		idx = 3
	elif ratio >= 0.60:
		idx = 2
	elif ratio >= 0.30:
		idx = 1
	return str(bands[clampi(idx, 0, bands.size() - 1)])

func civilian_tier_text() -> String:
	return tier_text("civilian_support")

func noble_tier_text() -> String:
	return tier_text("noble_support")

func radiation_tier_text() -> String:
	return tier_text("radiation_risk")

## 火穗锈病前兆文本（进度数字隐藏，只给文本征兆）
## 阈值按 0-10 的进度条标定
func blight_omen_text() -> String:
	if plague_progress >= 7: return "火籽炉接连停转，火穗收割量骤减。"
	if plague_progress >= 4: return "多处火穗田的灰白斑块连成了片，风一过就落一层灰。"
	if plague_progress >= 2: return "个别火穗田的火穗长势不对，灰白斑块时隐时现。"
	return ""

## 隐藏数值摘要（UI 状态区用）
func hidden_summary() -> String:
	return "民间：%s ｜ 旧姓：%s ｜ 土地：%s" % [
		civilian_tier_text(), noble_tier_text(), radiation_tier_text()]
