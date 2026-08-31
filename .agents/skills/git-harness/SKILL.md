---
name: git-harness
description: Tekken8 Frame Data 저장소에서 Git 상태 확인, 브랜치, 커밋, 푸시, PR 작업을 할 때 사용하는 개인 작업용 Git 하네스입니다.
---

# Git Harness

이 하네스는 개인 작업 흐름을 전제로 한다. 팀 협업 전용 절차는 기본값으로 요구하지 않는다.

## 적용 범위

다음 작업을 할 때 적용한다.

- `git status`, diff 확인, staging, commit, branch, push, PR 작성
- 릴리즈 브랜치 또는 `main`/`develop` 관련 정리
- 사용자가 "커밋해줘", "푸시해줘", "PR 올려줘", "브랜치 만들어줘"라고 요청한 경우

## 기본 안전 규칙

- 작업 전 `git status --short`로 기존 변경사항을 확인한다.
- 사용자가 만든 변경사항을 되돌리지 않는다.
- 관련 없는 untracked/ignored 파일은 임의로 stage, commit, 수정하지 않는다.
- `main` 또는 `develop`에서 직접 커밋/푸시해야 할 상황이면 먼저 사용자에게 확인한다.
- `git push`는 사용자가 명시적으로 요청했을 때만 실행한다.
- `--force`, `--force-with-lease`, rebase로 공개 이력을 바꾸는 작업은 사용자가 명시적으로 승인한 경우에만 실행한다.

## 브랜치 규칙

- 현재 브랜치가 작업 목적에 맞으면 그대로 사용한다.
- 새 브랜치는 작업 유형과 이슈 제목을 기준으로 만든다. 일반 `codex/` 접두사를 사용하지 않는다.
- 이슈가 있는 작업은 `fix/#<이슈번호>/<kebab-case-작업명>` 또는 `feat/#<이슈번호>/<kebab-case-작업명>` 형식을 사용한다. 예: `fix/#66/character-image-url-fallback`.
- 이슈가 없는 작업도 목적에 맞는 `fix/`, `feat/`, `refactor/`, `docs/`, `test/`, `chore/` 접두사를 사용한다.
- 브랜치를 만들기 전에는 반드시 이슈 제목/유형과 기존 브랜치 명명 사례를 확인하고, 선택한 브랜치명이 해당 유형과 일치하는지 검증한다.

## 커밋 메시지

- 커밋 메시지는 한국어로 작성한다.
- Conventional Commits 형식을 사용한다.
  - 예: `feat: 기술 검색 필터 개선`
  - 예: `fix: 커맨드 토큰 렌더링 오류 수정`
  - 예: `docs: 프레임 데이터 갱신 절차 보강`
- 허용 타입: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`
- 작은 변경은 제목만으로 충분하다. 설명이 필요한 변경은 본문에 핵심 이유와 검증 결과를 bullet로 적는다.
- AI 공동 작업자 꼬리말(`Co-authored-by: ...`)은 추가하지 않는다.

## PR 규칙

- PR은 사용자가 요청했을 때만 생성한다.
- PR 본문은 `.github/pull_request_template.md`가 있으면 그 구조를 따른다.
- 이슈 연결 문구(`Closes #...`, `Fixes #...`)는 관련 이슈가 있을 때만 넣는다.
- Draft 여부나 라벨 같은 PR 메타데이터는 필수가 아니다. 사용자가 요청한 경우에만 설정한다.
- PR 생성 전에는 제목과 본문 초안을 사용자에게 보여주고 확인을 받는다.

## 검증 보고

- 코드 변경 뒤에는 가능한 검증 명령을 실행하고 결과를 보고한다.
- 실행하지 못한 검증이 있으면 이유와 사용자가 확인할 명령을 남긴다.
- AGENTS.md 규칙에 따라 작업 요청, 변경 내용, 검증 결과를 `implementation-notes.md`에 기록한다.
