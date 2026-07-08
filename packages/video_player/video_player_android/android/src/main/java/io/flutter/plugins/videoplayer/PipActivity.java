// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import android.app.Activity;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.Rect;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Rational;
import android.view.Gravity;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import io.flutter.Log;

/**
 * A minimal activity that hosts only the video surface while in Picture-in-Picture mode. Running
 * PiP in a dedicated activity (instead of the Flutter host activity) keeps the main app usable
 * behind the PiP window and guarantees the PiP window shows nothing but the video.
 *
 * <p>On API 33+ this activity is launched directly into PiP via {@code
 * ActivityOptions.makeLaunchIntoPip}. On API 26-32 it briefly appears full screen (black) and
 * enters PiP right after creation.
 *
 * <p>The activity is stacked on the same task as the host activity, so finishing it after the PiP
 * window is expanded reveals the host activity underneath.
 */
@RequiresApi(Build.VERSION_CODES.O)
public final class PipActivity extends Activity {
  static final String EXTRA_LAUNCHED_INTO_PIP = "launched_into_pip";
  private static final String TAG = "VideoPlayerPip";

  // Keeps this activity alive after the expand transition starts, so the system animation
  // (which lands the video on the source rect) finishes before the host activity is revealed.
  private static final long EXPAND_TRANSITION_GRACE_MS = 400;

  private final Handler mainHandler = new Handler(Looper.getMainLooper());
  private boolean activityStarted = false;
  private boolean enterPipRequested = false;
  @Nullable private AspectRatioFrameLayout videoContainer;

  private final SurfaceHolder.Callback surfaceCallback =
      new SurfaceHolder.Callback() {
        @Override
        public void surfaceCreated(@NonNull SurfaceHolder holder) {
          VideoPlayer player = PipActivityController.getPlayer();
          if (player != null) {
            Log.d(TAG, "PiP surface created; switching video output to PipActivity");
            player.attachPipSurface(holder.getSurface());
          }
        }

        @Override
        public void surfaceChanged(@NonNull SurfaceHolder holder, int format, int w, int h) {}

        @Override
        public void surfaceDestroyed(@NonNull SurfaceHolder holder) {
          Log.d(TAG, "PiP surface destroyed");
          PipActivityController.onPipSurfaceDestroyed();
        }
      };

  @Override
  protected void onCreate(@Nullable Bundle savedInstanceState) {
    super.onCreate(savedInstanceState);
    VideoPlayer player = PipActivityController.getPlayer();
    if (player == null) {
      Log.w(TAG, "No active player for PipActivity; finishing");
      finish();
      return;
    }
    PipActivityController.onActivityCreated(this);
    boolean launchedIntoPip = getIntent().getBooleanExtra(EXTRA_LAUNCHED_INTO_PIP, false);
    setContentView(createContentView(player, launchedIntoPip));

    if (launchedIntoPip) {
      Log.d(TAG, "Launched directly into PiP (makeLaunchIntoPip)");
      enterPipRequested = true;
      // When the activity is created directly in PiP mode there is no mode
      // *change*, so onPictureInPictureModeChanged(true) may never fire.
      // Report PiP entry here instead (onPipEntered is idempotent).
      PipActivityController.onPipEntered();
    } else {
      enterPipIfNeeded("onCreate");
    }
  }

  private View createContentView(@NonNull VideoPlayer player, boolean launchedIntoPip) {
    FrameLayout root = new FrameLayout(this);
    root.setBackgroundColor(Color.BLACK);

    Rational aspectRatio = player.getVideoAspectRatio();
    videoContainer = new AspectRatioFrameLayout(this, aspectRatio.floatValue());

    SurfaceView surfaceView = new SurfaceView(this);
    surfaceView.getHolder().addCallback(surfaceCallback);
    videoContainer.addView(
        surfaceView,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

    root.addView(videoContainer, videoLayoutParams(launchedIntoPip));
    return root;
  }

  /**
   * Layout for the video container. While in PiP the video fills the window (whose aspect ratio
   * already matches the video). In full-screen phases it sits exactly on the source rect — the
   * on-screen position of the Flutter video widget — so both the enter animation (API 26-32) and
   * the expand-to-full-screen animation land the video on the widget, making the hand-off to the
   * host activity seamless. Without a source rect it falls back to letterboxed center.
   */
  private FrameLayout.LayoutParams videoLayoutParams(boolean fillWindow) {
    Rect sourceRect = PipActivityController.getSourceRectHint();
    if (!fillWindow && sourceRect != null) {
      FrameLayout.LayoutParams params =
          new FrameLayout.LayoutParams(sourceRect.width(), sourceRect.height());
      params.leftMargin = sourceRect.left;
      params.topMargin = sourceRect.top;
      return params;
    }
    return new FrameLayout.LayoutParams(
        ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.CENTER);
  }

  private void applyVideoLayout(boolean fillWindow) {
    if (videoContainer != null) {
      videoContainer.setLayoutParams(videoLayoutParams(fillWindow));
    }
  }

  // API 26-32 entry point. Entering from onCreate usually works; onWindowFocusChanged is the
  // fallback for devices that reject the request before the window is attached.
  private void enterPipIfNeeded(@NonNull String caller) {
    if (enterPipRequested || isInPictureInPictureMode()) {
      return;
    }
    VideoPlayer player = PipActivityController.getPlayer();
    if (player == null) {
      return;
    }
    boolean entered = enterPictureInPictureMode(PipActivityController.buildPipParams(player));
    Log.d(TAG, "enterPictureInPictureMode from " + caller + " -> " + entered);
    if (entered) {
      enterPipRequested = true;
    }
  }

  @Override
  public void onWindowFocusChanged(boolean hasFocus) {
    super.onWindowFocusChanged(hasFocus);
    if (hasFocus) {
      enterPipIfNeeded("onWindowFocusChanged");
    }
  }

  @Override
  protected void onStart() {
    super.onStart();
    activityStarted = true;
  }

  @Override
  protected void onStop() {
    super.onStop();
    activityStarted = false;
  }

  @Override
  public void onPictureInPictureModeChanged(
      boolean isInPictureInPictureMode, @NonNull Configuration newConfig) {
    super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig);
    Log.d(
        TAG,
        "onPictureInPictureModeChanged: "
            + isInPictureInPictureMode
            + " started="
            + activityStarted);
    if (isInPictureInPictureMode) {
      applyVideoLayout(true);
      PipActivityController.onPipEntered();
      return;
    }
    // When the PiP window is dismissed the activity is stopped before this callback fires,
    // whereas expanding back to full screen keeps it started.
    if (activityStarted) {
      // Show the video on the source rect so the system's expand animation lands it exactly on
      // the Flutter video widget, then hand off to the host activity underneath.
      applyVideoLayout(false);
      Log.d(TAG, "Expanded to full screen; finishing after transition grace period");
      mainHandler.postDelayed(
          () -> PipActivityController.endPip(false, "expanded to full screen"),
          EXPAND_TRANSITION_GRACE_MS);
    } else {
      PipActivityController.endPipFromWindowClose();
    }
  }

  @Override
  public void finish() {
    super.finish();
    // Suppress the close animation: the host activity underneath already shows the video at the
    // same position, so any transition would break the seamless hand-off.
    overridePendingTransition(0, 0);
  }

  @Override
  protected void onDestroy() {
    super.onDestroy();
    mainHandler.removeCallbacksAndMessages(null);
    PipActivityController.onActivityDestroyed(this);
  }

  /** Sizes its content to the video aspect ratio so the full-screen phase is letterboxed. */
  private static final class AspectRatioFrameLayout extends FrameLayout {
    private final float aspectRatio;

    AspectRatioFrameLayout(@NonNull Context context, float aspectRatio) {
      super(context);
      this.aspectRatio = aspectRatio > 0 ? aspectRatio : 16f / 9f;
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
      int width = MeasureSpec.getSize(widthMeasureSpec);
      int height = MeasureSpec.getSize(heightMeasureSpec);
      if (width == 0 || height == 0) {
        super.onMeasure(widthMeasureSpec, heightMeasureSpec);
        return;
      }
      if ((float) width / height > aspectRatio) {
        width = (int) (height * aspectRatio);
      } else {
        height = (int) (width / aspectRatio);
      }
      super.onMeasure(
          MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY),
          MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY));
    }
  }
}
