extends Node
## 게임 진행 저장 (오토로드: SaveManager). 서버 없이 로컬 JSON 하나에 모든 진행을 저장합니다.
## 저장: user://saves/slot_1.json  · 임시 파일에 쓴 뒤 교체 · 직전 파일은 .bak 로 보관
## 불러오기 실패(손상) 시 .bak 으로 복구를 시도합니다. 구조가 바뀌면 SAVE_VERSION 을 올리고 _migrate 에 단계 추가.

signal changed

const SAVE_VERSION := 1
const DEFAULT_PATH := "user://saves/slot_1.json"
const ENERGY_MAX := 240
const ENERGY_REGEN_SEC := 360
const STAGE_ENERGY := 10
const CURRENCIES := ["credit", "crystal", "energy"]

var path := DEFAULT_PATH
var data: Dictionary = {}
var auto_save := true
## 테스트에서 시간을 고정하기 위해 바꿀 수 있습니다.
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())


func now() -> int:
	return clock.call()


func has_save() -> bool:
	return FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak")


func is_loaded() -> bool:
	return not data.is_empty()


static func default_data(t: int, uid: String) -> Dictionary:
	var chars := {}
	for id in Progression.ROSTER:
		chars[String(id)] = {"level": Progression.START_LEVEL, "break": 0, "shards": 0}
	return {
		"version": SAVE_VERSION,
		"created": t,
		"player": {"name": "PLAYER", "uid": uid, "level": 1, "exp": 0},
		"currency": {"credit": 50000, "crystal": 0, "energy": 120},
		"energy_t": t,
		"characters": chars,
		"lobby_char": "j",
		"story": {"cleared": []},
		"gacha": {"pity": 0, "total": 0},
		"battlepass": {"xp": 0, "claimed": []},
		"dispatch": {},
		"mail_claimed": [],
		"shop": {"daily_day": -1},
	}


func new_game() -> void:
	var uid := "UID-%010d" % (randi() % 10000000000)
	data = default_data(now(), uid)
	_commit()


func load_game() -> bool:
	for p in [path, path + ".bak"]:
		var d = _read(p)
		if d is Dictionary and _validate(d):
			data = _migrate(d)
			if p != path:
				push_warning("세이브 파일 손상: 백업에서 복구했습니다.")
				save_game()
			_regen_energy()
			changed.emit()
			return true
	data = {}
	return false


func save_game() -> Error:
	if data.is_empty():
		return ERR_UNCONFIGURED
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("세이브 쓰기 실패: %s" % error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path)


func delete_save() -> void:
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	data = {}


func _read(p: String):
	if not FileAccess.file_exists(p):
		return null
	var text := FileAccess.get_file_as_string(p)
	return JSON.parse_string(text)


func _validate(d: Dictionary) -> bool:
	for k in ["version", "player", "currency", "characters"]:
		if not d.has(k):
			return false
	if not (d.currency is Dictionary and d.characters is Dictionary and d.player is Dictionary):
		return false
	for c in CURRENCIES:
		if not (d.currency.get(c) is float or d.currency.get(c) is int):
			return false
	return int(d.version) >= 1 and int(d.version) <= SAVE_VERSION


## 버전별 변환. 빠진 항목은 기본값으로 채웁니다.
func _migrate(d: Dictionary) -> Dictionary:
	var base := default_data(now(), str(d.player.get("uid", "UID-0000000000")))
	for k in base:
		if not d.has(k):
			d[k] = base[k]
	for id in Progression.ROSTER:
		if not d.characters.has(String(id)):
			d.characters[String(id)] = base.characters[String(id)]
	d.version = SAVE_VERSION
	return d


func _commit() -> void:
	changed.emit()
	if auto_save:
		save_game()


# ---------- 재화 ----------

func get_currency(c: String) -> int:
	if c == "energy":
		_regen_energy()
	return int(data.currency.get(c, 0))


func add_currency(c: String, amount: int) -> void:
	data.currency[c] = get_currency(c) + amount
	_commit()


func spend(c: String, amount: int) -> bool:
	var before := get_currency(c)
	if before < amount:
		return false
	data.currency[c] = before - amount
	if c == "energy" and before >= ENERGY_MAX:
		data.energy_t = now()  # 가득 찬 상태에서 쓰면 이때부터 회복 시작
	_commit()
	return true


## 에너지는 6분마다 1씩, 최대 240까지 자동 회복합니다.
func _regen_energy() -> void:
	if data.is_empty():
		return
	var e := int(data.currency.energy)
	var t := now()
	if e >= ENERGY_MAX:
		data.energy_t = t
		return
	var gained := (t - int(data.energy_t)) / ENERGY_REGEN_SEC
	if gained > 0:
		data.currency.energy = mini(ENERGY_MAX, e + gained)
		data.energy_t = int(data.energy_t) + gained * ENERGY_REGEN_SEC


func grant(reward: Dictionary) -> void:
	for k in reward:
		if k in CURRENCIES:
			data.currency[k] = get_currency(k) + int(reward[k])
		elif k == "shards":
			for id in reward.shards:
				add_shards(StringName(id), int(reward.shards[id]), false)
		elif k == "player_exp":
			_add_player_exp(int(reward[k]))
		elif k == "bp_xp":
			data.battlepass.xp = int(data.battlepass.xp) + int(reward[k])
	_commit()


func _add_player_exp(v: int) -> void:
	var p: Dictionary = data.player
	p.exp = int(p.exp) + v
	while int(p.exp) >= Progression.player_exp_to_next(int(p.level)):
		p.exp = int(p.exp) - Progression.player_exp_to_next(int(p.level))
		p.level = int(p.level) + 1


# ---------- 캐릭터 ----------

func char_state(id: StringName) -> Dictionary:
	return data.characters[String(id)]


func char_level(id: StringName) -> int:
	return int(char_state(id).level)


func party_levels() -> Dictionary:
	var out := {}
	for id in Progression.ROSTER:
		out[id] = char_level(id)
	return out


func add_shards(id: StringName, n: int, commit: bool = true) -> void:
	var s := char_state(id)
	s.shards = int(s.shards) + n
	if commit:
		_commit()


## 레벨업 1회. 실패 사유: "max", "cap", "credit"
func level_up(id: StringName) -> String:
	var s := char_state(id)
	var lv := int(s.level)
	if lv >= Progression.MAX_LEVEL:
		return "max"
	if lv >= Progression.level_cap(int(s.break)):
		return "cap"
	if not spend("credit", Progression.level_up_cost(lv)):
		return "credit"
	s.level = lv + 1
	_commit()
	return ""


## 돌파. 실패 사유: "max", "level", "shards"
func break_through(id: StringName) -> String:
	var s := char_state(id)
	var b := int(s.break)
	if b >= Progression.MAX_BREAK:
		return "max"
	if int(s.level) < Progression.level_cap(b):
		return "level"
	var cost := Progression.break_cost(b)
	if int(s.shards) < cost:
		return "shards"
	s.shards = int(s.shards) - cost
	s.break = b + 1
	_commit()
	return ""


# ---------- 스토리 ----------

func start_stage(stage_id: String) -> bool:
	return spend("energy", STAGE_ENERGY)


func clear_stage(stage_id: String) -> Dictionary:
	var first: bool = not (stage_id in data.story.cleared)
	var reward := {"credit": 12000, "player_exp": 300, "bp_xp": 60, "crystal": 30}
	if first:
		data.story.cleared.append(stage_id)
		reward.crystal += 160
	grant(reward)
	reward["first_clear"] = first
	return reward
