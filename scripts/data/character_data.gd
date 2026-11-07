class_name CharacterData
extends Resource
## 캐릭터 1명의 고정 데이터. 값은 data/characters/*.tres 에서 편집합니다.
## 출처: 사용자 제공 캐릭터 기획 PDF (스킬 프리뷰·캐릭터 시트·캐릭터 정보 화면).

enum Element { VOID, CONDUCT, RADIANCE }
enum Role { TANK, DEALER, SUPPORT }
enum AttackRange { MELEE, RANGED }

@export var id: StringName
@export var display_name: String
@export var name_en: String
@export var epithet: String            ## 예: 어둠속의 그림자
@export var code: String               ## 예: CODE-J2-7234-257E
@export_range(1, 5) var rank: int = 5
@export var element: Element
@export var role: Role
@export var range_type: AttackRange
@export var height_cm: int
@export var weapon_name: String
@export_multiline var weapon_desc: String
@export_multiline var profile: String
@export_multiline var trait_desc: String  ## 캐릭터 정보 화면의 「특성」

@export_group("Stats")
## PDF 캐릭터 정보 화면의 수치와 그 화면의 레벨. 다른 레벨은 Progression 이 비례 계산.
@export var ref_level: int = 90
@export var hp: float
@export var atk: float
@export var def: float
@export var crit_rate: float           ## % (PDF 4번째 수치로 해석)
@export var crit_dmg: float            ## % (PDF 5번째 수치로 해석)
@export var effect_hit: float          ## PDF 6번째 수치 (해석 미확정: 효과 적중)
@export var move_speed: float = 70.0   ## 전투 화면 px/초 (640×360 기준)
@export var attack_range: float = 24.0 ## px
@export var attack_interval: float = 1.0
@export var basic_mult: float = 1.0    ## 기본 공격 배율

@export_group("Skills")
@export var skill_name: String
@export_multiline var skill_desc: String
@export var skill_cooldown: float
@export var ult_name: String
@export_multiline var ult_desc: String
@export var ult_cooldown: float

@export_group("Presentation")
@export var color_main: Color
@export var color_sub: Color
@export var illust: Texture2D
@export var portrait: Texture2D


func element_key() -> String:
	return ["ELEMENT_VOID", "ELEMENT_CONDUCT", "ELEMENT_RADIANCE"][element]


func role_key() -> String:
	return ["ROLE_TANK", "ROLE_DEALER", "ROLE_SUPPORT"][role]


func range_key() -> String:
	return ["RANGE_MELEE", "RANGE_RANGED"][range_type]


static func element_color(e: int) -> Color:
	return [Color("#9D7BFF"), Color("#3FE0FF"), Color("#FFC83D")][e]
