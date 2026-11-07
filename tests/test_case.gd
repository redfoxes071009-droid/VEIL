extends RefCounted
## 테스트 묶음의 기본 클래스. test_ 로 시작하는 함수를 실행기가 차례로 호출합니다.
## 함수는 await 를 써도 됩니다(실행기가 기다립니다).

var tree: SceneTree
var failures: Array[String] = []
var checks := 0


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func check_eq(actual, expected, message: String) -> void:
	check(actual == expected, "%s (기대값 %s, 실제값 %s)" % [message, str(expected), str(actual)])


func wait_frames(n: int) -> void:
	for i in n:
		await tree.process_frame


func wait_seconds(sec: float) -> void:
	await tree.create_timer(sec, true, false, true).timeout
