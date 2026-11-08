extends "res://tests/test_case.gd"
## 세이브 · 육성 · 모집 · 상점 · 배틀패스 · 파견 · 우편 단위 테스트.

const SaveScript := preload("res://scripts/systems/save_manager.gd")
const PATH := "user://test_unit_save.json"

var _t := 1_000_000


func _make() -> Node:
	var s: Node = SaveScript.new()
	s.path = PATH
	s.clock = func() -> int: return _t
	s.delete_save()
	s.new_game()
	return s


func _done(s: Node) -> void:
	s.delete_save()
	s.free()


func test_new_game_defaults() -> void:
	var s := _make()
	for id in Progression.ROSTER:
		check_eq(s.char_level(id), Progression.START_LEVEL, "시작 레벨 30: %s" % id)
	check_eq(s.get_currency("energy"), 120, "시작 에너지 120")
	_done(s)


func test_save_load_roundtrip_and_backup_recovery() -> void:
	var s := _make()
	s.add_currency("credit", 777)
	var credit: int = s.get_currency("credit")
	var b: Node = SaveScript.new()
	b.path = PATH
	b.clock = s.clock
	check(b.load_game(), "불러오기")
	check_eq(b.get_currency("credit"), credit, "크레딧 유지")
	# 본 파일 손상 → .bak 복구
	s.add_currency("credit", 1)
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{손상된 JSON")
	f.close()
	var c: Node = SaveScript.new()
	c.path = PATH
	c.clock = s.clock
	check(c.load_game(), "손상 시 백업에서 복구")
	check_eq(c.get_currency("credit"), credit, "백업 시점 값")
	b.free()
	c.free()
	_done(s)


func test_migration_fills_missing_fields() -> void:
	var s := _make()
	s.data.erase("battlepass")
	s.data.characters.erase("phase")
	s.save_game()
	var b: Node = SaveScript.new()
	b.path = PATH
	b.clock = s.clock
	check(b.load_game(), "빠진 항목이 있어도 불러오기")
	check(b.data.has("battlepass"), "배틀패스 기본값 채움")
	check(b.data.characters.has("phase"), "캐릭터 기본값 채움")
	b.free()
	_done(s)


func test_energy_regen() -> void:
	var s := _make()
	check(s.spend("energy", 100), "에너지 사용")
	_t += SaveScript.ENERGY_REGEN_SEC * 5 + 10
	check_eq(s.get_currency("energy"), 25, "6분마다 1 회복 (5)")
	_t += 999999
	check_eq(s.get_currency("energy"), SaveScript.ENERGY_MAX, "최대 240")
	_done(s)


func test_level_and_breakthrough() -> void:
	var s := _make()
	s.add_currency("credit", 10_000_000)
	for i in 40:
		s.level_up(&"ra")
	check_eq(s.char_level(&"ra"), 60, "돌파 0단계 상한 60")
	check_eq(s.level_up(&"ra"), "cap", "상한에서 레벨업 불가")
	check_eq(s.break_through(&"ra"), "shards", "조각 부족")
	s.add_shards(&"ra", 10)
	check_eq(s.break_through(&"ra"), "", "돌파 성공")
	check_eq(int(s.char_state(&"ra").break), 1, "돌파 1단계")
	check_eq(s.level_up(&"ra"), "", "상한 70으로 증가")
	check(Progression.stat_at(Progression.load_character(&"j"), "atk", 90) == 5746.0, "PDF 기준 레벨 수치 일치 (J Lv90 공격력 5746)")
	_done(s)


func test_gacha_cost_and_pity() -> void:
	var s := _make()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	check(Gacha.pull(s, 1, rng).is_empty(), "크리스탈 없으면 모집 불가")
	s.add_currency("crystal", Gacha.COST_TEN * 6)
	var fives := 0
	for i in 5:
		for r in Gacha.pull(s, 10, rng):
			if r.rarity == 5:
				fives += 1
	check(fives >= 1, "50회 안에 ★5 최소 1회 (%d)" % fives)
	check_eq(s.get_currency("crystal"), Gacha.COST_TEN, "10회 = 1600 크리스탈")
	var forced := Gacha.roll_once(rng, Gacha.PITY - 1)
	check_eq(forced.rarity, 5, "천장 도달 시 ★5 확정")
	_done(s)


func test_shop_daily_and_pick_shards() -> void:
	var s := _make()
	var daily: Dictionary = OfflineContent.SHOP[0]
	check_eq(OfflineContent.buy(s, daily), "", "일일 무료 보급")
	check_eq(OfflineContent.buy(s, daily), "sold_out", "하루 1회")
	_t += 86400
	check_eq(OfflineContent.buy(s, daily), "", "다음 날 다시 가능")
	var shard_item: Dictionary = OfflineContent.SHOP[3]
	var shards0 := int(s.char_state(&"phase").shards)
	check_eq(OfflineContent.buy(s, shard_item, &"phase"), "", "선택 조각 구매")
	check_eq(int(s.char_state(&"phase").shards), shards0 + 5, "선택한 캐릭터에 조각 +5")
	_done(s)


func test_battlepass_and_stage_clear() -> void:
	var s := _make()
	check_eq(OfflineContent.bp_claim(s, 0), "locked", "경험치 없으면 잠김")
	var r: Dictionary = s.clear_stage("1-1")
	check(r.first_clear, "첫 클리어")
	check_eq(int(r.crystal), 190, "첫 클리어 크리스탈 30+160")
	s.clear_stage("1-1")
	check_eq(OfflineContent.bp_tier(s), 1, "패스 경험치 120 → 1단계")
	check_eq(OfflineContent.bp_claim(s, 0), "", "1단계 보상")
	check_eq(OfflineContent.bp_claim(s, 0), "claimed", "중복 수령 불가")
	_done(s)


func test_dispatch_and_mail() -> void:
	var s := _make()
	var m: Dictionary = OfflineContent.DISPATCH[0]
	check_eq(OfflineContent.dispatch_start(s, m, &"stage"), "", "파견 시작")
	check_eq(OfflineContent.dispatch_start(s, OfflineContent.DISPATCH[1], &"stage"), "busy", "같은 캐릭터 중복 파견 불가")
	check_eq(OfflineContent.dispatch_collect(s, m), "running", "시간 전 수령 불가")
	_t += int(m.seconds)
	var c0: int = s.get_currency("credit")
	check_eq(OfflineContent.dispatch_collect(s, m), "", "완료 후 수령")
	check_eq(s.get_currency("credit"), c0 + 8000, "파견 보상")
	check_eq(OfflineContent.unread_mail(s), 2, "우편 2통")
	OfflineContent.mail_claim(s, OfflineContent.MAIL[1])
	check_eq(OfflineContent.unread_mail(s), 1, "받은 우편은 읽음")
	_done(s)


func test_story_stage_defs() -> void:
	var s := _make()
	check_eq(StageDefs.STAGES.size(), 7, "스토리 맵 노드 7개")
	check(not StageDefs.is_battle("R1-1"), "R1-1 기록 노드는 전투 없음")
	check(StageDefs.is_unlocked(s, "1-1"), "1-1 처음부터 열림")
	check(not StageDefs.is_unlocked(s, "1-2"), "1-2 잠김")
	check_eq(StageDefs.missing_requirements(s, "1-2"), ["1-1"], "1-2 조건 1-1")
	check(not StageDefs.is_unlocked(s, "S1-3"), "S1-3 잠김")
	var e0: int = s.get_currency("energy")
	check(s.start_stage("S1-3"), "S1-3 에너지 소모")
	check_eq(s.get_currency("energy"), e0 - 15, "S1-3 에너지 15")
	var c0: int = s.get_currency("credit")
	var r: Dictionary = s.clear_stage("S1-2")
	check_eq(int(r.credit), int(12000 * 1.6), "S1-2 보상 ×1.6")
	check_eq(s.get_currency("credit"), c0 + int(12000 * 1.6), "S1-2 크레딧 지급")
	check(StageDefs.is_unlocked(s, "S1-3"), "S1-2 클리어 → S1-3 해금")
	check_eq(StageDefs.cleared_count(s), 1, "진행 수 1")
	_done(s)


func test_stage_enemy_scaling() -> void:
	var w := CombatWorld.new()
	w.setup_stage({}, 7, StageDefs.get_def("S1-3"))
	check_eq(w.enemies().size(), 7, "S1-3 적 7체")
	var e: Unit = w.enemies()[0]
	check(is_equal_approx(e.max_hp, EnemyDefs.get_def(e.enemy_kind).hp * 2.0), "S1-3 적 HP ×2")
	w.free()
	var d := CombatWorld.new()
	d.setup_stage({}, 7)
	check_eq(d.enemies().size(), 7, "기본(1-1) 적 7체 유지")
	d.free()
