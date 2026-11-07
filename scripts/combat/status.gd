class_name Status
extends RefCounted
## 상태 이름과 효과 수치. 유닛이 이 표를 보고 능력치를 보정합니다.

const STEALTH := &"stealth"            ## J 그림자 장막: 타겟 불가, 사거리·치명타 증가
const ROOT := &"root"                  ## 속박: 이동 불가
const BLIND := &"blind"                ## 실명: 공격 50% 빗나감
const SLOW := &"slow"                  ## 이동 속도 -20%
const CONDUCT_BONUS := &"conduct_bonus" ## 스테이지: 전도 피해 +20%
const TWIN_SPEARS := &"twin_spears"    ## 라 쌍창: 공속 +20% 이속 +15% 방어 -15%
const JUDGEMENT := &"judgement"        ## 라 심판의 날: 공격력 +25%, 초당 5% 회복
const SHIELD := &"shield"              ## 보호막 (amount)
const LIGHTSPEED := &"lightspeed"      ## 페이즈 광속 질주: 이속 +30%, 다음 스킬 쿨 초기화
const SPRINT := &"sprint"              ## 페이즈 질주 중 (포털 게이지 소모)
const HASTE := &"haste"                ## 질주 버프: 이속 +20% 공속 +15%
const RESIST_DOWN := &"resist_down"    ## 내성 감소: 받는 피해 +20%
const DODGE := &"dodge"                ## 회피 무적

const MOVE := {SLOW: -0.20, TWIN_SPEARS: 0.15, LIGHTSPEED: 0.30, HASTE: 0.20}
const ATTACK_SPEED := {TWIN_SPEARS: 0.20, HASTE: 0.15}
const ATK := {JUDGEMENT: 0.25}
const DEF := {TWIN_SPEARS: -0.15}
const LABEL_KEYS := {
	STEALTH: "STATUS_STEALTH", ROOT: "STATUS_ROOT", BLIND: "STATUS_BLIND", SLOW: "STATUS_SLOW",
	CONDUCT_BONUS: "STATUS_CONDUCT", TWIN_SPEARS: "STATUS_TWIN", JUDGEMENT: "STATUS_JUDGEMENT",
	SHIELD: "STATUS_SHIELD", LIGHTSPEED: "STATUS_LIGHTSPEED", SPRINT: "STATUS_SPRINT",
	HASTE: "STATUS_HASTE", RESIST_DOWN: "STATUS_RESIST_DOWN",
}
