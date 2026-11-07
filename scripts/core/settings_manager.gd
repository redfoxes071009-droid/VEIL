extends Node
## 설정 저장·불러오기·적용 (오토로드: SettingsManager).
## 저장 위치: user://settings.cfg  (Windows: %APPDATA%\Godot\app_userdata\VEIL\)
## 파일이 손상되면 .corrupt 로 이름을 바꿔 보관하고 기본값으로 시작합니다.

signal settings_changed

const SETTINGS_VERSION := 1
const DEFAULT_PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]

enum WindowMode { WINDOWED, FULLSCREEN }

const DEFAULT_MASTER_VOLUME := 0.8
const DEFAULT_WINDOW_MODE := WindowMode.WINDOWED
const DEFAULT_RESOLUTION_INDEX := 1

var master_volume: float = DEFAULT_MASTER_VOLUME
var window_mode: int = DEFAULT_WINDOW_MODE
var resolution_index: int = DEFAULT_RESOLUTION_INDEX
## 테스트에서 다른 경로를 쓰기 위해 열어 둡니다.
var path: String = DEFAULT_PATH


func reset_to_defaults() -> void:
	master_volume = DEFAULT_MASTER_VOLUME
	window_mode = DEFAULT_WINDOW_MODE
	resolution_index = DEFAULT_RESOLUTION_INDEX


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	settings_changed.emit()


func set_window_mode(mode: int) -> void:
	window_mode = mode if mode in WindowMode.values() else DEFAULT_WINDOW_MODE
	settings_changed.emit()


func set_resolution_index(index: int) -> void:
	resolution_index = index if index >= 0 and index < RESOLUTIONS.size() else DEFAULT_RESOLUTION_INDEX
	settings_changed.emit()


func get_resolution() -> Vector2i:
	return RESOLUTIONS[resolution_index]


## 파일에서 불러옵니다. 파일이 없거나 손상되면 기본값을 쓰고 false 를 돌려줍니다.
func load_settings() -> bool:
	reset_to_defaults()
	if not FileAccess.file_exists(path):
		return false
	var cfg := ConfigFile.new()
	var err := cfg.load(path)
	if err != OK:
		_quarantine_corrupt_file()
		return false
	# 숫자 타입만 받아들이고, 범위를 벗어난 값은 각 setter 가 바로잡습니다.
	var vol = cfg.get_value("audio", "master_volume", DEFAULT_MASTER_VOLUME)
	var mode = cfg.get_value("display", "window_mode", DEFAULT_WINDOW_MODE)
	var res = cfg.get_value("display", "resolution_index", DEFAULT_RESOLUTION_INDEX)
	set_master_volume(float(vol) if typeof(vol) in [TYPE_FLOAT, TYPE_INT] else DEFAULT_MASTER_VOLUME)
	set_window_mode(int(mode) if typeof(mode) in [TYPE_FLOAT, TYPE_INT] else DEFAULT_WINDOW_MODE)
	set_resolution_index(int(res) if typeof(res) in [TYPE_FLOAT, TYPE_INT] else DEFAULT_RESOLUTION_INDEX)
	return true


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("meta", "version", SETTINGS_VERSION)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("display", "window_mode", window_mode)
	cfg.set_value("display", "resolution_index", resolution_index)
	var err := cfg.save(path)
	if err != OK:
		push_error("설정 저장 실패 (%s): %s" % [path, error_string(err)])
	return err


## 현재 값을 오디오와 창에 적용합니다.
func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus, master_volume <= 0.0)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
	if _can_control_window():
		if window_mode == WindowMode.FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		else:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			var size := _fit_to_screen(get_resolution())
			DisplayServer.window_set_size(size)
			var screen := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
			DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
	if is_inside_tree() and has_node("/root/EventBus"):
		get_node("/root/EventBus").settings_applied.emit()


func _can_control_window() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.has_feature("mobile")


## 화면보다 큰 해상도를 고르면 화면 안에 들어가는 가장 큰 해상도로 줄입니다.
func _fit_to_screen(size: Vector2i) -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen()).size
	if size.x <= usable.x and size.y <= usable.y:
		return size
	for i in range(RESOLUTIONS.size() - 1, -1, -1):
		if RESOLUTIONS[i].x <= usable.x and RESOLUTIONS[i].y <= usable.y:
			return RESOLUTIONS[i]
	return RESOLUTIONS[0]


func _quarantine_corrupt_file() -> void:
	var bad := path + ".corrupt"
	if FileAccess.file_exists(bad):
		DirAccess.remove_absolute(bad)
	DirAccess.rename_absolute(path, bad)
	push_warning("설정 파일이 손상되어 기본값으로 시작합니다. 원본: %s" % bad)
