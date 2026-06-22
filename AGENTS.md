# AGENTS.md

이 저장소는 Godot 4.7.x Standard와 GDScript만 사용하는 2인 협업 프로젝트입니다.

## 공통 규칙

- 람다 함수는 꼭 필요한 경우를 제외하고 사용하지 말 것.
- GDScript를 우선 사용하고, C#/.NET 파일은 별도 합의 없이 추가하지 말 것.
- 작업 전 `git status`로 변경 범위를 확인할 것.
- 씬 파일(`*.tscn`), `project.godot`, Input Map은 한 번에 한 사람만 수정할 것.
- `.godot/`, `exports/`, `builds/`의 생성 파일은 커밋하지 말 것.
- Godot import 설정인 `*.import` 파일은 원본 에셋과 함께 커밋할 것.
- 큰 바이너리 에셋은 `.gitattributes`의 Git LFS 규칙을 따를 것.

## 브랜치 규칙

- Codex 작업 브랜치: `codex/<task>`
- Cursor/Claude Sonnet 작업 브랜치: `cursor/<task>`
- `main`에는 직접 push하지 말고 Pull Request로 병합할 것.

## PR 전 체크

- Godot에서 프로젝트가 열리는지 확인한다.
- 메인 씬(`res://scenes/main.tscn`)이 실행되는지 확인한다.
- `git status`에 의도한 변경만 남아 있는지 확인한다.
