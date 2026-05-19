# PromptMeter

[English](README.md) · **한국어** · [日本語](README.ja.md) · [中文](README.zh.md)

[![macOS](https://img.shields.io/badge/macOS-26%2B-0a0a0c?style=flat-square)](https://github.com/minhee0000/PromptMeter)
[![Version](https://img.shields.io/badge/version-0.1.0-16d3b4?style=flat-square)](https://github.com/minhee0000/PromptMeter)
[![License: MIT](https://img.shields.io/badge/license-MIT-6e5aff?style=flat-square)](LICENSE)

PromptMeter는 매일 AI 코딩 어시스턴트와 함께 일하는 사람들을 위한 macOS 메뉴 바 앱입니다. 여러 대시보드를 열거나 CLI 출력을 뒤지지 않아도 현재 사용 가능한 quota, 리셋 시점, 로컬 토큰 사용량을 한눈에 볼 수 있게 해줍니다.

현재는 Codex, Claude Code, Gemini CLI를 지원합니다.

## 스크린샷

<!-- TODO: 팝오버 캡처가 준비되면 docs/screenshot.png로 교체. -->

_메뉴 바 팝오버 스크린샷 — 곧 추가됩니다._

## 왜 만들었나

AI 코딩 도구는 강력하지만, 그 한도는 놓치기 쉽습니다:

- 지금 Codex 세션이 얼마나 남았지?
- Claude Code 윈도우는 언제 리셋되지?
- Gemini CLI는 설치되어 있고 로그인되어 있나?
- 오늘 토큰을 얼마나 썼지?
- 어느 provider가 가장 빨리 떨어지지?

PromptMeter는 이런 답을 메뉴 바와 간단한 팝오버에 띄워서, 컨텍스트 전환 없이 계속 작업할 수 있게 해줍니다.

## 기능

- 가장 적게 남은 provider 세션을 보여주는 **메뉴 바 상태 표시**.
- Codex, Claude Code, Gemini CLI별 **Provider 카드**.
- 로컬 Codex/Claude Code JSONL 로그에서 집계한 **오늘 사용량**.
- 모델별 로컬 요율 추정치를 사용하는 **예상 토큰 비용**.
- 시계 또는 카운트다운으로 표시되는 **Quota 리셋**.
- Provider 윈도우가 임계치에 가까워지면 보내는 **낮은 quota 알림**.
- 설치/로그인 명령어가 설정에 표시되는 **CLI 누락 감지**.
- UI에서 계정 이메일을 숨기는 **프라이버시 토글**.
- 조용한 메뉴 바 워크플로우를 위한 **로그인 시 자동 실행**.
- 새로 추가된 로그만 다시 읽는 **점진적 로그 스캔**.

## Provider 지원

| Provider | 상태 | PromptMeter가 읽는 데이터 |
| --- | --- | --- |
| Codex | 지원 | 로컬 CLI/app-server quota, 플랜, 계정, 세션 한도, 로컬 토큰 사용량 로그 |
| Claude Code | 지원 | OAuth 사용량, 구독, 리셋 윈도우, 로컬 토큰 사용량 로그 |
| Gemini CLI | 지원 | 로컬 CLI `/stats model` quota 출력 |

PromptMeter는 OpenAI, Anthropic, Google과 어떠한 제휴 관계도 없습니다. 로컬에 설치된 도구와 세션 로그를 통해 접근 가능한 데이터만 읽습니다.

## 프라이버시

PromptMeter는 로컬 우선으로 설계되었습니다:

- 프롬프트 텍스트는 토큰 추정을 위해 로컬에서만 처리됩니다.
- 로컬 토큰 사용량은 사용자 컴퓨터의 파일에서 계산됩니다.
- 사용량 스캔 캐시에는 집계 카운트, 파일 시그니처, 오프셋, 파서 상태만 저장됩니다.
- 계정 이메일은 설정 UI에서 숨길 수 있습니다.

Claude Code OAuth 자격증명은 macOS Keychain을 통해 읽으며, 토큰 갱신이 필요할 때는 PromptMeter 자체 Keychain 항목에 캐시합니다.

## macOS 권한

PromptMeter는 macOS에서 조용히 동작합니다 — Screen Recording, Accessibility, Full Disk Access 어느 것도 요구하지 않습니다.

- **Keychain (macOS가 프롬프트 표시)** — 첫 새로고침 시 PromptMeter는 Claude Code CLI가 저장한 Claude OAuth 자격증명(`Claude Code-credentials` 항목)을 읽고, 백그라운드 새로고침에서 재프롬프트가 뜨지 않도록 갱신 가능한 사본을 자체 Keychain 항목(`com.seo.promptMeter.oauth-cache`)에 캐시합니다. 초기 프롬프트도 완전히 없애려면:
  1. **Keychain Access.app** → login keychain을 엽니다.
  2. 프롬프트된 항목(보통 `Claude Code-credentials`)을 찾아 엽니다.
  3. **Access Control**에서 `PromptMeter.app`을 "Always allow access by these applications"에 추가합니다.
  4. PromptMeter를 다시 실행합니다.
- **알림 (선택)** — 낮은 quota 알림을 켰을 때만 요청합니다. 거부해도 다른 기능은 그대로 동작합니다.
- **로그인 항목 (선택)** — 설정 → General → "Start at login"은 `SMAppService`를 사용하며, macOS가 PromptMeter를 로그인 항목에 추가하기 전에 한 번 묻습니다.

비밀번호는 저장하지 않습니다. Provider CLI는 각자의 인증을 그대로 관리합니다.

## 프로젝트 구조

```text
PromptMeter/
  App/        앱 진입점, 앱 델리게이트, 팝오버 호스트
  Core/       메인 앱 모델, 설정, 프롬프트 메트릭, 알림
  Menu/       메뉴 바 팝오버 뷰와 메뉴 데이터 모델
  Providers/  Codex, Claude Code, Gemini CLI 클라이언트와 사용량 매핑
  Settings/   설정 윈도우, 탭, 재사용 가능한 설정 컴포넌트
  Usage/      로컬 토큰 사용량 스캐너, 가격, 파일 캐시, 스냅샷
```

Xcode 프로젝트는 파일 시스템 동기화 루트 그룹을 사용하므로, 디스크의 트리가 곧 소스 레이아웃입니다.

## 빌드

요구 사항:

- macOS
- Xcode
- SwiftUI/AppKit 툴체인
- 선택적 provider CLI:
  - `codex`
  - `claude`
  - `gemini`

클론 후 열기:

```bash
git clone git@github.com:minhee0000/PromptMeter.git
cd PromptMeter
open PromptMeter.xcodeproj
```

이후 Xcode에서 `PromptMeter` scheme를 빌드하고 실행합니다.

현재 프로젝트는 macOS 메뉴 바 앱(`LSUIElement`)으로 구성되어 있으며, 체크인된 Xcode 프로젝트가 사용하는 macOS SDK를 대상으로 합니다.

## 사용 방법

1. 사용 중인 provider CLI를 설치하고 로그인합니다.
2. PromptMeter를 실행합니다.
3. 메뉴 바 팝오버를 열어 quota, 리셋 윈도우, 오늘 사용량을 확인합니다.
4. 설정에서 새로고침 주기, 표시 방식, 프라이버시, 로그인 시 실행을 구성합니다.

CLI가 없는 경우 PromptMeter는 설정에 해당 provider를 계속 표시하되, 메인 팝오버에는 위젯을 노출하지 않습니다.

## 참고 사항

- 사용량과 비용 수치는 로컬 로그와 모델별 요율 테이블에 기반한 추정치입니다.
- Provider API와 CLI 출력은 변경될 수 있으므로, PromptMeter는 응답이 사용 불가하거나 rate limit에 걸린 경우 방어적으로 처리합니다.
- Claude의 HTTP 429 응답에 대해서는 이전 성공 스냅샷을 유지하고 backoff 후 재시도합니다.

## 로드맵

- 주간 사용량 요약.
- 일별 사용 추세를 보여주는 차트 뷰 옵션.
- 추가 provider 통합.
- 서명된 릴리스 빌드.
- 지원용 진단 정보 가져오기/내보내기.

## 라이선스

MIT © minhee0000. 자세한 내용은 [LICENSE](LICENSE)를 참고하세요.
