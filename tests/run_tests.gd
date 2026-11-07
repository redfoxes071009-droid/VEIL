extends Node
## 테스트 실행기. 실행: godot --headless res://tests/run_tests.tscn
## 모든 묶음을 실행하고 실패가 있으면 종료 코드 1로 끝납니다.

const SUITES := [
	"res://tests/unit/test_settings.gd",
	"res://tests/unit/test_input_config.gd",
	"res://tests/integration/test_game_flow.gd",
]


func _ready() -> void:
	# 실행기 씬이 씬 전환 테스트에 지워지지 않도록 루트에 따로 둡니다.
	var tree := get_tree()
	tree.current_scene = null
	_run.call_deferred(tree)


func _run(tree: SceneTree) -> void:
	TranslationServer.set_locale("ko")
	var total := 0
	var failed: Array[String] = []
	for path: String in SUITES:
		var suite = load(path).new()
		suite.tree = tree
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			var before: int = suite.failures.size()
			await suite.call(name)
			var ok: bool = suite.failures.size() == before
			print("%s  %s :: %s" % ["PASS" if ok else "FAIL", path.get_file(), name])
			for i in range(before, suite.failures.size()):
				print("      - " + suite.failures[i])
				failed.append("%s :: %s — %s" % [path.get_file(), name, suite.failures[i]])
		total += suite.checks
	print("\n결과: 검사 %d개, 실패 %d개" % [total, failed.size()])
	tree.quit(1 if failed.size() > 0 else 0)
