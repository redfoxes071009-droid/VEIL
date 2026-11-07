class_name OfflineContent
extends RefCounted
## 로비의 운영형 콘텐츠를 서버 없이 로컬로 구현합니다: 상점 · 배틀패스 · 파견임무 · 우편 · 공지 · 이벤트.
## 모든 보상은 게임 안 재화이며 실제 결제는 없습니다.

const SHOP := [
	{"id": "daily", "name_key": "SHOP_DAILY", "price": {}, "reward": {"crystal": 60}, "daily": true},
	{"id": "energy", "name_key": "SHOP_ENERGY", "price": {"crystal": 50}, "reward": {"energy": 60}},
	{"id": "credit", "name_key": "SHOP_CREDIT", "price": {"crystal": 100}, "reward": {"credit": 20000}},
	{"id": "shards", "name_key": "SHOP_SHARDS", "price": {"credit": 30000}, "reward": {"shards_pick": 5}},
]

const BP_TIER_XP := 100
const BP_TIERS := [
	{"crystal": 160}, {"credit": 10000}, {"energy": 60}, {"crystal": 160}, {"shards": {"j": 5}},
	{"credit": 20000}, {"crystal": 160}, {"shards": {"stage": 5}}, {"energy": 120}, {"crystal": 480},
]

const DISPATCH := [
	{"id": "scout", "name_key": "DISPATCH_SCOUT", "seconds": 60, "reward": {"credit": 8000}},
	{"id": "data", "name_key": "DISPATCH_DATA", "seconds": 300, "reward": {"crystal": 60}},
	{"id": "infiltrate", "name_key": "DISPATCH_INFILTRATE", "seconds": 1800, "reward": {"credit": 30000, "crystal": 100}},
]

const MAIL := [
	{"id": "welcome", "title_key": "MAIL_WELCOME", "body_key": "MAIL_WELCOME_BODY", "reward": {"crystal": 1600}},
	{"id": "proto", "title_key": "MAIL_PROTO", "body_key": "MAIL_PROTO_BODY", "reward": {"credit": 30000, "energy": 60}},
]

const NOTICES := [
	{"title_key": "NOTICE_1_TITLE", "body_key": "NOTICE_1_BODY"},
	{"title_key": "NOTICE_2_TITLE", "body_key": "NOTICE_2_BODY"},
]


static func today(save: Node) -> int:
	return save.now() / 86400


# ---------- 상점 ----------

static func shop_available(save: Node, item: Dictionary) -> bool:
	if item.get("daily", false):
		return int(save.data.shop.daily_day) != today(save)
	return true


## pick: 조각을 받을 캐릭터 (shards_pick 상품)
static func buy(save: Node, item: Dictionary, pick: StringName = &"j") -> String:
	if not shop_available(save, item):
		return "sold_out"
	for c in item.price:
		if save.get_currency(c) < int(item.price[c]):
			return "currency"
	for c in item.price:
		save.spend(c, int(item.price[c]))
	var reward: Dictionary = item.reward.duplicate(true)
	if reward.has("shards_pick"):
		reward = {"shards": {String(pick): reward.shards_pick}}
	if item.get("daily", false):
		save.data.shop.daily_day = today(save)
	save.grant(reward)
	return ""


# ---------- 배틀패스 ----------

static func bp_tier(save: Node) -> int:
	return mini(BP_TIERS.size(), int(save.data.battlepass.xp) / BP_TIER_XP)


static func bp_claim(save: Node, index: int) -> String:
	if index >= bp_tier(save):
		return "locked"
	if index in save.data.battlepass.claimed:
		return "claimed"
	save.data.battlepass.claimed.append(index)
	save.grant(BP_TIERS[index])
	return ""


# ---------- 파견임무 ----------

static func dispatch_state(save: Node, mission_id: String) -> Dictionary:
	return save.data.dispatch.get(mission_id, {})


static func dispatch_busy_chars(save: Node) -> Array:
	var out := []
	for m in save.data.dispatch.values():
		out.append(m.char)
	return out


static func dispatch_start(save: Node, mission: Dictionary, char_id: StringName) -> String:
	if not dispatch_state(save, mission.id).is_empty():
		return "running"
	if String(char_id) in dispatch_busy_chars(save):
		return "busy"
	save.data.dispatch[mission.id] = {"char": String(char_id), "end": save.now() + int(mission.seconds)}
	save.save_game()
	save.changed.emit()
	return ""


static func dispatch_remaining(save: Node, mission_id: String) -> int:
	var s := dispatch_state(save, mission_id)
	return 0 if s.is_empty() else maxi(0, int(s.end) - save.now())


static func dispatch_collect(save: Node, mission: Dictionary) -> String:
	var s := dispatch_state(save, mission.id)
	if s.is_empty():
		return "idle"
	if dispatch_remaining(save, mission.id) > 0:
		return "running"
	save.data.dispatch.erase(mission.id)
	save.grant(mission.reward)
	return ""


# ---------- 우편 ----------

static func mail_claimed(save: Node, mail_id: String) -> bool:
	return mail_id in save.data.mail_claimed


static func mail_claim(save: Node, mail: Dictionary) -> String:
	if mail_claimed(save, mail.id):
		return "claimed"
	save.data.mail_claimed.append(mail.id)
	save.grant(mail.reward)
	return ""


static func unread_mail(save: Node) -> int:
	var n := 0
	for m in MAIL:
		if not mail_claimed(save, m.id):
			n += 1
	return n


## 보상 사전을 사람이 읽는 문장으로.
static func reward_text(reward: Dictionary) -> String:
	var parts := []
	var names := {"credit": "CUR_CREDIT", "crystal": "CUR_CRYSTAL", "energy": "CUR_ENERGY"}
	for k in reward:
		if names.has(k):
			parts.append("%s ×%s" % [TranslationServer.translate(names[k]), _num(int(reward[k]))])
		elif k == "shards":
			for id in reward.shards:
				parts.append("%s %s ×%d" % [Progression.load_character(StringName(id)).display_name, TranslationServer.translate("CUR_SHARD"), int(reward.shards[id])])
		elif k == "shards_pick":
			parts.append("%s ×%d" % [TranslationServer.translate("SHOP_PICK_SHARD"), int(reward[k])])
	return ", ".join(parts)


static func _num(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
