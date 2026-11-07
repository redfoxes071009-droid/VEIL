class_name Progression
extends RefCounted
## 레벨·돌파·전투력 계산. 수치 공식은 여기 한 곳에서만 관리합니다.

const MAX_LEVEL := 90
const MAX_BREAK := 3
const GROWTH := 0.04  ## 레벨당 HP·공격력·방어력 성장률
const START_LEVEL := 30
const BREAK_SHARDS: Array[int] = [10, 20, 40]
const ROSTER: Array[StringName] = [&"j", &"ra", &"stage", &"phase"]

static var _cache := {}


static func load_character(id: StringName) -> CharacterData:
	if not _cache.has(id):
		_cache[id] = load("res://data/characters/%s.tres" % id)
	return _cache[id]


static func all_characters() -> Array[CharacterData]:
	var out: Array[CharacterData] = []
	for id in ROSTER:
		out.append(load_character(id))
	return out


## 돌파 단계별 레벨 상한: 0단계 60 → 3단계 90.
static func level_cap(breakthrough: int) -> int:
	return mini(60 + 10 * clampi(breakthrough, 0, MAX_BREAK), MAX_LEVEL)


static func level_up_cost(level: int) -> int:
	return 500 + level * 120


static func break_cost(breakthrough: int) -> int:
	return BREAK_SHARDS[breakthrough] if breakthrough < MAX_BREAK else -1


## PDF 화면의 기준 레벨 수치에서 비례 계산합니다.
static func stat_at(data: CharacterData, stat: String, level: int) -> float:
	var ref: float = data.get(stat)
	if stat in ["hp", "atk", "def"]:
		return ref * (1.0 + GROWTH * (level - 1)) / (1.0 + GROWTH * (data.ref_level - 1))
	return ref


static func stats_at(data: CharacterData, level: int) -> Dictionary:
	var s := {}
	for k in ["hp", "atk", "def", "crit_rate", "crit_dmg", "effect_hit"]:
		s[k] = stat_at(data, k, level)
	return s


## 전투력 (표시용 종합 수치).
static func combat_power(data: CharacterData, level: int, breakthrough: int = 0) -> int:
	var s := stats_at(data, level)
	var p: float = s.hp * 0.3 + s.atk * 0.45 + s.def * 0.12 + s.crit_rate * 12.0 + s.crit_dmg * 3.0
	return int(p * (1.0 + 0.05 * breakthrough))


static func player_exp_to_next(level: int) -> int:
	return 300 + level * 150
