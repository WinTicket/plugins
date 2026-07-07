// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import android.app.Activity;
import android.app.ActivityOptions;
import android.app.PictureInPictureParams;
import android.content.Intent;
import android.os.Build;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import io.flutter.Log;
import java.lang.ref.WeakReference;

/**
 * Coordinates the dedicated {@link PipActivity} with the {@link VideoPlayer} whose video it shows.
 *
 * <p>Members are static because {@link PipActivity} is instantiated by the Android framework and
 * needs a process-wide handle to reach the active player. Only one dedicated PiP session can exist
 * at a time. All methods must be called on the main thread.
 */
final class PipActivityController {
  /** Notified when the dedicated PiP session ends, regardless of how it ended. */
  interface OnPipEndedListener {
    void onPipEnded(@Nullable VideoPlayer player);
  }

  private static final String TAG = "VideoPlayerPip";

  @Nullable private static VideoPlayer player;
  @Nullable private static WeakReference<PipActivity> activityRef;
  private static boolean inPipMode = false;
  @Nullable private static OnPipEndedListener onPipEndedListener;

  private PipActivityController() {}

  static void setOnPipEndedListener(@Nullable OnPipEndedListener listener) {
    onPipEndedListener = listener;
  }

  /** Launches the dedicated PiP activity showing the given player's video. */
  static void launch(@NonNull Activity hostActivity, @NonNull VideoPlayer targetPlayer) {
    if (player != null && player != targetPlayer) {
      endPip(false, "replaced by another player");
    }
    player = targetPlayer;
    Intent intent = new Intent(hostActivity, PipActivity.class);
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      PictureInPictureParams params =
          new PictureInPictureParams.Builder()
              .setAspectRatio(targetPlayer.getVideoAspectRatio())
              .build();
      intent.putExtra(PipActivity.EXTRA_LAUNCHED_INTO_PIP, true);
      Log.d(TAG, "Launching PipActivity via makeLaunchIntoPip (API 33+)");
      hostActivity.startActivity(intent, ActivityOptions.makeLaunchIntoPip(params).toBundle());
    } else {
      Log.d(TAG, "Launching PipActivity; entering PiP after creation (API < 33)");
      hostActivity.startActivity(intent);
    }
  }

  @Nullable
  static VideoPlayer getPlayer() {
    return player;
  }

  static boolean isInPipMode() {
    return inPipMode;
  }

  static void onActivityCreated(@NonNull PipActivity activity) {
    activityRef = new WeakReference<>(activity);
  }

  static void onPipEntered() {
    if (player == null) {
      return;
    }
    inPipMode = true;
    player.notifyPipStarted();
  }

  /**
   * Called when the PiP surface is torn down. Restores the Flutter texture as the video output if
   * the session has not been ended through {@link #endPip} yet.
   */
  static void onPipSurfaceDestroyed() {
    if (player != null) {
      player.restoreFlutterSurface();
    }
  }

  /**
   * Ends the dedicated PiP session: restores video output to the Flutter texture, optionally
   * pauses playback, notifies Dart, and finishes the PiP activity. Safe to call multiple times.
   */
  static void endPip(boolean pauseVideo, @NonNull String reason) {
    VideoPlayer endedPlayer = player;
    if (endedPlayer == null && activityRef == null) {
      return;
    }
    Log.d(TAG, "Ending dedicated PiP: " + reason);
    boolean wasInPipMode = inPipMode;
    inPipMode = false;
    player = null;
    if (endedPlayer != null) {
      endedPlayer.restoreFlutterSurface();
      if (pauseVideo) {
        endedPlayer.pause();
      }
      if (wasInPipMode) {
        endedPlayer.notifyPipStopped();
      }
    }
    finishActivityAndNotify(endedPlayer);
  }

  /**
   * Called at the start of {@link VideoPlayer#dispose()}. Tears the session down without touching
   * the player, which is about to release its ExoPlayer.
   */
  static void onPlayerDisposed(@NonNull VideoPlayer disposedPlayer) {
    if (player != disposedPlayer) {
      return;
    }
    Log.d(TAG, "Player disposed while its dedicated PiP session was active");
    inPipMode = false;
    player = null;
    finishActivityAndNotify(disposedPlayer);
  }

  /** Called from {@link PipActivity#onDestroy()} as a safety net for unexpected teardown. */
  static void onActivityDestroyed(@NonNull PipActivity activity) {
    if (activityRef != null && activityRef.get() == activity) {
      endPip(false, "activity destroyed");
    }
  }

  private static void finishActivityAndNotify(@Nullable VideoPlayer endedPlayer) {
    finishActivity();
    if (onPipEndedListener != null) {
      onPipEndedListener.onPipEnded(endedPlayer);
    }
  }

  private static void finishActivity() {
    PipActivity activity = activityRef != null ? activityRef.get() : null;
    activityRef = null;
    if (activity != null && !activity.isFinishing()) {
      activity.finish();
    }
  }
}
