extends Node
## 개발용: 주요 화면을 PNG로 저장합니다 (화면이 있는 환경에서 실행).
## 실행: godot res://tests/capture_screens.tscn -- <출력 폴더>
## 실제 저장 파일을 건드리지 않도록 전용 저장 경로를 씁니다.


func _ready() -> void:
	get_tree().current_scene = null
	_run.call_deferred()


func _shot(dir: String, name: String, wait: float = 0.5) -> void:
	await get_tree().create_timer(wait, true, false, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(dir.path_join(name + ".png"))


func _go(path: String) -> void:
	await SceneManager.change_scene(path, 0.0)


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0] if args.size() > 0 else OS.get_user_data_dir()
	TranslationServer.set_locale("ko")
	SaveManager.path = "user://capture_save.json"
	SaveManager.delete_save()
	SaveManager.new_game()
	OfflineContent.mail_claim(SaveManager, OfflineContent.MAIL[0])
	await _go(SceneManager.TITLE_SCENE)
	await _shot(dir, "01_title")
	await _go(SceneManager.LOBBY_SCENE)
	await _shot(dir, "02_lobby")
	await _go(SceneManager.CHARACTER_SCENE)
	await _shot(dir, "03_character_j")
	var cs := get_tree().current_scene
	cs._select_char(2)
	cs._select_tab(3)
	await _shot(dir, "04_character_stage_skill")
	await _go(SceneManager.GACHA_SCENE)
	get_tree().current_scene.find_child("PullTen", true, false).pressed.emit()
	await _shot(dir, "05_gacha")
	await _go(SceneManager.DISPATCH_SCENE)
	await _shot(dir, "06_dispatch")
	await _go(SceneManager.STORY_SCENE)
	await _shot(dir, "07_story")
	await _go(SceneManager.BATTLE_SCENE)
	var w: CombatWorld = get_tree().current_scene.world
	for u in w.party:
		u.controlled = false
		u.auto_skills = true
	w.leader.contamination = 80.0
	await _shot(dir, "08_battle", 7.0)
	await _shot(dir, "09_battle_later", 6.0)
	SaveManager.delete_save()
	get_tree().quit()
