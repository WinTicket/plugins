// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import android.app.Activity;
import android.app.PictureInPictureParams;
import android.content.Context;
import android.content.res.Configuration;
import android.graphics.Color;
import android.os.Build;
import android.os.Bundle;
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

  private boolean activityStarted = false;
  private boolean enterPipRequested = false;

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
    setContentView(createContentView(player));

    if (getIntent().getBooleanExtra(EXTRA_LAUNCHED_INTO_PIP, false)) {
      Log.d(TAG, "Launched directly into PiP (makeLaunchIntoPip)");
      enterPipRequested = true;
    } else {
      enterPipIfNeeded("onCreate");
    }
  }

  private View createContentView(@NonNull VideoPlayer player) {
    FrameLayout root = new FrameLayout(this);
    root.setBackgroundColor(Color.BLACK);

    Rational aspectRatio = player.getVideoAspectRatio();
    AspectRatioFrameLayout videoContainer =
        new AspectRatioFrameLayout(this, aspectRatio.floatValue());

    SurfaceView surfaceView = new SurfaceView(this);
    surfaceView.getHolder().addCallback(surfaceCallback);
    videoContainer.addView(
        surfaceView,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT));

    root.addView(
        videoContainer,
        new FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER));
    return root;
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
    PictureInPictureParams params =
        new PictureInPictureParams.Builder().setAspectRatio(player.getVideoAspectRatio()).build();
    boolean entered = enterPictureInPictureMode(params);
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
      PipActivityController.onPipEntered();
      return;
    }
    // When the PiP window is dismissed the activity is stopped before this callback fires,
    // whereas expanding back to full screen keeps it started.
    if (activityStarted) {
      PipActivityController.endPip(false, "expanded to full screen");
    } else {
      PipActivityController.endPip(true, "dismissed");
    }
  }

  @Override
  protected void onDestroy() {
    super.onDestroy();
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
