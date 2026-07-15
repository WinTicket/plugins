// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import android.app.Activity;
import android.app.ActivityOptions;
import android.app.PictureInPictureParams;
import android.content.Intent;
import android.graphics.Rect;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
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

  // How long after the PiP window closes to wait before deciding whether the close was an
  // "expand back to the app" (host regains focus -> keep playing) or a plain dismissal.
  private static final long WINDOW_CLOSE_PAUSE_DECISION_MS = 500;

  @Nullable private static VideoPlayer player;
  @Nullable private static WeakReference<PipActivity> activityRef;
  @Nullable private static WeakReference<Activity> hostActivityRef;
  private static boolean inPipMode = false;
  @Nullable private static OnPipEndedListener onPipEndedListener;
  // Screen rect (physical pixels) of the video widget, used as the PiP enter-animation origin.
  @Nullable private static Rect sourceRectHint;

  private PipActivityController() {}

  static void setOnPipEndedListener(@Nullable OnPipEndedListener listener) {
    onPipEndedListener = listener;
  }

  /**
   * Launches the dedicated PiP activity showing the given player's video. When non-null,
   * {@code sourceRectHintPx} makes the system animate the PiP window out of that on-screen rect
   * instead of the full screen.
   */
  @RequiresApi(Build.VERSION_CODES.O)
  static void launch(
      @NonNull Activity hostActivity,
      @NonNull VideoPlayer targetPlayer,
      @Nullable Rect sourceRectHintPx) {
    if (player != null && player != targetPlayer) {
      endPip(false, "replaced by another player");
    }
    player = targetPlayer;
    hostActivityRef = new WeakReference<>(hostActivity);
    sourceRectHint = sourceRectHintPx;
    Intent intent = new Intent(hostActivity, PipActivity.class);
    // PipActivity 起動時にホストの onUserLeaveHint を誤発火させないためのフラグ。
    // ここで発火してしまうと、auto PiP リスナが「新規の離脱」と判定して二重起動しうる。
    intent.addFlags(Intent.FLAG_ACTIVITY_NO_USER_ACTION);
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      intent.putExtra(PipActivity.EXTRA_LAUNCHED_INTO_PIP, true);
      Log.d(
          TAG,
          "Launching PipActivity via makeLaunchIntoPip (API 33+), sourceRectHint="
              + sourceRectHintPx);
      hostActivity.startActivity(
          intent, ActivityOptions.makeLaunchIntoPip(buildPipParams(targetPlayer)).toBundle());
    } else {
      Log.d(TAG, "Launching PipActivity; entering PiP after creation (API < 33)");
      hostActivity.startActivity(intent);
    }
  }

  /**
   * Builds the PiP params for the given player: the video aspect ratio plus, when set, the source
   * rect the enter animation should start from.
   */
  @RequiresApi(Build.VERSION_CODES.O)
  static PictureInPictureParams buildPipParams(@NonNull VideoPlayer targetPlayer) {
    PictureInPictureParams.Builder builder =
        new PictureInPictureParams.Builder().setAspectRatio(targetPlayer.getVideoAspectRatio());
    if (sourceRectHint != null) {
      builder.setSourceRectHint(sourceRectHint);
    }
    return builder.build();
  }

  @Nullable
  static VideoPlayer getPlayer() {
    return player;
  }

  /** Screen rect of the video widget, used to lay out and animate PiP transitions. */
  @Nullable
  static Rect getSourceRectHint() {
    return sourceRectHint;
  }

  static boolean isInPipMode() {
    return inPipMode;
  }

  static void onActivityCreated(@NonNull PipActivity activity) {
    activityRef = new WeakReference<>(activity);
  }

  static void onPipEntered() {
    // Idempotent: with makeLaunchIntoPip this is called from onCreate, and
    // onPictureInPictureModeChanged(true) may or may not fire afterwards.
    if (player == null || inPipMode) {
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
   * Ends the session after the system closed the PiP window. On API 33+ this happens both when
   * the user dismisses the window (X) and when they expand it back to the app — the dedicated
   * activity is stopped in both cases, so they are indistinguishable here. Decide whether to
   * pause after a grace period: if the host activity regained focus the close was an
   * expand-back-to-app, so playback continues; otherwise it was a plain dismissal, so pause.
   */
  static void endPipFromWindowClose() {
    VideoPlayer endedPlayer = player;
    Activity hostActivity = hostActivityRef != null ? hostActivityRef.get() : null;
    endPip(false, "window closed");
    if (endedPlayer == null) {
      return;
    }
    new Handler(Looper.getMainLooper())
        .postDelayed(
            () -> {
              boolean hostFocused = hostActivity != null && hostActivity.hasWindowFocus();
              Log.d(TAG, "PiP window closed; hostFocused=" + hostFocused);
              if (!hostFocused && !endedPlayer.isDisposed()) {
                endedPlayer.pause();
              }
            },
            WINDOW_CLOSE_PAUSE_DECISION_MS);
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
    sourceRectHint = null;
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
    sourceRectHint = null;
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
