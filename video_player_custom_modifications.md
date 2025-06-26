# video_player 2.5.1 独自カスタム修正まとめ

## 概要

このプロジェクトでは、Flutter公式のvideo_player 2.5.1に対して独自のカスタム修正を行っています。主に再生状態の管理とiOSでの時間範囲処理の改善が含まれています。

## バージョン情報

| パッケージ | バージョン | 備考 |
|-----------|-----------|------|
| video_player | 2.5.1 | メインパッケージ（変更なし） |
| video_player_android | 2.3.10 | 標準2.5.1の依存関係（^2.3.5）より新しい |
| video_player_avfoundation | 2.3.8 | 標準2.5.1の依存関係（^2.2.17）より新しい |
| video_player_web | 2.0.13 | 標準2.5.1の依存関係（^2.0.0）と互換 |
| video_player_platform_interface | 6.0.1 | 標準2.5.1の依存関係（>=5.1.1 <7.0.0）と互換 |

## 主要な独自修正

### 1. Native isPlaying ステータス機能（2023年2月追加）

**目的**: より正確なリアルタイム再生状態の取得

**修正内容**:
- `VideoPlayerController`に`Future<bool> get isPlaying`メソッドを追加
- Android ExoPlayerとiOS AVPlayerから直接再生状態を取得
- Flutter側の状態管理に依存せず、ネイティブレベルでの正確な再生状態を提供

**影響を受けるファイル**:
- `packages/video_player/video_player/lib/video_player.dart`
- `packages/video_player/video_player_android/android/src/main/java/io/flutter/plugins/videoplayer/VideoPlayer.java`
- `packages/video_player/video_player_android/android/src/main/java/io/flutter/plugins/videoplayer/VideoPlayerPlugin.java`
- `packages/video_player/video_player_avfoundation/ios/Classes/FLTVideoPlayerPlugin.m`
- 各プラットフォームのメッセージング・インターフェースファイル

### 2. iOS時間範囲の修正（2022年12月追加）

**目的**: iOSでの時間範囲処理とバッファリング状態の改善

**修正内容**:
- seekable time rangeの計算ロジック修正
- loaded time rangeの正確な取得
- AVPlayerのバッファリング状態報告の改善
- ライブストリームと時間ベースシークの処理向上

**影響を受けるファイル**:
- `packages/video_player/video_player_avfoundation/ios/Classes/FLTVideoPlayerPlugin.m`
- 関連するメッセージング・インターフェースファイル

### 3. その他の機能

**CustomSSLSocketFactory**:
- 古いAndroidバージョンでのTLS 1.1/1.2サポート
- `packages/video_player/video_player_android/android/src/main/java/io/flutter/plugins/videoplayer/CustomSSLSocketFactory.java`

## 技術的詳細

### Native isPlaying API

```dart
// 使用例
final bool isCurrentlyPlaying = await videoPlayerController.isPlaying;
```

この機能により、以下の利点があります：

- **正確性**: ネイティブプレイヤーの実際の状態を反映
- **リアルタイム**: Flutter側の状態更新を待たずに最新の再生状態を取得
- **信頼性**: ネットワーク遅延やバッファリングの影響を受けない正確な状態管理

### iOS時間範囲改善

- **seekable range**: 再生可能な時間範囲の正確な計算
- **loaded range**: バッファリング済み時間範囲の適切な取得
- **ライブストリーム対応**: 動的に変化する時間範囲への対応

## 導入の経緯

これらの修正は、以下の課題を解決するために導入されました：

1. **再生状態の不正確性**: 標準のvideo_playerでは、Flutter側の状態とネイティブプレイヤーの実際の状態に差異が生じる場合があった
2. **iOS時間範囲の問題**: iOSでのseekable/loaded time rangeの取得が不正確で、シークやバッファリング表示に影響があった
3. **ライブストリーム対応**: 動的に変化する時間範囲への対応が不十分だった

## 保守・更新について

- メインパッケージのバージョンは2.5.1を維持
- プラットフォーム実装は個別に更新されている
- 独自修正は本家のアップデートと競合しないよう注意深く管理されている

## 注意事項

- この独自修正版は、標準のvideo_player 2.5.1とは異なる動作をする場合があります
- 本家video_playerの新しいバージョンにアップデートする際は、これらの独自修正の移植が必要です
- 独自修正により、Flutter公式サポートの対象外となる可能性があります

---

*最終更新: 2025年6月*