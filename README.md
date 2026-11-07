# VEIL (베일)

변이와 오염으로 붕괴한 세계에서 J가 큐브의 진실을 추적하는 2D SF 디스토피아 싱글플레이 RPG.

- 엔진: **Godot 4.7.2** (표준판, GDScript) · 렌더러: GL Compatibility
- 현재 단계: **Phase 2 — 프로젝트 구축** (게임플레이 없음)
- 기획: 「VEIL 최초 기획 분석 보고서」(Claude Docs) · UI 설계: Figma 「VEIL — 프로토타입 UI」

## 실행 방법

1. [Godot 4.7.2](https://godotengine.org/download)를 설치합니다 (.NET 아닌 표준판).
2. Godot 프로젝트 관리자에서 **가져오기** → 이 폴더의 `project.godot` 선택.
3. 처음 열면 리소스 가져오기가 끝날 때까지 기다린 뒤 **F5**(실행).

현재 할 수 있는 것: 타이틀 → 새 게임 → 테스트 맵(빈 화면) → Esc 일시정지 → 설정(음량·화면 모드·해상도, 자동 저장) → 타이틀로 / 게임 종료.

## 테스트

```bash
godot --headless --import                 # 최초 1회
godot --headless res://tests/run_tests.tscn  # 실패가 있으면 종료 코드 1
```

## 폴더

| 폴더 | 내용 |
| --- | --- |
| `scripts/core/` | 오토로드: EventBus, InputConfig, SettingsManager, GameManager, SceneManager |
| `scripts/ui/` | 타이틀, 일시정지, 설정 패널, 공통 스타일(UiStyle) |
| `scenes/` | main(부팅), ui, maps, gameplay |
| `data/localization/` | 번역 CSV (모든 화면 문구는 번역 키로 작성) |
| `assets/placeholder/` | 임시 리소스 전용 (최종 빌드 전 0개가 목표) |
| `tests/` | 단위·통합 테스트, 화면 캡처 도구 |

## 조작 (PC 기본)

이동 WASD · 회피 Space · 스킬 Q/E · 궁극기 R · 라 스킬 1 / 궁극기 Shift+1 · 상호작용 F · 대상 지정 좌클릭 · 일시정지 Esc
(Phase 2에서는 Esc만 동작합니다.)

## 라이선스 메모

- Noto Sans KR, Rajdhani: SIL Open Font License 1.1 (`assets/fonts/OFL-*.txt`). 게임에 포함해 배포 가능.
