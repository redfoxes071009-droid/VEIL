class_name CombatWorld
extends Node2D
## 전투 화면 (640×360 픽셀 좌표). 유닛·피해 계산·지형·목표(단말·출구)를 관리합니다.
## 실제 게임에서는 _physics_process 가, 테스트에서는 simulate() 를 직접 호출해 진행합니다.

signal battle_finished(won: bool)
signal message(text_key: String)
signal objective_changed(text_key: String)

const SIZE := Vector2(640, 360)
const DEF_K := 1000.0            ## 방어 공식: 피해 × K / (K + 방어력)
const MISS_CHANCE := 0.5         ## 실명 시 빗나감 확률
const RESIST_DOWN_MULT := 1.2
const CONTAM_BASIC := 3.0
const CONTAM_SKILL := 5.0
const CONTAM_HIT := 3.0
const CONTAM_HIT_TANK := 6.0
const INTERACT_DIST := 22.0

enum State { RUNNING, WON, LOST }

var state := State.RUNNING
var auto_process := true
var units: Array[Unit] = []
var leader: Unit
var party: Array[Unit] = []      ## [J, 라, 스테이지, 페이즈]
var obstacles: Array[Rect2] = []
var terminal_pos := Vector2(430, 80)
var terminal_done := false
var exit_rect := Rect2(606, 150, 26, 60)
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _physics_process(delta: float) -> void:
	if auto_process and state == State.RUNNING and not get_tree().paused:
		simulate(delta)


## 기본 스테이지(프롤로그 1-1) 구성. levels: {id: 레벨}
func setup_stage(levels: Dictionary, seed_value: int = 0) -> void:
	rng.seed = seed_value if seed_value != 0 else randi()
	obstacles = [Rect2(180, 40, 40, 90), Rect2(180, 230, 40, 90), Rect2(360, 140, 50, 30), Rect2(500, 250, 60, 30)]
	var spawn := Vector2(60, 180)
	var order: Array[StringName] = [&"j", &"ra", &"stage", &"phase"]
	for i in order.size():
		var d := Progression.load_character(order[i])
		var u := Unit.new()
		u.setup_character(d, levels.get(order[i], Progression.START_LEVEL), self)
		u.position = spawn + [Vector2(0, 0), Vector2(16, -14), Vector2(-14, 16), Vector2(-10, -18)][i]
		if i == 0:
			u.controlled = true
			leader = u
		u.brain = UnitBrain.for_ally(maxi(0, i - 1))
		_add_unit(u)
		party.append(u)
	# 1구역: 변이체 3 + 사수 1
	for p in [Vector2(270, 150), Vector2(285, 200), Vector2(300, 175)]:
		_spawn_enemy(&"bite_mutant", p)
	_spawn_enemy(&"bite_gunner", Vector2(330, 120))
	# 2구역(단말): 브루트 1 + 사수 2
	_spawn_enemy(&"bite_brute", Vector2(470, 110))
	_spawn_enemy(&"bite_gunner", Vector2(520, 70))
	_spawn_enemy(&"bite_gunner", Vector2(510, 200))
	objective_changed.emit("OBJ_TERMINAL")


func _spawn_enemy(kind: StringName, p: Vector2) -> Unit:
	var e := Unit.new()
	e.setup_enemy(kind, self)
	e.position = p
	e.brain = UnitBrain.for_enemy()
	_add_unit(e)
	return e


func _add_unit(u: Unit) -> void:
	units.append(u)
	add_child(u)
	u.died.connect(_on_unit_died)


func simulate(delta: float) -> void:
	if state != State.RUNNING:
		return
	for u in units:
		u.tick(delta)
	_separate()
	if leader and leader.alive and terminal_done and exit_rect.has_point(leader.position):
		_finish(true)


func _on_unit_died(u: Unit) -> void:
	if u == leader:
		message.emit("MSG_LEADER_DOWN")
		_finish(false)


func _finish(won: bool) -> void:
	if state != State.RUNNING:
		return
	state = State.WON if won else State.LOST
	battle_finished.emit(won)


# ---------- 조회 ----------

func allies() -> Array[Unit]:
	return party


func enemies() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in units:
		if u.team == Unit.Team.ENEMY and u.alive:
			out.append(u)
	return out


func enemies_in_radius(p: Vector2, r: float) -> Array[Unit]:
	var out: Array[Unit] = []
	for e in enemies():
		if e.position.distance_to(p) <= r + e.radius:
			out.append(e)
	return out


func enemies_near_segment(a: Vector2, b: Vector2, half_width: float) -> Array[Unit]:
	var out: Array[Unit] = []
	for e in enemies():
		var q := Geometry2D.get_closest_point_to_segment(e.position, a, b)
		if q.distance_to(e.position) <= half_width + e.radius:
			out.append(e)
	return out


func nearest_enemy(u: Unit, max_dist: float) -> Unit:
	return nearest_enemy_to_point(u.position, max_dist)


func nearest_enemy_to_point(p: Vector2, max_dist: float) -> Unit:
	var best: Unit = null
	var bd := max_dist
	for e in enemies():
		var d := e.position.distance_to(p)
		if d <= bd:
			bd = d
			best = e
	return best


func nearest_targetable_player(p: Vector2, max_dist: float) -> Unit:
	var best: Unit = null
	var bd := max_dist
	for a in party:
		if a.is_targetable():
			var d := a.position.distance_to(p)
			if d <= bd:
				bd = d
				best = a
	return best


# ---------- 피해 ----------

## opts: bonus_flat, ignore_def, no_crit, no_contam, skill, basic
func deal_damage(src: Unit, dst: Unit, mult: float, opts: Dictionary = {}) -> float:
	if dst == null or not dst.alive or not src.alive and src.team == Unit.Team.ENEMY:
		return 0.0
	if src.has_status(Status.BLIND) and rng.randf() < MISS_CHANCE:
		spawn_fx(&"text", dst.position + Vector2(0, -14), {"text": "MISS", "color": Color("#B0B8C0")})
		return 0.0
	var raw: float = src.atk() * mult + opts.get("bonus_flat", 0.0)
	var defense := 0.0 if opts.get("ignore_def", false) else dst.def()
	var dmg := raw * DEF_K / (DEF_K + maxf(0.0, defense))
	if src.kit:
		dmg *= src.kit.damage_mult(src.element)
	if dst.has_status(Status.RESIST_DOWN):
		dmg *= RESIST_DOWN_MULT
	var crit := false
	if not opts.get("no_crit", false) and rng.randf() * 100.0 < src.effective_crit_rate():
		crit = true
		dmg *= 1.0 + src.crit_dmg / 100.0
	dmg *= rng.randf_range(0.95, 1.05)
	var dealt := dst.take_damage(dmg)
	if dealt <= 0.0:
		return 0.0
	if src.team == Unit.Team.PLAYER and not opts.get("no_contam", false):
		src.add_contamination(CONTAM_SKILL if opts.get("skill", false) else CONTAM_BASIC)
	if dst.team == Unit.Team.PLAYER:
		var tank := dst.data and dst.data.role == CharacterData.Role.TANK
		dst.add_contamination(CONTAM_HIT_TANK if tank else CONTAM_HIT)
	if dst.brain and dst.brain.is_enemy:
		dst.brain.wake(dst)
	var col := CharacterData.element_color(src.element) if src.team == Unit.Team.PLAYER else Color("#FF6B6B")
	spawn_fx(&"text", dst.position + Vector2(rng.randf_range(-4, 4), -14),
		{"text": str(int(dealt)) + ("!" if crit else ""), "color": col, "size": 9 if crit else 7})
	return dealt


# ---------- 이동·지형 ----------

func move_unit(u: Unit, delta_vec: Vector2) -> void:
	var p := u.position + delta_vec
	p.x = clampf(p.x, u.radius, SIZE.x - u.radius)
	p.y = clampf(p.y, u.radius + 8, SIZE.y - u.radius)
	var blockers := obstacles.duplicate()
	if not terminal_done:
		blockers.append(exit_rect)
	for r in blockers:
		p = _push_out(p, u.radius, r)
	u.position = p


static func _push_out(p: Vector2, r: float, rect: Rect2) -> Vector2:
	var q := Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y))
	var d := p - q
	if d.length_squared() >= r * r:
		return p
	if d == Vector2.ZERO:
		# 사각형 안쪽: 가장 가까운 변으로 밀어냄
		var left := p.x - rect.position.x
		var right := rect.end.x - p.x
		var top := p.y - rect.position.y
		var bottom := rect.end.y - p.y
		var m := minf(minf(left, right), minf(top, bottom))
		if m == left: return Vector2(rect.position.x - r, p.y)
		if m == right: return Vector2(rect.end.x + r, p.y)
		if m == top: return Vector2(p.x, rect.position.y - r)
		return Vector2(p.x, rect.end.y + r)
	return q + d.normalized() * r


func _separate() -> void:
	for i in units.size():
		var a := units[i]
		if not a.alive:
			continue
		for j in range(i + 1, units.size()):
			var b := units[j]
			if not b.alive:
				continue
			var d := b.position - a.position
			var min_d := a.radius + b.radius
			var l := d.length()
			if l < min_d and l > 0.01:
				var push := d / l * (min_d - l) * 0.5
				move_unit(a, -push)
				move_unit(b, push)


# ---------- 상호작용 ----------

func can_interact(u: Unit) -> bool:
	return not terminal_done and u.alive and u.position.distance_to(terminal_pos) <= INTERACT_DIST


func interact(u: Unit) -> bool:
	if not can_interact(u):
		return false
	terminal_done = true
	message.emit("MSG_TERMINAL")
	objective_changed.emit("OBJ_EXIT")
	queue_redraw()
	return true


func spawn_fx(kind: StringName, pos: Vector2, params: Dictionary) -> void:
	if not is_inside_tree():
		return
	var fx := CombatFx.new()
	fx.kind = kind
	fx.params = params
	fx.position = pos
	fx.z_index = 10
	add_child(fx)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), Color("#11161C"))
	for x in range(0, int(SIZE.x), 20):
		draw_line(Vector2(x, 0), Vector2(x, SIZE.y), Color(1, 1, 1, 0.03))
	for y in range(0, int(SIZE.y), 20):
		draw_line(Vector2(0, y), Vector2(SIZE.x, y), Color(1, 1, 1, 0.03))
	draw_rect(Rect2(0, 0, SIZE.x, 8), Color("#1C242D"))
	for r in obstacles:
		draw_rect(r, Color("#232C36"))
		draw_rect(r, Color("#2E3844"), false, 1.0)
	# 단말
	var tc := Color("#B6FF3B") if not terminal_done else Color("#4A5560")
	draw_rect(Rect2(terminal_pos - Vector2(5, 8), Vector2(10, 14)), Color("#1C242D"))
	draw_rect(Rect2(terminal_pos - Vector2(5, 8), Vector2(10, 14)), tc, false, 1.0)
	draw_rect(Rect2(terminal_pos - Vector2(3, 6), Vector2(6, 4)), tc)
	# 출구
	var ec := Color("#3FE0C8") if terminal_done else Color("#E5484D")
	draw_rect(exit_rect, Color(ec, 0.15))
	draw_rect(exit_rect, ec, false, 1.0)
