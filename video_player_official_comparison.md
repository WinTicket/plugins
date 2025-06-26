# video_player 本家2.5.1との差異比較

## 調査結果サマリー

この分析により、**当プロジェクトのvideo_playerには過去に独自カスタム修正が実装されていたが、現在のmainブランチではそれらの修正が含まれていない**ことが判明しました。

## 実装されていたカスタム修正（過去のコミット）

### 1. Native isPlaying機能 (コミット: fcefd82dd - 2023年2月)

**コミッター情報**:
- **Author**: Takuma Osada <ostk0069@gmail.com>
- **Committer**: GitHub <noreply@github.com>  
- **Date**: Mon Feb 20 17:51:07 2023 +0900
- **PR**: #16 (feat: get native isPlaying)
- **PR URL**: このリポジトリ内のPR #16

**実装内容**:
```dart
/// Get latest isPlaying status from ExoPlayer/AVPlayer
Future<bool> get isPlaying async {
  if (_isDisposed) {
    return false;
  }
  return await _videoPlayerPlatform.getIsPlaying(_textureId);
}
```

**変更されたファイル**:
- `packages/video_player/video_player/lib/video_player.dart` - isPlaying getter追加
- `packages/video_player/video_player_android/android/src/main/java/io/flutter/plugins/videoplayer/VideoPlayer.java`
- `packages/video_player/video_player_android/android/src/main/java/io/flutter/plugins/videoplayer/VideoPlayerPlugin.java`
- `packages/video_player/video_player_avfoundation/ios/Classes/FLTVideoPlayerPlugin.m`
- 各プラットフォームのメッセージング・インターフェースファイル (21ファイル、533行の変更)

### 2. iOS時間範囲修正 (コミット: f6d14794c、257856d9c - 2022年12月)

**コミッター情報**:

**iOS loaded time range修正 (f6d14794c)**:
- **Author**: Takuma Osada <ostk0069@gmail.com>
- **Committer**: b4tchkn <baaaakkrad@gmail.com>
- **Date**: Tue Dec 27 13:28:54 2022 +0900 (Author Date)
- **Commit Date**: Fri Jan 27 16:37:20 2023 +0900
- **PR**: #12 (fix: get ios loaded time range)
- **PR URL**: このリポジトリ内のPR #12

**iOS seekable time range修正 (257856d9c)**:
- **Author**: Takuma Osada <ostk0069@gmail.com>
- **Committer**: b4tchkn <baaaakkrad@gmail.com>
- **Date**: Tue Dec 27 11:50:54 2022 +0900 (Author Date)
- **Commit Date**: Fri Jan 27 16:37:20 2023 +0900
- **PR**: #11 (fix: ios seekable time range)
- **PR URL**: このリポジトリ内のPR #11
- **Co-authored-by**: Akihisa Sengoku <akihisasengoku@users.noreply.github.com>

**実装内容**:
- iOS AVPlayerでのseekable time rangeの正確な計算
- loaded time rangeの適切な取得
- バッファリング状態の改善

**変更されたファイル**:
- `packages/video_player/video_player_avfoundation/ios/Classes/FLTVideoPlayerPlugin.m`
- 関連するメッセージング・インターフェースファイル (7ファイル、681行の変更)

## 現在の状況分析

### mainブランチ (現在)
- **公式video_player 2.5.1と同等**: カスタム修正は含まれていない
- **標準API**: `controller.value.isPlaying`のみ利用可能
- **互換性**: 本家Flutter video_playerと完全互換

### 別ブランチでの管理
以下のブランチでカスタム修正が管理されている可能性があります：
- `remotes/origin/feat-video-player-timeshift` - タイムシフト機能
- `remotes/origin/fix-ios-seekable-time-range` - iOS時間範囲修正
- `remotes/origin/get-ios-loaded-time-range` - iOS loaded time range修正

## 詳細な本家との差異

### 本家Flutter video_player 2.5.1との比較

| 項目 | 本家2.5.1 | 現在のmainブランチ | 過去のカスタム版 |
|------|-----------|-------------------|------------------|
| Native isPlaying API | ❌ なし | ❌ なし | ✅ あり |
| iOS時間範囲修正 | ❌ 標準実装 | ❌ 標準実装 | ✅ 修正済み |
| API互換性 | ✅ 標準 | ✅ 標準 | ⚠️ 拡張あり |
| プラットフォーム対応 | ✅ 標準 | ✅ 標準 | ✅ 拡張済み |

### 現在のmainブランチ vs 本家2.5.1

**差異: 実質的になし**

現在のmainブランチの実装は本家Flutter video_player 2.5.1とほぼ同一です：

1. **pubspec.yaml**: 依存関係とバージョンが一致
2. **lib/video_player.dart**: APIと実装が同一
3. **プラットフォーム実装**: Android/iOS/Web全て標準実装
4. **テストコード**: 標準的なテスト構成

## 技術的詳細

### 過去に実装されていたNative isPlaying機能

**問題解決**:
- Flutter側の`value.isPlaying`とネイティブプレイヤーの実際の再生状態の差異を解消
- リアルタイムでの正確な再生状態取得

**実装方式**:
- Android: ExoPlayerから直接状態取得
- iOS: AVPlayerから直接状態取得
- プラットフォーム共通: Pigeonによるメッセージング

### iOS時間範囲修正の内容

**修正対象**:
```objective-c
// 修正前（推定）
CMTimeRange seekableRange = self.player.currentItem.seekableTimeRanges.firstObject.CMTimeRangeValue;

// 修正後
CMTimeRange seekableRange = [self getSeekableTimeRange]; // カスタム実装
CMTimeRange loadedRange = [self getLoadedTimeRange]; // カスタム実装
```

**改善内容**:
- seekable rangeの開始時間を適切に考慮
- loaded rangeの正確な計算
- ライブストリーム対応の向上

## 推奨事項

### 1. カスタム修正の再適用を検討する場合

現在のmainブランチにカスタム修正を再適用したい場合：

```bash
# 過去のカスタム修正コミットを確認
git show fcefd82dd  # Native isPlaying
git show f6d14794c  # iOS loaded time range  
git show 257856d9c  # iOS seekable time range

# ブランチから修正を適用
git cherry-pick fcefd82dd
git cherry-pick f6d14794c  
git cherry-pick 257856d9c
```

### 2. 本家との互換性を維持する場合

現在のmainブランチのまま使用することで：
- 本家video_playerとの完全互換性を維持
- 将来のアップデートが容易
- 公式サポート対象として維持

### 3. 段階的適用

カスタム修正を段階的に適用：
1. iOS時間範囲修正のみ適用（ライブストリーム対応重視）
2. Native isPlaying機能の検討（リアルタイム状態管理重視）

## 結論

**現在のmainブランチは本家Flutter video_player 2.5.1と実質的に同一**であり、過去に実装されていたカスタム修正は含まれていません。これらの修正は別のコミット履歴やブランチで管理されており、必要に応じて再適用することが可能です。

カスタム修正の適用判断は、プロジェクトの要件（本家との互換性 vs 独自機能の必要性）に基づいて決定することをお勧めします。

---

*調査日: 2025年6月26日*  
*対象リポジトリ: /Users/s12844/projects/winticket-plugins*