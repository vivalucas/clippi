# Clippi

[简体中文](README.md) | [English](README.en.md) | [日本語](README.ja.md)

Clippi は、クロスプラットフォームのネイティブデスクトップ動画処理ツールです。処理エンジンに ffmpeg / ffprobe を使用し、macOS では SwiftUI、Windows では WinUI 3 の GUI を提供することで、一般的な動画処理をコマンドラインなしで行えるようにします。

## 機能

- 単一メディアファイルのドラッグ＆ドロップまたは選択
- 解像度、長さ、コーデック、フレームレート、ビットレートの自動取得
- 動画トリミング：高速モード（ストリームコピー）と精密モード（再エンコード）
- 形式変換：MP4 / MKV / MOV / WebM
- 解像度変更：4K / 1080p / 720p / 480p
- 音声処理：MP3 / AAC / WAV の抽出、または音声トラックの削除
- GPU エンコーダー検出：macOS VideoToolbox、Windows NVENC / QSV
- 進捗、速度、完了、失敗、キャンセル状態のコールバック
- 出力パスの重複回避、処理前の上書き確認と書き込み権限チェック
- UI ローカライズ：简体中文、English、日本語

> バッチキューや高度な ffmpeg パラメータ制御は今後の計画です。現在のデスクトップ UI は単一ファイル処理を中心にしています。

## ダウンロードと配布

正式版は GitHub Releases で配布します：

- macOS：`Clippi-macos.dmg`
- Windows：`Clippi-windows.zip`

リリースビルドには ffmpeg / ffprobe が同梱されるため、ユーザーが ffmpeg を別途インストールする必要はありません。開発環境では `scripts/download_ffmpeg.*` でローカルバイナリを取得できます。Rust コアライブラリは、アプリ同梱パス、`CLIPPI_FFMPEG_DIR`、システム `PATH` の順に検索します。

## 技術スタック

| レイヤー | 技術 |
|------|------|
| macOS UI | Swift + SwiftUI |
| Windows UI | C# + WinUI 3 |
| コアライブラリ | Rust |
| 処理エンジン | ffmpeg / ffprobe |
| ローカライズ | macOS `.lproj` / Windows `.resw` |

## プロジェクト構成

```text
clippi/
├── core/                          # Rust コアライブラリ
│   ├── src/
│   │   ├── lib.rs                 # モジュール定義
│   │   ├── ffi.rs                 # C FFI インターフェイス
│   │   ├── probe.rs               # ffprobe によるファイル情報取得
│   │   ├── gpu.rs                 # GPU 検出
│   │   ├── task.rs                # ffmpeg タスク実行
│   │   ├── queue.rs               # シリアルキュー基盤
│   │   ├── binaries.rs            # ffmpeg / ffprobe パス解決
│   │   ├── types.rs               # データ型
│   │   └── error.rs               # エラー型
│   └── Cargo.toml
├── macos/                         # macOS SwiftUI プロジェクト
│   ├── Clippi.xcodeproj/
│   └── Clippi/
│       ├── ClippiApp.swift        # App エントリ
│       ├── ClippiCore.h           # Swift ブリッジヘッダー
│       ├── FFI/ClippiFFI.swift    # Swift FFI ラッパー
│       ├── Localization.swift     # macOS ローカライズ補助
│       ├── *.lproj/               # zh-Hans / en / ja ローカライズリソース
│       ├── ViewModels/
│       └── Views/
├── windows/                       # Windows WinUI 3 プロジェクト
│   └── Clippi/
│       ├── App.xaml/cs
│       ├── MainWindow.xaml/cs
│       ├── Localization.cs        # Windows ローカライズ補助
│       ├── Strings/               # zh-CN / en-US / ja-JP .resw リソース
│       ├── ViewModels/
│       └── ClippiCore.cs          # C# P/Invoke ラッパー
├── scripts/
│   ├── download_ffmpeg.sh
│   ├── download_ffmpeg.ps1
│   ├── build-core.sh
│   └── build-core.ps1
├── .github/workflows/
│   ├── build-macos.yml
│   └── build-windows.yml
├── LICENSE
├── README.md                      # 简体中文
├── README.en.md                   # English
└── README.ja.md                   # 日本語
```

## ローカル開発

### 必要環境

- Rust stable
- macOS：Xcode 15+
- Windows：Visual Studio 2022 + .NET 8 SDK
- ffmpeg / ffprobe：スクリプトでダウンロード、または `CLIPPI_FFMPEG_DIR` に配置

### ビルド手順

```bash
# 1. ffmpeg / ffprobe をダウンロード
./scripts/download_ffmpeg.sh      # macOS
.\scripts\download_ffmpeg.ps1     # Windows

# 2. Rust コアライブラリをビルド
./scripts/build-core.sh           # macOS
.\scripts\build-core.ps1          # Windows

# 3. ネイティブプロジェクトを開く
# macOS: macos/Clippi.xcodeproj
# Windows: windows/Clippi/Clippi.csproj
```

## CI/CD

GitHub Actions は次の場合に自動ビルドします：

- `main` への push：macOS / Windows artifact をビルドしてメインブランチを検証
- `v*` tag の push：Release アセットをビルドしてアップロード

リリース例：

```bash
git tag v1.0.0
git push origin v1.0.0
```

## 現在の制限

- デスクトップ UI は現在、単一ファイル処理のみ対応
- Windows 版はインストーラーではなく zip 配布
- macOS 版は未署名のため、初回起動時にシステムの許可操作が必要な場合があります
- 出力ファイルサイズ予測、空き容量警告、高度な ffmpeg パラメータ編集、コマンドプレビュー、ログ展開、バッチタスク管理は今後対応予定

## ライセンス

GPL-2.0
