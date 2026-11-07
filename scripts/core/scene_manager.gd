extends CanvasLayer
## 씬 전환과 페이드 (오토로드: SceneManager).

signal scene_change_finished(path: String)

const TITLE_SCENE := "res://scenes/ui/title_screen.tscn"
const TEST_MAP_SCENE := "res://scenes/maps/test_map.tscn"

var _fade: ColorRect
var _busy := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func is_busy() -> bool:
	return _busy


## 페이드 아웃 → 씬 교체 → 페이드 인. 없는 경로면 오류를 남기고 false.
func change_scene(path: String, fade_time: float = 0.25) -> bool:
	if _busy:
		return false
	if not ResourceLoader.exists(path):
		push_error("존재하지 않는 씬: %s" % path)
		return false
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP
	if fade_time > 0.0:
		await _tween_fade(1.0, fade_time)
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("씬 전환 실패 (%s): %s" % [path, error_string(err)])
	# change_scene_to_file 은 다음 프레임에 반영됩니다.
	await get_tree().process_frame
	await get_tree().process_frame
	if fade_time > 0.0:
		await _tween_fade(0.0, fade_time)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
	scene_change_finished.emit(path)
	return err == OK


func _tween_fade(alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "color:a", alpha, time)
	await tween.finished
