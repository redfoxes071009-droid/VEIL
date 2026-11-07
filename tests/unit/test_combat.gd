extends "res://tests/test_case.gd"
## 전투 단위 테스트. CombatWorld 를 트리 밖에서 만들어 simulate() 로 직접 진행합니다.


func _world() -> CombatWorld:
	var w := CombatWorld.new()
	w.auto_process = false
	w.setup_stage({}, 12345)
	return w


func _free(w: CombatWorld) -> void:
	w.free()


func _enemy(w: CombatWorld, kind: StringName = &"bite_mutant") -> Unit:
	for e in w.enemies():
		if e.enemy_kind == kind:
			return e
	return null


func _run(w: CombatWorld, seconds: float, step: float = 1.0 / 30.0) -> void:
	var t := 0.0
	while t < seconds and w.state == CombatWorld.State.RUNNING:
		w.simulate(step)
		t += step


func test_party_and_enemies_spawn() -> void:
	var w := _world()
	check_eq(w.party.size(), 4, "파티 4명 (J·라·스테이지·페이즈)")
	check_eq(w.leader.data.id, &"j", "J가 리더")
	check(w.leader.controlled, "J는 직접 조작")
	check_eq(w.enemies().size(), 7, "적 7기")
	check_eq(w.party[1].data.role, CharacterData.Role.TANK, "라 = 탱커")
	check_eq(w.party[2].data.role, CharacterData.Role.DEALER, "스테이지 = 딜러")
	check_eq(w.leader.data.role, CharacterData.Role.DEALER, "J = 딜러")
	_free(w)


func test_defense_reduces_damage_and_ignore_def() -> void:
	var w := _world()
	var j := w.leader
	var e := _enemy(w)
	j.crit_rate = 0.0
	var hp0 := e.hp
	var normal := w.deal_damage(j, e, 1.0, {"no_contam": true})
	var pierced := w.deal_damage(j, e, 1.0, {"no_contam": true, "ignore_def": true})
	check(pierced > normal * 1.2, "방어 무시 피해가 더 큼 (%d vs %d)" % [pierced, normal])
	check(e.hp < hp0, "적 HP 감소")
	_free(w)


func test_ult_requires_full_contamination_and_cooldown() -> void:
	var w := _world()
	var j := w.leader
	j.target = _enemy(w)
	check(not j.use_ult(), "오염도 0이면 궁극기 불가")
	j.contamination = 100.0
	check(j.use_ult(j.target.position), "오염도 100이면 사용")
	check_eq(j.contamination, 0.0, "사용 후 오염도 0")
	check_eq(j.ult_cd, j.data.ult_cooldown, "PDF 쿨타임 적용 (7초)")
	j.contamination = 100.0
	check(not j.use_ult(), "쿨타임 중에는 불가")
	_free(w)


func test_contamination_gain() -> void:
	var w := _world()
	var j := w.leader
	var e := _enemy(w)
	w.deal_damage(j, e, 1.0)
	check(j.contamination > 0.0, "피해를 주면 오염도 증가")
	var ra := w.party[1]
	w.deal_damage(e, ra, 1.0)
	check_eq(ra.contamination, CombatWorld.CONTAM_HIT_TANK, "탱커는 맞을 때 더 많이 충전")
	_free(w)


func test_j_skill_costs_hp_and_stealth() -> void:
	var w := _world()
	var j := w.leader
	var hp0 := j.hp
	check(j.use_skill(true, j.position + Vector2(10, 0)), "생명의 대가 (길게)")
	check(is_equal_approx(j.hp, hp0 * 0.85), "현재 HP 15% 소모")
	check(j.has_status(Status.STEALTH), "은신 상태")
	check(not j.is_targetable(), "은신 중 타겟 불가")
	check_eq(j.attack_range(), j.base_range + 60.0, "은신 사거리 +15m(60px)")
	check_eq(j.effective_crit_rate(), j.crit_rate + 20.0, "은신 치명타 +20%")
	check(j.kit.basic_bonus_flat() > 0.0, "은신 기본 공격 추가 피해")
	check(j.use_skill(false), "짧게 누르면 조기 종료")
	check(not j.has_status(Status.STEALTH), "은신 해제")
	_free(w)


func test_j_dash_hits_enemies_on_path() -> void:
	var w := _world()
	var j := w.leader
	var e := _enemy(w)
	j.position = e.position - Vector2(30, 0)
	var hp0 := e.hp
	j.use_skill(false, e.position + Vector2(40, 0))
	check(e.hp < hp0, "짧게: 경로의 적에게 가시 피해")
	_free(w)


func test_j_ult_roots_center_and_enters_stealth() -> void:
	var w := _world()
	var j := w.leader
	var e := _enemy(w, &"bite_brute")
	j.position = e.position - Vector2(60, 0)
	j.contamination = 100.0
	j.use_ult(e.position)
	check(e.has_status(Status.ROOT), "중심부 적 속박")
	check_eq(e.move_speed(), 0.0, "속박 중 이동 불가")
	check(j.has_status(Status.STEALTH), "발동 후 그림자 장막")
	_free(w)


func test_stage_combo_stacks_and_cracking() -> void:
	var w := _world()
	var st := w.party[2]
	var e := _enemy(w, &"bite_brute")
	st.position = e.position - Vector2(60, 0)
	st.target = e
	check(st.use_skill(), "콤보! 발동")
	for i in 40:
		st.kit.tick(1.0 / 30.0)
	check_eq(st.kit.combo, 5, "5연발 적중 → 콤보 5")
	check(is_equal_approx(st.attack_speed_mult(), 1.25), "콤보당 공속 +5% (최대 +25%)")
	check(st.has_status(Status.CONDUCT_BONUS), "전도 피해 보너스")
	check(is_equal_approx(st.kit.damage_mult(CharacterData.Element.CONDUCT), 1.2), "전도 피해 +20%")
	var hp0 := e.hp
	st.contamination = 100.0
	check(st.use_ult(), "크래킹 발동")
	check(e.hp < hp0, "광역 전도 피해 + 픽셀 폭발")
	check_eq(st.kit.combo, 0, "스택 모두 소모")
	_free(w)


func test_stage_combo_expires() -> void:
	var w := _world()
	var st := w.party[2]
	st.kit.combo = 3
	st.kit.combo_t = 5.0
	st.kit.tick(5.1)
	check_eq(st.kit.combo, 0, "5초 지나면 콤보 소멸")
	_free(w)


func test_ra_twin_spears_and_blind() -> void:
	var w := _world()
	var ra := w.party[1]
	var e := _enemy(w, &"bite_brute")
	ra.position = e.position - Vector2(40, 0)
	ra.use_skill(false, e.position)
	for i in 20:
		ra.kit.tick(1.0 / 30.0)
	check(ra.has_status(Status.TWIN_SPEARS), "쌍창 전환")
	check(is_equal_approx(ra.attack_speed_mult(), 1.2), "공속 +20%")
	check(is_equal_approx(ra.move_speed(), ra.base_move * 1.15), "이속 +15%")
	check(is_equal_approx(ra.def(), ra.base_def * 0.85), "방어 -15%")
	check(e.has_status(Status.BLIND), "광휘 창 적중 → 실명")
	_free(w)


func test_ra_judgement_revives_and_heals() -> void:
	var w := _world()
	var ra := w.party[1]
	var st := w.party[2]
	st.hp = st.max_hp * 0.2
	ra.take_damage(ra.max_hp * 10)
	check(not ra.alive, "라 쓰러짐")
	ra.contamination = 100.0
	check(ra.can_use_ult(), "쓰러져도 심판의 날 사용 가능")
	check(ra.use_ult(), "심판의 날")
	check(ra.alive and is_equal_approx(ra.hp, ra.max_hp * 0.5), "최대 체력 50%로 부활")
	check(is_equal_approx(st.hp, st.max_hp * (0.2 + 0.306)), "아군 최대 HP 30.6% 회복")
	check(ra.has_status(Status.JUDGEMENT), "공격력 +25% 버프")
	check(is_equal_approx(ra.atk(), ra.base_atk * 1.25), "공격력 +25%")
	_free(w)


func test_ra_auto_revive_when_downed() -> void:
	var w := _world()
	var ra := w.party[1]
	ra.contamination = 100.0
	ra.take_damage(ra.max_hp * 10)
	for i in 40:
		ra.tick(1.0 / 30.0)
	check(ra.alive, "쓰러진 뒤 1초 후 자동 부활 (AI)")
	_free(w)


func test_phase_lightspeed_resets_cooldown() -> void:
	var w := _world()
	var ph := w.party[3]
	ph.use_skill(false, ph.position + Vector2(10, 0))
	check(ph.has_status(Status.LIGHTSPEED), "차원 개방 → 광속 질주")
	check(ph.skill_cd > 0.0, "쿨다운 시작")
	ph.skill_cd = 0.0
	ph.use_skill(false, ph.position + Vector2(10, 0))
	check_eq(ph.skill_cd, 0.0, "광속 질주 중 재사용 → 쿨다운 초기화")
	check(not ph.has_status(Status.LIGHTSPEED), "광속 질주 소모")
	_free(w)


func test_phase_sprint_buffs_allies_and_drains_portal() -> void:
	var w := _world()
	var ph := w.party[3]
	var e := _enemy(w)
	ph.position = e.position - Vector2(20, 0)
	ph.kit.portal = 9.0
	ph.contamination = 100.0
	check(ph.use_ult(), "차원 질주 발동")
	ph.kit.tick(0.1)
	check(w.leader.has_status(Status.HASTE), "아군 이속·공속 버프")
	check(e.has_status(Status.RESIST_DOWN), "주변 적 내성 감소")
	for i in 40:
		ph.kit.tick(0.1)
	check_eq(ph.kit.portal, 0.0, "포털 게이지 초당 3pt 소모 → 0")
	check(not ph.has_status(Status.SPRINT), "게이지가 없으면 질주 종료")
	_free(w)


func test_blind_can_miss() -> void:
	var w := _world()
	var e := _enemy(w)
	e.add_status(Status.BLIND, 10.0)
	var misses := 0
	for i in 40:
		if w.deal_damage(e, w.party[1], 1.0) == 0.0:
			misses += 1
	check(misses > 5 and misses < 35, "실명 시 약 50% 빗나감 (%d/40)" % misses)
	_free(w)


func test_terminal_opens_exit_and_win() -> void:
	var w := _world()
	var j := w.leader
	for e in w.enemies():
		e.take_damage(1e9)
	j.position = w.terminal_pos + Vector2(0, 14)
	check(w.interact(j), "단말 조사")
	check(w.terminal_done, "출구 개방")
	j.position = w.exit_rect.get_center()
	w.simulate(0.016)
	check_eq(w.state, CombatWorld.State.WON, "출구 도착 → 승리")
	_free(w)


func test_leader_down_is_defeat() -> void:
	var w := _world()
	w.leader.take_damage(1e9)
	check_eq(w.state, CombatWorld.State.LOST, "J가 쓰러지면 패배")
	_free(w)


## J까지 AI로 돌려 전투가 끝까지 진행되는지 확인 (밸런스·멈춤 검사).
func test_ai_battle_clears_enemies() -> void:
	var w := _world()
	for u in w.party:
		u.controlled = false
		u.auto_skills = true
	_run(w, 90.0)
	check(w.leader.alive, "J 생존")
	check_eq(w.enemies().size(), 0, "90초 안에 적 전멸 (남은 적 %d)" % w.enemies().size())
	_free(w)
