class_name Gacha
extends RefCounted
## 모집 (로컬 전용). 실제 결제 없음 — 크리스탈은 게임 안에서만 얻습니다.
## 모든 캐릭터를 처음부터 보유하므로, 모집 결과는 캐릭터 조각(돌파 재료)과 크레딧입니다.
## ★5 조각 6% (그중 50%는 픽업 캐릭터), ★4 조각 24%, ★3 크레딧 70%. 50회 안에 ★5 보장.

const COST_ONE := 160
const COST_TEN := 1600
const PICKUP: StringName = &"stage"
const RATE_5 := 0.06
const RATE_4 := 0.24
const PITY := 50
const SHARDS_5 := 10
const SHARDS_4 := 2
const CREDIT_3 := 5000


## 결과 하나: {"rarity", "char"?, "shards"?, "credit"?}. pity 는 호출 측이 관리합니다.
static func roll_once(rng: RandomNumberGenerator, pity: int) -> Dictionary:
	var r := rng.randf()
	if pity + 1 >= PITY or r < RATE_5:
		var id: StringName = PICKUP if rng.randf() < 0.5 else Progression.ROSTER[rng.randi() % Progression.ROSTER.size()]
		return {"rarity": 5, "char": id, "shards": SHARDS_5}
	if r < RATE_5 + RATE_4:
		return {"rarity": 4, "char": Progression.ROSTER[rng.randi() % Progression.ROSTER.size()], "shards": SHARDS_4}
	return {"rarity": 3, "credit": CREDIT_3}


## count 회 모집. 크리스탈이 모자라면 빈 배열.
static func pull(save: Node, count: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cost := COST_TEN if count == 10 else COST_ONE * count
	if not save.spend("crystal", cost):
		return out
	var g: Dictionary = save.data.gacha
	var reward := {"credit": 0, "shards": {}}
	for i in count:
		var res := roll_once(rng, int(g.pity))
		g.total = int(g.total) + 1
		g.pity = 0 if res.rarity == 5 else int(g.pity) + 1
		if res.has("char"):
			var k := String(res.char)
			reward.shards[k] = reward.shards.get(k, 0) + res.shards
		else:
			reward.credit += res.credit
		out.append(res)
	save.grant(reward)
	return out
