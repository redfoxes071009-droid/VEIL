extends "res://tests/test_case.gd"
## SettingsManager 단위 테스트. 실제 설정 파일 대신 테스트 전용 경로를 씁니다.

const SettingsScript := preload("res://scripts/core/settings_manager.gd")
const TEST_PATH := "user://test_settings.cfg"


func _make() -> Node:
	var s: Node = SettingsScript.new()
	s.path = TEST_PATH
	return s


func _cleanup() -> void:
	for p in [TEST_PATH, TEST_PATH + ".corrupt"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


func test_defaults_when_no_file() -> void:
	_cleanup()
	var s := _make()
	check_eq(s.load_settings(), false, "파일이 없으면 false")
	check_eq(s.master_volume, s.DEFAULT_MASTER_VOLUME, "기본 음량")
	check_eq(s.resolution_index, s.DEFAULT_RESOLUTION_INDEX, "기본 해상도")
	s.free()


func test_save_and_load_roundtrip() -> void:
	_cleanup()
	var a := _make()
	a.set_master_volume(0.35)
	a.set_window_mode(a.WindowMode.FULLSCREEN)
	a.set_resolution_index(2)
	check_eq(a.save_settings(), OK, "저장 성공")
	var b := _make()
	check_eq(b.load_settings(), true, "불러오기 성공")
	check(is_equal_approx(b.master_volume, 0.35), "음량 유지")
	check_eq(b.window_mode, b.WindowMode.FULLSCREEN, "화면 모드 유지")
	check_eq(b.resolution_index, 2, "해상도 유지")
	a.free()
	b.free()
	_cleanup()


func test_values_are_clamped() -> void:
	var s := _make()
	s.set_master_volume(2.5)
	check_eq(s.master_volume, 1.0, "음량 상한 1.0")
	s.set_master_volume(-1.0)
	check_eq(s.master_volume, 0.0, "음량 하한 0.0")
	s.set_resolution_index(99)
	check_eq(s.resolution_index, s.DEFAULT_RESOLUTION_INDEX, "없는 해상도는 기본값")
	s.set_window_mode(7)
	check_eq(s.window_mode, s.DEFAULT_WINDOW_MODE, "없는 화면 모드는 기본값")
	s.free()


func test_out_of_range_file_values_are_fixed() -> void:
	_cleanup()
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master_volume", 9.0)
	cfg.set_value("display", "resolution_index", -3)
	cfg.set_value("display", "window_mode", "전체")  # 잘못된 타입
	cfg.save(TEST_PATH)
	var s := _make()
	s.load_settings()
	check_eq(s.master_volume, 1.0, "파일의 큰 음량은 1.0으로")
	check_eq(s.resolution_index, s.DEFAULT_RESOLUTION_INDEX, "파일의 잘못된 해상도는 기본값")
	check_eq(s.window_mode, s.DEFAULT_WINDOW_MODE, "파일의 잘못된 타입은 기본값")
	s.free()
	_cleanup()


func test_corrupt_file_is_quarantined() -> void:
	_cleanup()
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("[audio\nmaster_volume = ???\n<<손상된 파일>>")
	f.close()
	var s := _make()
	check_eq(s.load_settings(), false, "손상된 파일은 false")
	check_eq(s.master_volume, s.DEFAULT_MASTER_VOLUME, "손상 시 기본값")
	check(FileAccess.file_exists(TEST_PATH + ".corrupt"), "손상 파일을 .corrupt 로 보관")
	check(not FileAccess.file_exists(TEST_PATH), "원래 경로는 비워짐")
	s.free()
	_cleanup()
