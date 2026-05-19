import Foundation

enum L10nTables {
    static func template(for key: L10nKey, language: PromptMeterLanguage) -> String {
        if let translation = table[key]?[language], !translation.isEmpty {
            return translation
        }
        if language != .english, let english = table[key]?[.english], !english.isEmpty {
            return english
        }
        return key.rawValue
    }

    private static let table: [L10nKey: [PromptMeterLanguage: String]] =
        menuTable
            .merging(statusTable) { $1 }
            .merging(providerTable) { $1 }
            .merging(notificationTable) { $1 }
            .merging(settingsTabsTable) { $1 }
            .merging(settingsGeneralTable) { $1 }
            .merging(settingsDisplayTable) { $1 }
            .merging(settingsAdvancedTable) { $1 }
            .merging(settingsProvidersDebugTable) { $1 }
            .merging(settingsAboutTable) { $1 }
            .merging(cadenceTable) { $1 }
            .merging(displayPickerTable) { $1 }
            .merging(languageTable) { $1 }
            .merging(timeTable) { $1 }
            .merging(tooltipTable) { $1 }
            .merging(refreshScheduleTable) { $1 }
            .merging(commonTable) { $1 }

    // MARK: - Menu (popover today usage + footer)

    private static let menuTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .menuTodayUsage: [
            .english: "Today usage",
            .korean: "오늘 사용량",
            .japanese: "今日の使用量",
            .simplifiedChinese: "今日用量",
        ],
        .menuTodayUsageEmptyTitle: [
            .english: "No token usage today",
            .korean: "오늘 토큰 사용 없음",
            .japanese: "今日のトークン使用なし",
            .simplifiedChinese: "今日无 token 使用",
        ],
        .menuTodayUsageEmptySubtitle: [
            .english: "Local session logs are empty",
            .korean: "로컬 세션 로그가 비어 있습니다",
            .japanese: "ローカルセッションログは空です",
            .simplifiedChinese: "本地会话日志为空",
        ],
        .menuTodayUsageIn: [
            .english: "In",
            .korean: "입력",
            .japanese: "入力",
            .simplifiedChinese: "输入",
        ],
        .menuTodayUsageOut: [
            .english: "Out",
            .korean: "출력",
            .japanese: "出力",
            .simplifiedChinese: "输出",
        ],
        .menuTodayUsageCache: [
            .english: "Cache",
            .korean: "캐시",
            .japanese: "キャッシュ",
            .simplifiedChinese: "缓存",
        ],
        .menuTodayUsageEstimated: [
            .english: "Est.",
            .korean: "예상",
            .japanese: "推定",
            .simplifiedChinese: "预计",
        ],
        .menuTodayUsageTokensFormat: [
            .english: "%@ tokens",
            .korean: "%@ 토큰",
            .japanese: "%@ トークン",
            .simplifiedChinese: "%@ tokens",
        ],
        .menuFooterRefresh: [
            .english: "Refresh",
            .korean: "새로고침",
            .japanese: "更新",
            .simplifiedChinese: "刷新",
        ],
        .menuFooterRefreshing: [
            .english: "Refreshing",
            .korean: "새로고침 중",
            .japanese: "更新中",
            .simplifiedChinese: "刷新中",
        ],
        .menuFooterSettings: [
            .english: "Settings",
            .korean: "설정",
            .japanese: "設定",
            .simplifiedChinese: "设置",
        ],
        .menuFooterAbout: [
            .english: "About",
            .korean: "정보",
            .japanese: "情報",
            .simplifiedChinese: "关于",
        ],
        .menuFooterQuit: [
            .english: "Quit",
            .korean: "종료",
            .japanese: "終了",
            .simplifiedChinese: "退出",
        ],
    ]

    // MARK: - Refresh status capsule

    private static let statusTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .statusSyncing: [
            .english: "Syncing",
            .korean: "동기화 중",
            .japanese: "同期中",
            .simplifiedChinese: "同步中",
        ],
        .statusChecking: [
            .english: "Checking",
            .korean: "확인 중",
            .japanese: "確認中",
            .simplifiedChinese: "检查中",
        ],
        .statusNow: [
            .english: "Now",
            .korean: "방금",
            .japanese: "たった今",
            .simplifiedChinese: "刚刚",
        ],
        .statusLogin: [
            .english: "Login",
            .korean: "로그인",
            .japanese: "ログイン",
            .simplifiedChinese: "登录",
        ],
        .statusSetup: [
            .english: "Setup",
            .korean: "설치",
            .japanese: "セットアップ",
            .simplifiedChinese: "安装",
        ],
        .statusOffline: [
            .english: "Offline",
            .korean: "오프라인",
            .japanese: "オフライン",
            .simplifiedChinese: "离线",
        ],
    ]

    // MARK: - Provider state titles, details, and card text

    private static let providerTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .providerCheckingTitleFormat: [
            .english: "Checking %@",
            .korean: "%@ 확인 중",
            .japanese: "%@ を確認中",
            .simplifiedChinese: "正在检查 %@",
        ],
        .providerCheckingCLITitleFormat: [
            .english: "Checking %@ CLI",
            .korean: "%@ CLI 확인 중",
            .japanese: "%@ CLI を確認中",
            .simplifiedChinese: "正在检查 %@ CLI",
        ],
        .providerConnectedTitleFormat: [
            .english: "%@ connected",
            .korean: "%@ 연결됨",
            .japanese: "%@ に接続",
            .simplifiedChinese: "%@ 已连接",
        ],
        .providerMissingCLITitleFormat: [
            .english: "%@ CLI not installed",
            .korean: "%@ CLI 미설치",
            .japanese: "%@ CLI が未インストール",
            .simplifiedChinese: "%@ CLI 未安装",
        ],
        .providerMissingTitleFormat: [
            .english: "%@ not installed",
            .korean: "%@ 미설치",
            .japanese: "%@ が未インストール",
            .simplifiedChinese: "%@ 未安装",
        ],
        .providerNeedsLoginTitleFormat: [
            .english: "%@ login required",
            .korean: "%@ 로그인 필요",
            .japanese: "%@ にログインが必要",
            .simplifiedChinese: "需要登录 %@",
        ],
        .providerUnavailableTitleFormat: [
            .english: "%@ unavailable",
            .korean: "%@ 사용 불가",
            .japanese: "%@ は利用できません",
            .simplifiedChinese: "%@ 不可用",
        ],
        .providerCheckingDetailCodex: [
            .english: "PromptMeter is checking the local Codex app-server.",
            .korean: "PromptMeter가 로컬 Codex app-server를 확인하고 있습니다.",
            .japanese: "PromptMeter がローカルの Codex app-server を確認しています。",
            .simplifiedChinese: "PromptMeter 正在检查本地 Codex app-server。",
        ],
        .providerCheckingDetailClaude: [
            .english: "PromptMeter is checking the local Claude Code CLI.",
            .korean: "PromptMeter가 로컬 Claude Code CLI를 확인하고 있습니다.",
            .japanese: "PromptMeter がローカルの Claude Code CLI を確認しています。",
            .simplifiedChinese: "PromptMeter 正在检查本地 Claude Code CLI。",
        ],
        .providerCheckingDetailGemini: [
            .english: "PromptMeter is checking the local Gemini CLI.",
            .korean: "PromptMeter가 로컬 Gemini CLI를 확인하고 있습니다.",
            .japanese: "PromptMeter がローカルの Gemini CLI を確認しています。",
            .simplifiedChinese: "PromptMeter 正在检查本地 Gemini CLI。",
        ],
        .providerCodexConnectedDetailWithEmailFormat: [
            .english: "Reading live quota for %@.",
            .korean: "%@ 계정의 실시간 quota를 읽고 있습니다.",
            .japanese: "%@ のライブクオータを読み取っています。",
            .simplifiedChinese: "正在读取 %@ 的实时配额。",
        ],
        .providerCodexConnectedDetailNoEmail: [
            .english: "Reading live quota through the local Codex CLI.",
            .korean: "로컬 Codex CLI를 통해 실시간 quota를 읽고 있습니다.",
            .japanese: "ローカルの Codex CLI を通じてライブクオータを読み取っています。",
            .simplifiedChinese: "通过本地 Codex CLI 读取实时配额。",
        ],
        .providerClaudeConnectedDetailWithEmailFormat: [
            .english: "Reading Claude Code usage through the OAuth API for %@.",
            .korean: "%@ 계정의 Claude Code 사용량을 OAuth API로 읽고 있습니다.",
            .japanese: "%@ の Claude Code 使用量を OAuth API で読み取っています。",
            .simplifiedChinese: "通过 OAuth API 读取 %@ 的 Claude Code 用量。",
        ],
        .providerClaudeConnectedDetailNoEmail: [
            .english: "Reading Claude Code usage through the OAuth API.",
            .korean: "Claude Code 사용량을 OAuth API로 읽고 있습니다.",
            .japanese: "Claude Code の使用量を OAuth API で読み取っています。",
            .simplifiedChinese: "通过 OAuth API 读取 Claude Code 用量。",
        ],
        .providerGeminiConnectedDetailFormat: [
            .english: "Reading quota through %@.",
            .korean: "%@를 통해 quota를 읽고 있습니다.",
            .japanese: "%@ を通じてクオータを読み取っています。",
            .simplifiedChinese: "通过 %@ 读取配额。",
        ],
        .providerMissingCLIDetailCodex: [
            .english: "Install Codex CLI and sign in before refreshing usage.",
            .korean: "사용량을 새로고침하기 전에 Codex CLI를 설치하고 로그인하세요.",
            .japanese: "使用量を更新する前に Codex CLI をインストールしてサインインしてください。",
            .simplifiedChinese: "刷新用量前请先安装 Codex CLI 并登录。",
        ],
        .providerMissingCLIDetailClaude: [
            .english: "Install Claude Code and sign in before refreshing usage.",
            .korean: "사용량을 새로고침하기 전에 Claude Code를 설치하고 로그인하세요.",
            .japanese: "使用量を更新する前に Claude Code をインストールしてサインインしてください。",
            .simplifiedChinese: "刷新用量前请先安装 Claude Code 并登录。",
        ],
        .providerMissingCLIDetailGemini: [
            .english: "Install Gemini CLI and sign in before refreshing usage.",
            .korean: "사용량을 새로고침하기 전에 Gemini CLI를 설치하고 로그인하세요.",
            .japanese: "使用量を更新する前に Gemini CLI をインストールしてサインインしてください。",
            .simplifiedChinese: "刷新用量前请先安装 Gemini CLI 并登录。",
        ],
        .providerNeedsLoginDetailGenericFormat: [
            .english: "Run %@ in Terminal, then refresh PromptMeter.",
            .korean: "터미널에서 %@을(를) 실행한 후 PromptMeter를 새로고침하세요.",
            .japanese: "ターミナルで %@ を実行してから PromptMeter を更新してください。",
            .simplifiedChinese: "在终端中运行 %@，然后刷新 PromptMeter。",
        ],
        .providerNeedsLoginDetailGemini: [
            .english: "Run gemini in Terminal and sign in with Google.",
            .korean: "터미널에서 gemini를 실행하고 Google 계정으로 로그인하세요.",
            .japanese: "ターミナルで gemini を実行し、Google アカウントでサインインしてください。",
            .simplifiedChinese: "在终端中运行 gemini 并使用 Google 账号登录。",
        ],
        .providerLoginRequiredPlan: [
            .english: "Login required",
            .korean: "로그인 필요",
            .japanese: "ログインが必要",
            .simplifiedChinese: "需要登录",
        ],
        .providerUnavailablePlan: [
            .english: "Unavailable",
            .korean: "사용 불가",
            .japanese: "利用不可",
            .simplifiedChinese: "不可用",
        ],
        .providerLoginRequiredCardDetailFormat: [
            .english: "Run %@ from Terminal.",
            .korean: "터미널에서 %@을(를) 실행하세요.",
            .japanese: "ターミナルから %@ を実行してください。",
            .simplifiedChinese: "在终端中运行 %@。",
        ],
        .providerLoginRequiredCardDetailGeminiFormat: [
            .english: "Run %@ and sign in with Google.",
            .korean: "%@을(를) 실행하고 Google 계정으로 로그인하세요.",
            .japanese: "%@ を実行し、Google アカウントでサインインしてください。",
            .simplifiedChinese: "运行 %@ 并使用 Google 账号登录。",
        ],
        .providerClaudeNoRateLimits: [
            .english: "Claude OAuth usage did not include rate limits.",
            .korean: "Claude OAuth 사용량에 rate limit이 포함되지 않았습니다.",
            .japanese: "Claude OAuth の使用量にはレート制限が含まれていません。",
            .simplifiedChinese: "Claude OAuth 用量未包含速率限制信息。",
        ],
        .providerGeminiNoQuotaPercentages: [
            .english: "Gemini stats did not include quota percentages.",
            .korean: "Gemini stats에 quota 퍼센트가 포함되지 않았습니다.",
            .japanese: "Gemini の stats にクオータの割合が含まれていません。",
            .simplifiedChinese: "Gemini stats 未包含配额百分比。",
        ],
        .providerInstallActionTitle: [
            .english: "Local CLI required",
            .korean: "로컬 CLI 필요",
            .japanese: "ローカル CLI が必要",
            .simplifiedChinese: "需要本地 CLI",
        ],
        .providerInstallActionDetailCodex: [
            .english: "Install Codex CLI with npm or Homebrew, then run codex login.",
            .korean: "npm 또는 Homebrew로 Codex CLI를 설치한 후 codex login을 실행하세요.",
            .japanese: "npm または Homebrew で Codex CLI をインストールし、codex login を実行してください。",
            .simplifiedChinese: "通过 npm 或 Homebrew 安装 Codex CLI，然后运行 codex login。",
        ],
        .providerInstallActionDetailClaude: [
            .english: "Install Claude Code, then sign in with your Claude account.",
            .korean: "Claude Code를 설치한 후 Claude 계정으로 로그인하세요.",
            .japanese: "Claude Code をインストールし、Claude アカウントでサインインしてください。",
            .simplifiedChinese: "安装 Claude Code，然后使用 Claude 账号登录。",
        ],
        .providerInstallActionDetailGeminiFormat: [
            .english: "Install Gemini CLI, then run %@ to sign in.",
            .korean: "Gemini CLI를 설치한 후 %@을(를) 실행해 로그인하세요.",
            .japanese: "Gemini CLI をインストールし、%@ を実行してサインインしてください。",
            .simplifiedChinese: "安装 Gemini CLI，然后运行 %@ 登录。",
        ],
        .providerInstallCommandTitle: [
            .english: "Install command",
            .korean: "설치 명령",
            .japanese: "インストールコマンド",
            .simplifiedChinese: "安装命令",
        ],
        .providerInstallGuideButton: [
            .english: "Guide",
            .korean: "가이드",
            .japanese: "ガイド",
            .simplifiedChinese: "指南",
        ],
        .providerLoginCommandTitle: [
            .english: "Login command",
            .korean: "로그인 명령",
            .japanese: "ログインコマンド",
            .simplifiedChinese: "登录命令",
        ],
        .providerCopyButton: [
            .english: "Copy",
            .korean: "복사",
            .japanese: "コピー",
            .simplifiedChinese: "复制",
        ],
    ]

    // MARK: - Notifications

    private static let notificationTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .notificationQuotaLowSingleTitleFormat: [
            .english: "%1$@ %2$@ quota low",
            .korean: "%1$@ %2$@ quota 부족",
            .japanese: "%1$@ %2$@ クオータ残りわずか",
            .simplifiedChinese: "%1$@ %2$@ 配额不足",
        ],
        .notificationQuotaLowSingleBodyFormat: [
            .english: "%1$@ remaining is %2$d%%.",
            .korean: "%1$@ 잔여량 %2$d%%.",
            .japanese: "%1$@ の残量は %2$d%%。",
            .simplifiedChinese: "%1$@ 剩余 %2$d%%。",
        ],
        .notificationQuotaLowMultiTitleProviderFormat: [
            .english: "%@ quota low",
            .korean: "%@ quota 부족",
            .japanese: "%@ クオータ残りわずか",
            .simplifiedChinese: "%@ 配额不足",
        ],
        .notificationQuotaLowMultiTitleGeneric: [
            .english: "Provider quota low",
            .korean: "Provider quota 부족",
            .japanese: "プロバイダーのクオータ残りわずか",
            .simplifiedChinese: "Provider 配额不足",
        ],
        .notificationQuotaLowMultiBodyFormat: [
            .english: "%@ remaining.",
            .korean: "%@ 남음.",
            .japanese: "%@ 残り。",
            .simplifiedChinese: "%@ 剩余。",
        ],
        .notificationQuotaLowSummaryWithProviderFormat: [
            .english: "%1$@ %2$@ %3$d%%",
            .korean: "%1$@ %2$@ %3$d%%",
            .japanese: "%1$@ %2$@ %3$d%%",
            .simplifiedChinese: "%1$@ %2$@ %3$d%%",
        ],
        .notificationQuotaLowSummaryNoProviderFormat: [
            .english: "%1$@ %2$d%%",
            .korean: "%1$@ %2$d%%",
            .japanese: "%1$@ %2$d%%",
            .simplifiedChinese: "%1$@ %2$d%%",
        ],
    ]

    // MARK: - Settings tabs + header

    private static let settingsTabsTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .settingsTabsGeneral: [
            .english: "General",
            .korean: "일반",
            .japanese: "一般",
            .simplifiedChinese: "通用",
        ],
        .settingsTabsProviders: [
            .english: "Providers",
            .korean: "Provider",
            .japanese: "プロバイダー",
            .simplifiedChinese: "Provider",
        ],
        .settingsTabsDisplay: [
            .english: "Display",
            .korean: "표시",
            .japanese: "表示",
            .simplifiedChinese: "显示",
        ],
        .settingsTabsAdvanced: [
            .english: "Advanced",
            .korean: "고급",
            .japanese: "詳細",
            .simplifiedChinese: "高级",
        ],
        .settingsTabsAbout: [
            .english: "About",
            .korean: "정보",
            .japanese: "情報",
            .simplifiedChinese: "关于",
        ],
        .settingsHeaderSubtitle: [
            .english: "Settings",
            .korean: "설정",
            .japanese: "設定",
            .simplifiedChinese: "设置",
        ],
    ]

    // MARK: - Settings - General

    private static let settingsGeneralTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .settingsGeneralAppCard: [
            .english: "App",
            .korean: "앱",
            .japanese: "アプリ",
            .simplifiedChinese: "应用",
        ],
        .settingsGeneralStartAtLoginTitle: [
            .english: "Start at login",
            .korean: "로그인 시 실행",
            .japanese: "ログイン時に起動",
            .simplifiedChinese: "开机自启",
        ],
        .settingsGeneralStartAtLoginDetail: [
            .english: "Open PromptMeter quietly in the menu bar.",
            .korean: "PromptMeter를 메뉴 바에서 조용히 시작합니다.",
            .japanese: "PromptMeter をメニューバーで静かに起動します。",
            .simplifiedChinese: "在菜单栏中静默启动 PromptMeter。",
        ],
        .settingsGeneralRefreshCadenceTitle: [
            .english: "Refresh cadence",
            .korean: "새로고침 주기",
            .japanese: "更新間隔",
            .simplifiedChinese: "刷新频率",
        ],
        .settingsGeneralRefreshCadenceDetail: [
            .english: "Background provider usage refresh interval.",
            .korean: "백그라운드에서 provider 사용량을 갱신하는 주기입니다.",
            .japanese: "プロバイダー使用量をバックグラウンドで更新する間隔。",
            .simplifiedChinese: "后台 provider 用量的刷新间隔。",
        ],
        .settingsGeneralLanguageTitle: [
            .english: "Language",
            .korean: "언어",
            .japanese: "言語",
            .simplifiedChinese: "语言",
        ],
        .settingsGeneralLanguageDetail: [
            .english: "Display language for the popover, settings, and notifications.",
            .korean: "팝오버, 설정, 알림에 사용할 표시 언어입니다.",
            .japanese: "ポップオーバー、設定、通知の表示言語。",
            .simplifiedChinese: "弹出窗口、设置和通知的显示语言。",
        ],
        .settingsGeneralRefreshCard: [
            .english: "Refresh",
            .korean: "새로고침",
            .japanese: "更新",
            .simplifiedChinese: "刷新",
        ],
        .settingsGeneralRefreshScheduleTitle: [
            .english: "Schedule",
            .korean: "스케줄",
            .japanese: "スケジュール",
            .simplifiedChinese: "调度",
        ],
        .settingsGeneralRefreshNowTitle: [
            .english: "Refresh now",
            .korean: "지금 새로고침",
            .japanese: "今すぐ更新",
            .simplifiedChinese: "立即刷新",
        ],
        .settingsGeneralRefreshNowDetail: [
            .english: "Pull the latest provider quota from local CLIs.",
            .korean: "로컬 CLI에서 최신 provider quota를 가져옵니다.",
            .japanese: "ローカルの CLI から最新のプロバイダークオータを取得します。",
            .simplifiedChinese: "从本地 CLI 拉取最新的 provider 配额。",
        ],
        .settingsGeneralRefreshNowButton: [
            .english: "Refresh",
            .korean: "새로고침",
            .japanese: "更新",
            .simplifiedChinese: "刷新",
        ],
        .settingsGeneralRefreshingButton: [
            .english: "Refreshing",
            .korean: "새로고침 중",
            .japanese: "更新中",
            .simplifiedChinese: "刷新中",
        ],
    ]

    // MARK: - Settings - Display

    private static let settingsDisplayTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .settingsDisplayMenuBarCard: [
            .english: "Menu Bar",
            .korean: "메뉴 바",
            .japanese: "メニューバー",
            .simplifiedChinese: "菜单栏",
        ],
        .settingsDisplayUsageValueTitle: [
            .english: "Usage value",
            .korean: "사용량 표시",
            .japanese: "使用量の値",
            .simplifiedChinese: "用量数值",
        ],
        .settingsDisplayUsageValueDetail: [
            .english: "Choose whether bars show remaining quota or consumed quota.",
            .korean: "바에 잔여 quota를 표시할지, 사용된 quota를 표시할지 선택합니다.",
            .japanese: "バーに残量を表示するか、消費量を表示するかを選びます。",
            .simplifiedChinese: "选择进度条显示剩余配额还是已用配额。",
        ],
        .settingsDisplayResetFormatTitle: [
            .english: "Reset format",
            .korean: "리셋 표시",
            .japanese: "リセット表示",
            .simplifiedChinese: "重置格式",
        ],
        .settingsDisplayResetFormatDetail: [
            .english: "Show reset as a clean clock value or a countdown.",
            .korean: "리셋을 시계 형식 또는 카운트다운으로 표시합니다.",
            .japanese: "リセットを時計形式またはカウントダウンで表示します。",
            .simplifiedChinese: "以时钟时间或倒计时显示重置。",
        ],
        .settingsDisplayPopoverCard: [
            .english: "Popover",
            .korean: "팝오버",
            .japanese: "ポップオーバー",
            .simplifiedChinese: "弹出窗口",
        ],
        .settingsDisplayLayoutTitle: [
            .english: "Layout",
            .korean: "레이아웃",
            .japanese: "レイアウト",
            .simplifiedChinese: "布局",
        ],
        .settingsDisplayLayoutValue: [
            .english: "Aligned compact rows",
            .korean: "정렬된 컴팩트 행",
            .japanese: "整列されたコンパクトな行",
            .simplifiedChinese: "对齐的紧凑行",
        ],
        .settingsDisplayMenuBarRowTitle: [
            .english: "Menu bar",
            .korean: "메뉴 바",
            .japanese: "メニューバー",
            .simplifiedChinese: "菜单栏",
        ],
        .settingsDisplayMenuBarRowValue: [
            .english: "Icon only",
            .korean: "아이콘만",
            .japanese: "アイコンのみ",
            .simplifiedChinese: "仅图标",
        ],
    ]

    // MARK: - Settings - Advanced

    private static let settingsAdvancedTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .settingsAdvancedPrivacyCard: [
            .english: "Privacy",
            .korean: "프라이버시",
            .japanese: "プライバシー",
            .simplifiedChinese: "隐私",
        ],
        .settingsAdvancedHidePersonalInformationTitle: [
            .english: "Hide personal information",
            .korean: "개인 정보 숨기기",
            .japanese: "個人情報を隠す",
            .simplifiedChinese: "隐藏个人信息",
        ],
        .settingsAdvancedHidePersonalInformationDetail: [
            .english: "Obscure account emails in settings.",
            .korean: "설정에서 계정 이메일을 가립니다.",
            .japanese: "設定でアカウントのメールアドレスを隠します。",
            .simplifiedChinese: "在设置中隐藏账户邮箱。",
        ],
        .settingsAdvancedToolsCard: [
            .english: "Tools",
            .korean: "도구",
            .japanese: "ツール",
            .simplifiedChinese: "工具",
        ],
        .settingsAdvancedProviderCLIsTitle: [
            .english: "Provider CLIs",
            .korean: "Provider CLI",
            .japanese: "プロバイダー CLI",
            .simplifiedChinese: "Provider CLI",
        ],
        .settingsAdvancedProviderCLIsDetail: [
            .english: "PromptMeter reads usage through local provider CLIs.",
            .korean: "PromptMeter는 로컬 provider CLI를 통해 사용량을 읽습니다.",
            .japanese: "PromptMeter はローカルのプロバイダー CLI を通じて使用量を読み取ります。",
            .simplifiedChinese: "PromptMeter 通过本地 provider CLI 读取用量。",
        ],
        .settingsAdvancedDiagnosticsCard: [
            .english: "Diagnostics",
            .korean: "진단",
            .japanese: "診断",
            .simplifiedChinese: "诊断",
        ],
        .settingsAdvancedDebugModeTitle: [
            .english: "Debug mode",
            .korean: "디버그 모드",
            .japanese: "デバッグモード",
            .simplifiedChinese: "调试模式",
        ],
        .settingsAdvancedDebugModeDetail: [
            .english: "Expose provider CLI paths, raw plans, and limit identifiers.",
            .korean: "provider CLI 경로, 원본 플랜, 한도 식별자를 노출합니다.",
            .japanese: "プロバイダー CLI のパス、元のプラン、制限識別子を表示します。",
            .simplifiedChinese: "显示 provider CLI 路径、原始套餐和限制标识符。",
        ],
    ]

    // MARK: - Settings - Providers debug rows

    private static let settingsProvidersDebugTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .settingsProvidersDebugCLI: [
            .english: "CLI",
            .korean: "CLI",
            .japanese: "CLI",
            .simplifiedChinese: "CLI",
        ],
        .settingsProvidersDebugVersion: [
            .english: "Version",
            .korean: "버전",
            .japanese: "バージョン",
            .simplifiedChinese: "版本",
        ],
        .settingsProvidersDebugRawPlan: [
            .english: "Raw plan",
            .korean: "원본 플랜",
            .japanese: "元のプラン",
            .simplifiedChinese: "原始套餐",
        ],
        .settingsProvidersDebugLimit: [
            .english: "Limit",
            .korean: "한도",
            .japanese: "制限",
            .simplifiedChinese: "限制",
        ],
        .settingsProvidersDebugAuth: [
            .english: "Auth",
            .korean: "인증",
            .japanese: "認証",
            .simplifiedChinese: "认证",
        ],
        .settingsProvidersDebugProvider: [
            .english: "Provider",
            .korean: "Provider",
            .japanese: "プロバイダー",
            .simplifiedChinese: "Provider",
        ],
        .settingsProvidersDebugUsageSource: [
            .english: "Usage source",
            .korean: "사용량 소스",
            .japanese: "使用量ソース",
            .simplifiedChinese: "用量来源",
        ],
        .settingsProvidersDebugCredential: [
            .english: "Credential",
            .korean: "자격증명",
            .japanese: "認証情報",
            .simplifiedChinese: "凭证",
        ],
        .settingsProvidersDebugRateTier: [
            .english: "Rate tier",
            .korean: "Rate tier",
            .japanese: "レート区分",
            .simplifiedChinese: "速率层级",
        ],
        .settingsProvidersDebugTokenExpiry: [
            .english: "Token expiry",
            .korean: "토큰 만료",
            .japanese: "トークン有効期限",
            .simplifiedChinese: "Token 过期",
        ],
    ]

    // MARK: - Settings - About

    private static let settingsAboutTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .settingsAboutVersionLabelFormat: [
            .english: "Version %@",
            .korean: "버전 %@",
            .japanese: "バージョン %@",
            .simplifiedChinese: "版本 %@",
        ],
        .settingsAboutTagline: [
            .english: "A quiet menu bar meter for prompt usage.",
            .korean: "프롬프트 사용량을 조용히 측정하는 메뉴 바 미터.",
            .japanese: "プロンプト使用量を静かに計測するメニューバーメーター。",
            .simplifiedChinese: "静默测量提示词用量的菜单栏度量器。",
        ],
        .settingsAboutCopyrightFormat: [
            .english: "© %@ PromptMeter",
            .korean: "© %@ PromptMeter",
            .japanese: "© %@ PromptMeter",
            .simplifiedChinese: "© %@ PromptMeter",
        ],
        .settingsAboutGitHubButton: [
            .english: "GitHub",
            .korean: "GitHub",
            .japanese: "GitHub",
            .simplifiedChinese: "GitHub",
        ],
    ]

    // MARK: - Cadence display

    private static let cadenceTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .cadenceThirtySeconds: [
            .english: "30 sec",
            .korean: "30초",
            .japanese: "30 秒",
            .simplifiedChinese: "30 秒",
        ],
        .cadenceOneMinute: [
            .english: "1 min",
            .korean: "1분",
            .japanese: "1 分",
            .simplifiedChinese: "1 分钟",
        ],
        .cadenceFiveMinutes: [
            .english: "5 min",
            .korean: "5분",
            .japanese: "5 分",
            .simplifiedChinese: "5 分钟",
        ],
        .cadenceFifteenMinutes: [
            .english: "15 min",
            .korean: "15분",
            .japanese: "15 分",
            .simplifiedChinese: "15 分钟",
        ],
    ]

    // MARK: - Display picker enums (usage basis, reset style) + quota windows

    private static let displayPickerTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .usageBasisRemaining: [
            .english: "Remaining",
            .korean: "잔여",
            .japanese: "残り",
            .simplifiedChinese: "剩余",
        ],
        .usageBasisUsed: [
            .english: "Used",
            .korean: "사용됨",
            .japanese: "使用済み",
            .simplifiedChinese: "已用",
        ],
        .resetStyleClock: [
            .english: "Clock",
            .korean: "시계",
            .japanese: "時計",
            .simplifiedChinese: "时钟",
        ],
        .resetStyleCountdown: [
            .english: "Countdown",
            .korean: "카운트다운",
            .japanese: "カウントダウン",
            .simplifiedChinese: "倒计时",
        ],
        .quotaWindowSession: [
            .english: "Session",
            .korean: "세션",
            .japanese: "セッション",
            .simplifiedChinese: "会话",
        ],
        .quotaWindowWeekly: [
            .english: "Weekly",
            .korean: "주간",
            .japanese: "週間",
            .simplifiedChinese: "每周",
        ],
    ]

    // MARK: - Language picker labels (shown in their own script)

    private static let languageTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .languageSystemFormat: [
            .english: "System (%@)",
            .korean: "시스템 (%@)",
            .japanese: "システム (%@)",
            .simplifiedChinese: "系统 (%@)",
        ],
        .languageEnglish: [
            .english: "English",
            .korean: "English",
            .japanese: "English",
            .simplifiedChinese: "English",
        ],
        .languageKorean: [
            .english: "한국어",
            .korean: "한국어",
            .japanese: "한국어",
            .simplifiedChinese: "한국어",
        ],
        .languageJapanese: [
            .english: "日本語",
            .korean: "日本語",
            .japanese: "日本語",
            .simplifiedChinese: "日本語",
        ],
        .languageSimplifiedChinese: [
            .english: "简体中文",
            .korean: "简体中文",
            .japanese: "简体中文",
            .simplifiedChinese: "简体中文",
        ],
    ]

    // MARK: - Time / units / token expiry

    private static let timeTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .timeNow: [
            .english: "Now",
            .korean: "지금",
            .japanese: "今すぐ",
            .simplifiedChinese: "现在",
        ],
        .timeTodayFormat: [
            .english: "Today %@",
            .korean: "오늘 %@",
            .japanese: "今日 %@",
            .simplifiedChinese: "今天 %@",
        ],
        .unitMinuteShortFormat: [
            .english: "%dm",
            .korean: "%d분",
            .japanese: "%d分",
            .simplifiedChinese: "%d分",
        ],
        .unitHourShortFormat: [
            .english: "%dh",
            .korean: "%d시간",
            .japanese: "%d時間",
            .simplifiedChinese: "%d时",
        ],
        .unitDayShortFormat: [
            .english: "%dd",
            .korean: "%d일",
            .japanese: "%d日",
            .simplifiedChinese: "%d天",
        ],
        .unitDayHourShortFormat: [
            .english: "%1$dd %2$dh",
            .korean: "%1$d일 %2$d시간",
            .japanese: "%1$d日 %2$d時間",
            .simplifiedChinese: "%1$d天 %2$d时",
        ],
        .unitHourMinuteShortFormat: [
            .english: "%1$dh %2$dm",
            .korean: "%1$d시간 %2$d분",
            .japanese: "%1$d時間 %2$d分",
            .simplifiedChinese: "%1$d时 %2$d分",
        ],
        .tokenExpiryNow: [
            .english: "Now",
            .korean: "곧",
            .japanese: "まもなく",
            .simplifiedChinese: "即将",
        ],
    ]

    // MARK: - Status item tooltip

    private static let tooltipTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .tooltipBaseEstimatedTokensFormat: [
            .english: "PromptMeter - %@ estimated tokens",
            .korean: "PromptMeter - 예상 토큰 %@",
            .japanese: "PromptMeter - 推定トークン %@",
            .simplifiedChinese: "PromptMeter - 预计 token %@",
        ],
        .tooltipBaseWithUsageFormat: [
            .english: "PromptMeter - %1$@ estimated tokens · %2$@",
            .korean: "PromptMeter - 예상 토큰 %1$@ · %2$@",
            .japanese: "PromptMeter - 推定トークン %1$@ · %2$@",
            .simplifiedChinese: "PromptMeter - 预计 token %1$@ · %2$@",
        ],
        .tooltipUsageProviderSessionLeftFormat: [
            .english: "%1$@ session %2$@ left",
            .korean: "%1$@ 세션 %2$@ 잔여",
            .japanese: "%1$@ セッション残り %2$@",
            .simplifiedChinese: "%1$@ 会话剩余 %2$@",
        ],
    ]

    // MARK: - Provider refresh schedule

    private static let refreshScheduleTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .refreshScheduleNotRefreshedYet: [
            .english: "Not refreshed yet",
            .korean: "아직 새로고침하지 않음",
            .japanese: "まだ更新していません",
            .simplifiedChinese: "尚未刷新",
        ],
        .refreshScheduleLastOnlyFormat: [
            .english: "Last %@",
            .korean: "마지막 %@",
            .japanese: "前回 %@",
            .simplifiedChinese: "上次 %@",
        ],
        .refreshScheduleLastAndNextFormat: [
            .english: "Last %1$@ · Next %2$@",
            .korean: "마지막 %1$@ · 다음 %2$@",
            .japanese: "前回 %1$@ · 次回 %2$@",
            .simplifiedChinese: "上次 %1$@ · 下次 %2$@",
        ],
    ]

    // MARK: - Common shared values

    private static let commonTable: [L10nKey: [PromptMeterLanguage: String]] = [
        .commonDash: [
            .english: "--",
            .korean: "--",
            .japanese: "--",
            .simplifiedChinese: "--",
        ],
        .commonPercentFormat: [
            .english: "%d%%",
            .korean: "%d%%",
            .japanese: "%d%%",
            .simplifiedChinese: "%d%%",
        ],
    ]
}
