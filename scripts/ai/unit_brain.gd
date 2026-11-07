class_name UnitBrain
extends RefCounted
## 유닛 AI. 아군(역할별)과 적(BITE) 공통 진입점: think(unit, delta).

const FOLLOW_DIST := 26.0
const ALLY_AGGRO := 170.0
const ENEMY_WAKE := 120.0
const ENEMY_LEASH := 260.0

var is_enemy := false
var awake := false
var _offset := Vector2.ZERO
var _repick := 0.0


static func for_ally(slot: int) -> UnitBrain:
	var b := UnitBrain.new()
	b._offset = [Vector2(-18, -14), Vector2(-22, 14), Vector2(-34, 0)][slot % 3]
	return b


static func for_enemy() -> UnitBrain:
	var b := UnitBrain.new()
	b.is_enemy = true
	return b


func think(u: Unit, delta: float) -> void:
	if is_enemy:
		_think_enemy(u, delta)
	else:
		_think_ally(u, delta)


# ---------- 아군 ----------

func _think_ally(u: Unit, delta: float) -> void:
	var w := u.world
	var leader: Unit = w.leader
	_repick -= delta
	if _repick <= 0.0 or u.target == null or not u.target.alive:
		_repick = 0.5
		var anchor: Vector2 = leader.position if leader and leader.alive else u.position
		u.target = w.nearest_enemy_to_point(anchor, ALLY_AGGRO)
	if u.target == null:
		if u == leader:
			_advance_objective(u, delta)
		elif leader and leader.alive:
			u.move_toward_point(leader.position + _offset, delta, 6.0)
		return
	var d := u.position.distance_to(u.target.position)
	var want := u.attack_range() + u.target.radius - 2.0
	if u.data.range_type == CharacterData.AttackRange.RANGED:
		if d > want:
			u.move_toward_point(u.target.position, delta)
		elif d < want * 0.5:
			u.move_dir(u.position - u.target.position, delta)
	elif d > want:
		u.move_toward_point(u.target.position, delta)
	u.try_basic_attack()
	if u.auto_skills or (u == leader and not u.controlled):
		if u.can_use_ult() and u.kit.ai_wants_ult():
			u.use_ult()
		elif u.can_use_skill() and u.kit.ai_wants_skill():
			u.use_skill(false)


## 리더를 AI로 돌릴 때(자동 전투·테스트): 단말 → 출구 순서로 이동.
func _advance_objective(u: Unit, delta: float) -> void:
	var w := u.world
	if not w.terminal_done:
		if w.can_interact(u):
			w.interact(u)
		else:
			_path_to(u, w.terminal_pos + Vector2(0, 14), delta)
	else:
		_path_to(u, w.exit_rect.get_center(), delta)


## 임시 경로: 1구역과 2구역 사이 통로(x 235, y 180)를 지나 목표로 이동.
## 맵이 늘어나면 NavigationRegion2D + NavigationAgent2D 로 교체합니다.
func _path_to(u: Unit, goal: Vector2, delta: float) -> void:
	var gate := Vector2(235, 180)
	if u.position.x < gate.x - 4.0 and goal.x > gate.x:
		u.move_toward_point(gate, delta)
	else:
		u.move_toward_point(goal, delta)


# ---------- 적 (BITE) ----------

func _think_enemy(u: Unit, delta: float) -> void:
	var w := u.world
	if not awake:
		if w.nearest_targetable_player(u.position, ENEMY_WAKE) != null:
			wake(u)
		return
	_repick -= delta
	if _repick <= 0.0 or u.target == null or not u.target.is_targetable():
		_repick = 0.6
		u.target = w.nearest_targetable_player(u.position, ENEMY_LEASH)
	if u.target == null:
		return
	var e: Dictionary = EnemyDefs.get_def(u.enemy_kind)
	var d := u.position.distance_to(u.target.position)
	if e.style == "ranged":
		var keep: float = e.keep_distance
		if d > u.attack_range():
			u.move_toward_point(u.target.position, delta)
		elif d < keep * 0.7:
			u.move_dir(u.position - u.target.position, delta)
	elif d > u.attack_range() + u.target.radius - 1.0:
		u.move_toward_point(u.target.position, delta)
	u.try_basic_attack()


## 같은 무리의 적을 함께 깨웁니다.
func wake(u: Unit) -> void:
	if awake:
		return
	awake = true
	for other in u.world.enemies_in_radius(u.position, 90.0):
		if other.brain and not other.brain.awake:
			other.brain.wake(other)
