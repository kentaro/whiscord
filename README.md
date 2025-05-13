# Whiscord

Whiscordは、スマートフォンで話した内容を音声認識し、即座にDiscordの特定チャンネルに投稿するモバイルアプリです。

## 特徴

- **簡単録音**: シンプルなUIで素早く音声録音ができる
- **高精度な音声認識**: OpenAI Whisper APIを使用した高精度な音声テキスト変換
- **Discord連携**: 認識したテキストを自動的にDiscordに投稿
- **日本語対応**: 日本語の音声認識に対応

## セットアップ方法

1. アプリをインストールする
2. 設定画面でOpenAI APIキーを設定する
3. DiscordでWebhook URLを取得して設定する
4. マイク権限を許可する

## 使い方

1. アプリを起動する
2. マイクボタンをタップして録音を開始
3. 停止ボタンをタップして録音を終了
4. 音声が自動的に認識され、Discordに投稿される

## 技術スタック

- Flutter: クロスプラットフォームUI
- flutter_sound: 音声録音
- OpenAI Whisper API: 音声認識
- Discord Webhook: テキスト投稿

## 注意点

- OpenAI APIキーは自分で取得する必要があります
- 音声認識には一定の精度限界があります
- インターネット接続が必要です

---

## 開発者向け情報

### 必要な環境

- Flutter SDK
- Dart SDK
- Android Studio または VS Code
- iOS/Androidエミュレータまたは実機

### ビルド方法

```
flutter pub get
flutter build apk  # Androidの場合
flutter build ios  # iOSの場合
```
