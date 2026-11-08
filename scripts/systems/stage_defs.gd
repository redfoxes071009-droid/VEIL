class_name StageDefs
extends RefCounted
## 프롤로그(장막 A part P1) 스토리 맵의 노드 정의.
## 노드 모양·위치는 Photoshop 「VEIL_스토리맵_UI.psd」에서 내보낸 assets/ui/story_map/ 을 씁니다.
## type: main(메인) · sub(서브 의뢰) · record(기록 재생, 전투 없음)
## unlock: 먼저 클리어해야 하는 노드. enemy_mult: 적 HP·공격력 배율.

const CHAPTER_TOTAL := 10   ## PSD 「임무 진행 상황 x/10」의 분모 (장막 A part 전체 임무 수)

const STAGES := {
	"R1-1": {
		"type": "record", "title_key": "STAGE_R1_1_TITLE", "desc_key": "STAGE_R1_1_DESC", "unlock": [],
	},
	"1-1": {
		"type": "main", "title_key": "STAGE_1_1_TITLE", "desc_key": "STAGE_1_1_DESC", "unlock": [],
		"energy": 10, "rec_level": 30, "enemy_mult": 1.0, "reward_mult": 1.0,
	},
	"1-2": {
		"type": "main", "title_key": "STAGE_1_2_TITLE", "desc_key": "STAGE_1_2_DESC", "unlock": ["1-1"],
		"energy": 10, "rec_level": 35, "enemy_mult": 1.35, "reward_mult": 1.3,
		"enemies": [["bite_mutant", 270, 150], ["bite_mutant", 290, 210], ["bite_gunner", 330, 120], ["bite_gunner", 320, 240],
			["bite_brute", 470, 110], ["bite_brute", 520, 220], ["bite_gunner", 540, 70]],
	},
	"R1-2": {
		"type": "record", "title_key": "STAGE_R1_2_TITLE", "desc_key": "STAGE_R1_2_DESC", "unlock": [],
	},
	"S1-1": {
		"type": "sub", "title_key": "STAGE_S1_1_TITLE", "desc_key": "STAGE_S1_1_DESC", "unlock": [],
		"energy": 8, "rec_level": 30, "enemy_mult": 0.85, "reward_mult": 0.8,
		"enemies": [["bite_mutant", 270, 160], ["bite_mutant", 300, 200], ["bite_mutant", 460, 120], ["bite_gunner", 510, 90]],
	},
	"S1-2": {
		"type": "sub", "title_key": "STAGE_S1_2_TITLE", "desc_key": "STAGE_S1_2_DESC", "unlock": [],
		"energy": 12, "rec_level": 40, "enemy_mult": 1.6, "reward_mult": 1.6,
		"enemies": [["bite_gunner", 280, 140], ["bite_gunner", 280, 220], ["bite_brute", 330, 180], ["bite_gunner", 480, 80],
			["bite_gunner", 520, 200], ["bite_brute", 470, 130]],
	},
	"S1-3": {
		"type": "sub", "title_key": "STAGE_S1_3_TITLE", "desc_key": "STAGE_S1_3_DESC", "unlock": ["S1-2"],
		"energy": 15, "rec_level": 50, "enemy_mult": 2.0, "reward_mult": 2.0,
		"enemies": [["bite_brute", 290, 150], ["bite_brute", 300, 220], ["bite_gunner", 340, 110], ["bite_brute", 470, 110],
			["bite_brute", 520, 210], ["bite_gunner", 540, 70], ["bite_gunner", 520, 260]],
	},
}


static func get_def(code: String) -> Dictionary:
	return STAGES.get(code, {})


static func is_battle(code: String) -> bool:
	return get_def(code).get("type", "") != "record"


static func is_cleared(save: Node, code: String) -> bool:
	return save.is_loaded() and code in save.data.story.cleared


static func is_unlocked(save: Node, code: String) -> bool:
	for req in get_def(code).get("unlock", []):
		if not is_cleared(save, req):
			return false
	return true


static func missing_requirements(save: Node, code: String) -> Array:
	var out := []
	for req in get_def(code).get("unlock", []):
		if not is_cleared(save, req):
			out.append(req)
	return out


static func cleared_count(save: Node) -> int:
	var n := 0
	for code in STAGES:
		if is_battle(code) and is_cleared(save, code):
			n += 1
	return n


static func type_key(code: String) -> String:
	return {"main": "STAGE_TYPE_MAIN", "sub": "STAGE_TYPE_SUB", "record": "STAGE_TYPE_RECORD"}[get_def(code).type]
