class_name EnemyDefs
extends RefCounted
## BITE 적 정의. BITE: 변이를 이용한 생체실험으로 군사 무기를 개발하는 적대 집단 (11/8 확정).
## 수치는 임시 밸런스입니다 (아군 시작 레벨 30 기준).

const DEFS := {
	&"bite_mutant": {
		"name_key": "ENEMY_MUTANT", "element": 0, "hp": 9000.0, "atk": 260.0, "def": 300.0,
		"speed": 52.0, "range": 12.0, "interval": 1.0, "radius": 6.0, "color": Color("#C0392B"),
		"style": "melee",
	},
	&"bite_gunner": {
		"name_key": "ENEMY_GUNNER", "element": 1, "hp": 6000.0, "atk": 320.0, "def": 200.0,
		"speed": 44.0, "range": 90.0, "interval": 1.6, "radius": 5.0, "color": Color("#E67E22"),
		"style": "ranged", "keep_distance": 70.0,
	},
	&"bite_brute": {
		"name_key": "ENEMY_BRUTE", "element": 0, "hp": 30000.0, "atk": 450.0, "def": 800.0,
		"speed": 36.0, "range": 16.0, "interval": 1.6, "radius": 9.0, "color": Color("#8E1B4D"),
		"style": "melee",
	},
}


static func get_def(kind: StringName) -> Dictionary:
	return DEFS[kind]
