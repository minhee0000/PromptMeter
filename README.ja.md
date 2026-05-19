# PromptMeter

[English](README.md) · [한국어](README.ko.md) · **日本語** · [中文](README.zh.md)

[![macOS](https://img.shields.io/badge/macOS-26%2B-0a0a0c?style=flat-square)](https://github.com/minhee0000/PromptMeter)
[![Version](https://img.shields.io/badge/version-0.1.0-16d3b4?style=flat-square)](https://github.com/minhee0000/PromptMeter)
[![License: MIT](https://img.shields.io/badge/license-MIT-6e5aff?style=flat-square)](LICENSE)

PromptMeter は、AI コーディングアシスタントを毎日使う人のための macOS メニューバーアプリです。複数のダッシュボードを開いたり CLI の出力を漁ったりしなくても、現在のクオータ、リセット時刻、ローカルトークン使用量を常に把握できます。

現在は Codex、Claude Code、Gemini CLI に対応しています。

## スクリーンショット

<!-- TODO: ポップオーバーのキャプチャが用意でき次第 docs/screenshot.png に置き換え。 -->

_メニューバーポップオーバーのスクリーンショット — 近日公開。_

## なぜ作ったか

AI コーディングツールは強力ですが、その上限は見失いがちです。

- 今の Codex セッションはあとどれくらい残っている?
- Claude Code のウィンドウはいつリセットされる?
- Gemini CLI はインストール済みでサインイン済みか?
- 今日はトークンをどれだけ使った?
- どのプロバイダーが一番先に枯渇しそうか?

PromptMeter はそうした答えをメニューバーとコンパクトなポップオーバーに表示し、コンテキストスイッチなしで作業を続けられるようにします。

## 機能

- 最も残りが少ないプロバイダーセッションを示す **メニューバーステータス**。
- Codex、Claude Code、Gemini CLI 用の **プロバイダーカード**。
- ローカルの Codex と Claude Code の JSONL ログから算出する **今日の使用量**。
- モデル別ローカル料金見積もりを使った **推定トークンコスト**。
- 時計形式またはカウントダウンで表示される **クオータリセット**。
- プロバイダーウィンドウが閾値に近づいたときの **低クオータ通知**。
- インストール/ログインコマンドを設定画面に表示する **CLI 未検出時の案内**。
- UI 上でアカウントメールアドレスを隠す **プライバシートグル**。
- 静かなメニューバー運用のための **ログイン時に起動**。
- 新しく追記された分だけを読み直す **インクリメンタルログスキャン**。

## プロバイダー対応

| プロバイダー | ステータス | PromptMeter が読み取るデータ |
| --- | --- | --- |
| Codex | 対応 | ローカル CLI / app-server のクオータ、プラン、アカウント、セッション制限、ローカルトークン使用ログ |
| Claude Code | 対応 | OAuth 使用量、サブスクリプション、リセットウィンドウ、ローカルトークン使用ログ |
| Gemini CLI | 対応 | ローカル CLI の `/stats model` クオータ出力 |

PromptMeter は OpenAI、Anthropic、Google と一切の提携関係はありません。ローカルにインストールされたツールとセッションログから取得できるデータのみを読み取ります。

## プライバシー

PromptMeter はローカルファーストで設計されています。

- プロンプトテキストはトークン推定のためにローカルで処理されます。
- ローカルトークン使用量はあなたのマシン上のファイルから計算されます。
- 使用量スキャンキャッシュには集計値、ファイルシグネチャ、オフセット、パーサ状態のみが保存されます。
- アカウントメールアドレスは設定 UI から非表示にできます。

Claude Code の OAuth 認証情報は macOS Keychain から読み取り、トークンリフレッシュが必要な場合は PromptMeter 自身の Keychain アイテムにキャッシュします。

## macOS 権限

PromptMeter は macOS 上で静かに動作します — Screen Recording、Accessibility、Full Disk Access のいずれも要求しません。

- **Keychain (macOS がプロンプト表示)** — 初回リフレッシュ時に PromptMeter は Claude Code CLI が保存した Claude OAuth 認証情報 (`Claude Code-credentials` 項目) を読み取り、バックグラウンドリフレッシュで再プロンプトが出ないように更新可能なコピーを自身の Keychain 項目 (`com.seo.promptMeter.oauth-cache`) にキャッシュします。初回プロンプトも完全になくすには:
  1. **Keychain Access.app** → login keychain を開きます。
  2. プロンプトされた項目 (通常は `Claude Code-credentials`) を見つけて開きます。
  3. **Access Control** で `PromptMeter.app` を "Always allow access by these applications" に追加します。
  4. PromptMeter を再起動します。
- **通知 (任意)** — 低クオータ通知を有効にしているときのみ要求します。拒否しても他の機能はそのまま動作します。
- **ログイン項目 (オプトイン)** — 設定 → General → "Start at login" は `SMAppService` を使用し、PromptMeter をログイン項目に追加する前に macOS が一度だけ確認します。

パスワードは保存しません。プロバイダーの CLI はそれぞれが認証を管理し続けます。

## プロジェクト構成

```text
PromptMeter/
  App/        アプリエントリ、アプリデリゲート、ポップオーバーホスト
  Core/       メインアプリモデル、設定、プロンプトメトリクス、通知
  Menu/       メニューバーポップオーバーのビューとメニューデータモデル
  Providers/  Codex、Claude Code、Gemini CLI のクライアントと使用量マッピング
  Settings/   設定ウィンドウ、タブ、再利用可能な設定コンポーネント
  Usage/      ローカルトークン使用量スキャナ、料金、ファイルキャッシュ、スナップショット
```

Xcode プロジェクトはファイルシステム同期されたルートグループを使っているため、ディスク上のツリーがそのままソースレイアウトです。

## ビルド

必要なもの:

- macOS
- Xcode
- SwiftUI / AppKit ツールチェーン
- 任意のプロバイダー CLI:
  - `codex`
  - `claude`
  - `gemini`

クローンして開く:

```bash
git clone git@github.com:minhee0000/PromptMeter.git
cd PromptMeter
open PromptMeter.xcodeproj
```

その後 Xcode から `PromptMeter` スキームをビルドして実行してください。

現在のプロジェクトは macOS のメニューバーアプリ (`LSUIElement`) として構成されており、リポジトリにチェックインされた Xcode プロジェクトが使用する macOS SDK を対象にしています。

## 使い方

1. 利用するプロバイダー CLI をインストールしてサインインします。
2. PromptMeter を起動します。
3. メニューバーのポップオーバーを開いてクオータ、リセットウィンドウ、今日の使用量を確認します。
4. 設定からリフレッシュ間隔、表示モード、プライバシー、ログイン時起動を構成します。

CLI が見つからない場合、PromptMeter は設定画面ではそのプロバイダーを表示し続けますが、メインのポップオーバーにはウィジェットを表示しません。

## 注意点

- 使用量とコストの数値はローカルログとモデル別料金テーブルに基づく見積もりです。
- プロバイダーの API や CLI 出力は変更される可能性があるため、PromptMeter は応答が取得できなかったりレート制限を受けたりした場合に防御的に振る舞います。
- Claude の HTTP 429 レスポンスに対しては、直近の成功スナップショットを保持し、バックオフしてから再試行します。

## ロードマップ

- 週次の使用量サマリ。
- 1 日ごとの使用傾向を示すチャートビュー (オプション)。
- 追加プロバイダー統合。
- 署名済みリリースビルド。
- サポート用診断情報のインポート / エクスポート。

## ライセンス

MIT © minhee0000. 詳細は [LICENSE](LICENSE) を参照してください。
