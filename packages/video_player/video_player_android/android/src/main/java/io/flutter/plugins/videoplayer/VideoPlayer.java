// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static com.google.android.exoplayer2.Player.REPEAT_MODE_ALL;
import static com.google.android.exoplayer2.Player.REPEAT_MODE_OFF;

import android.app.Activity;
import android.app.PictureInPictureParams;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Rect;
import android.graphics.RectF;
import android.net.Uri;
import android.os.Build;
import android.util.Rational;
import android.view.Surface;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.VisibleForTesting;
import com.google.android.exoplayer2.C;
import com.google.android.exoplayer2.DefaultLoadControl;
import com.google.android.exoplayer2.DefaultRenderersFactory;
import com.google.android.exoplayer2.ExoPlayer;
import com.google.android.exoplayer2.Format;
import com.google.android.exoplayer2.LoadControl;
import com.google.android.exoplayer2.MediaItem;
import com.google.android.exoplayer2.PlaybackException;
import com.google.android.exoplayer2.PlaybackParameters;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.Player.Listener;
import com.google.android.exoplayer2.analytics.DefaultAnalyticsCollector;
import com.google.android.exoplayer2.audio.AudioAttributes;
import com.google.android.exoplayer2.extractor.DefaultExtractorsFactory;
import com.google.android.exoplayer2.source.DefaultMediaSourceFactory;
import com.google.android.exoplayer2.source.MediaSource;
import com.google.android.exoplayer2.source.ProgressiveMediaSource;
import com.google.android.exoplayer2.source.dash.DashMediaSource;
import com.google.android.exoplayer2.source.dash.DefaultDashChunkSource;
import com.google.android.exoplayer2.source.hls.HlsMediaSource;
import com.google.android.exoplayer2.source.smoothstreaming.DefaultSsChunkSource;
import com.google.android.exoplayer2.source.smoothstreaming.SsMediaSource;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import com.google.android.exoplayer2.upstream.DataSource;
import com.google.android.exoplayer2.upstream.DefaultBandwidthMeter;
import com.google.android.exoplayer2.upstream.DefaultDataSource;
import com.google.android.exoplayer2.upstream.DefaultHttpDataSource;
import com.google.android.exoplayer2.util.Clock;
import com.google.android.exoplayer2.util.Util;
import io.flutter.plugin.common.EventChannel;
import io.flutter.view.TextureRegistry;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class VideoPlayer {
  private static final String FORMAT_SS = "ss";
  private static final String FORMAT_DASH = "dash";
  private static final String FORMAT_HLS = "hls";
  private static final String FORMAT_OTHER = "other";

  /** A handler invoked when PiP mode is requested, to notify the plugin of the player ID. */
  public interface PipRequestHandler {
    void onPipRequested();
  }

  private ExoPlayer exoPlayer;

  private Surface surface;

  private final TextureRegistry.SurfaceTextureEntry textureEntry;

  QueuingEventSink eventSink;

  private final EventChannel eventChannel;

  @VisibleForTesting boolean isInitialized = false;

  private final VideoPlayerOptions options;

  private final DefaultTrackSelector trackSelector;

  @Nullable VideoPlayerCallbacks videoPlayerCallbacks;
  @Nullable private Activity activity;
  @Nullable private PipRequestHandler pipRequestHandler;
  private boolean autoPipEnabled = false;
  private boolean disposed = false;

  VideoPlayer(
      Context context,
      EventChannel eventChannel,
      TextureRegistry.SurfaceTextureEntry textureEntry,
      String dataSource,
      String formatHint,
      @NonNull Map<String, String> httpHeaders,
      VideoPlayerOptions options) {
    this.eventChannel = eventChannel;
    this.textureEntry = textureEntry;
    this.options = options;

    this.trackSelector = new DefaultTrackSelector(context);

    ExoPlayer.Builder exoPlayerBuilder =
        new ExoPlayer.Builder(context).setTrackSelector(trackSelector);
    if (options.buffer != null) {
      DefaultLoadControl.Builder defaultLoadControlBuilder = new DefaultLoadControl.Builder();
      defaultLoadControlBuilder.setBufferDurationsMs(
              options.buffer.minBufferMs,
              options.buffer.maxBufferMs,
              options.buffer.bufferForPlaybackMs,
              options.buffer.bufferForPlaybackAfterRebufferMs
      );
      exoPlayerBuilder.setLoadControl(defaultLoadControlBuilder.build());
    }

    ExoPlayer exoPlayer = exoPlayerBuilder.build();


    Uri uri = Uri.parse(dataSource);
    DataSource.Factory dataSourceFactory;

    if (isHTTP(uri)) {
      DefaultHttpDataSource.Factory httpDataSourceFactory =
          new DefaultHttpDataSource.Factory()
              .setUserAgent("ExoPlayer")
              .setAllowCrossProtocolRedirects(true);

      if (httpHeaders != null && !httpHeaders.isEmpty()) {
        httpDataSourceFactory.setDefaultRequestProperties(httpHeaders);
      }
      dataSourceFactory = httpDataSourceFactory;
    } else {
      dataSourceFactory = new DefaultDataSource.Factory(context);
    }

    MediaSource mediaSource = buildMediaSource(uri, dataSourceFactory, formatHint, context);

    exoPlayer.setMediaSource(mediaSource);
    exoPlayer.prepare();

    setUpVideoPlayer(exoPlayer, new QueuingEventSink());
  }

  // Constructor used to directly test members of this class.
  @VisibleForTesting
  VideoPlayer(
      ExoPlayer exoPlayer,
      EventChannel eventChannel,
      TextureRegistry.SurfaceTextureEntry textureEntry,
      VideoPlayerOptions options,
      QueuingEventSink eventSink,
      DefaultTrackSelector trackSelector) {
    this.eventChannel = eventChannel;
    this.textureEntry = textureEntry;
    this.options = options;
    this.trackSelector = trackSelector;

    setUpVideoPlayer(exoPlayer, eventSink);
  }

  private static boolean isHTTP(Uri uri) {
    if (uri == null || uri.getScheme() == null) {
      return false;
    }
    String scheme = uri.getScheme();
    return scheme.equals("http") || scheme.equals("https");
  }

  private MediaSource buildMediaSource(
      Uri uri, DataSource.Factory mediaDataSourceFactory, String formatHint, Context context) {
    int type;
    if (formatHint == null) {
      type = Util.inferContentType(uri);
    } else {
      switch (formatHint) {
        case FORMAT_SS:
          type = C.CONTENT_TYPE_SS;
          break;
        case FORMAT_DASH:
          type = C.CONTENT_TYPE_DASH;
          break;
        case FORMAT_HLS:
          type = C.CONTENT_TYPE_HLS;
          break;
        case FORMAT_OTHER:
          type = C.CONTENT_TYPE_OTHER;
          break;
        default:
          type = -1;
          break;
      }
    }
    switch (type) {
      case C.CONTENT_TYPE_SS:
        return new SsMediaSource.Factory(
                new DefaultSsChunkSource.Factory(mediaDataSourceFactory),
                new DefaultDataSource.Factory(context, mediaDataSourceFactory))
            .createMediaSource(MediaItem.fromUri(uri));
      case C.CONTENT_TYPE_DASH:
        return new DashMediaSource.Factory(
                new DefaultDashChunkSource.Factory(mediaDataSourceFactory),
                new DefaultDataSource.Factory(context, mediaDataSourceFactory))
            .createMediaSource(MediaItem.fromUri(uri));
      case C.CONTENT_TYPE_HLS:
        return new HlsMediaSource.Factory(mediaDataSourceFactory)
            .createMediaSource(MediaItem.fromUri(uri));
      case C.CONTENT_TYPE_OTHER:
        return new ProgressiveMediaSource.Factory(mediaDataSourceFactory)
            .createMediaSource(MediaItem.fromUri(uri));
      default:
        {
          throw new IllegalStateException("Unsupported type: " + type);
        }
    }
  }

  private void setUpVideoPlayer(ExoPlayer exoPlayer, QueuingEventSink eventSink) {
    this.exoPlayer = exoPlayer;
    this.eventSink = eventSink;

    eventChannel.setStreamHandler(
        new EventChannel.StreamHandler() {
          @Override
          public void onListen(Object o, EventChannel.EventSink sink) {
            eventSink.setDelegate(sink);
          }

          @Override
          public void onCancel(Object o) {
            eventSink.setDelegate(null);
          }
        });

    surface = new Surface(textureEntry.surfaceTexture());
    exoPlayer.setVideoSurface(surface);
    setAudioAttributes(exoPlayer, options.mixWithOthers);

    exoPlayer.addListener(
        new Listener() {
          private boolean isBuffering = false;

          public void setBuffering(boolean buffering) {
            if (isBuffering != buffering) {
              isBuffering = buffering;
              Map<String, Object> event = new HashMap<>();
              event.put("event", isBuffering ? "bufferingStart" : "bufferingEnd");
              eventSink.success(event);
            }
          }

          @Override
          public void onPlaybackStateChanged(final int playbackState) {
            if (playbackState == Player.STATE_BUFFERING) {
              setBuffering(true);
              sendBufferingUpdate();
            } else if (playbackState == Player.STATE_READY) {
              if (!isInitialized) {
                isInitialized = true;
                sendInitialized();
              }
            } else if (playbackState == Player.STATE_ENDED) {
              Map<String, Object> event = new HashMap<>();
              event.put("event", "completed");
              eventSink.success(event);
            }

            if (playbackState != Player.STATE_BUFFERING) {
              setBuffering(false);
            }
          }

          @Override
          public void onPlayerError(final PlaybackException error) {
            setBuffering(false);
            if (eventSink != null) {
              eventSink.error("VideoError", "Video player had error " + error, null);
            }
          }
        });
  }

  void sendBufferingUpdate() {
    Map<String, Object> event = new HashMap<>();
    event.put("event", "bufferingUpdate");
    List<? extends Number> range = Arrays.asList(0, exoPlayer.getBufferedPosition());
    // iOS supports a list of buffered ranges, so here is a list with a single range.
    event.put("values", Collections.singletonList(range));
    eventSink.success(event);
  }

  private static void setAudioAttributes(ExoPlayer exoPlayer, boolean isMixMode) {
    exoPlayer.setAudioAttributes(
        new AudioAttributes.Builder().setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(),
        !isMixMode);
  }

  void play() {
    exoPlayer.setPlayWhenReady(true);
  }

  void pause() {
    exoPlayer.setPlayWhenReady(false);
  }

  void setLooping(boolean value) {
    exoPlayer.setRepeatMode(value ? REPEAT_MODE_ALL : REPEAT_MODE_OFF);
  }

  void setVolume(double value) {
    float bracketedValue = (float) Math.max(0.0, Math.min(1.0, value));
    exoPlayer.setVolume(bracketedValue);
  }

  void setPlaybackSpeed(double value) {
    // We do not need to consider pitch and skipSilence for now as we do not handle them and
    // therefore never diverge from the default values.
    final PlaybackParameters playbackParameters = new PlaybackParameters(((float) value));

    exoPlayer.setPlaybackParameters(playbackParameters);
  }

  void setMaxVideoResolution(int width, int height) {
    DefaultTrackSelector.Parameters.Builder builder = trackSelector.buildUponParameters();
    if (width > 0 && height > 0) {
      builder.setMaxVideoSize(width, height);
    } else {
      builder.setMaxVideoSize(Integer.MAX_VALUE, Integer.MAX_VALUE);
    }
    trackSelector.setParameters(builder.build());
  }

  void seekTo(int location) {
    exoPlayer.seekTo(location);
  }

  long getPosition() {
    return exoPlayer.getCurrentPosition();
  }

  long getDuration() {
    return exoPlayer.getDuration();
  }

  boolean getIsPlaying() { return exoPlayer.isPlaying(); }

  void setActivity(@Nullable Activity activity) {
    this.activity = activity;
  }

  void setPipRequestHandler(@Nullable PipRequestHandler handler) {
    this.pipRequestHandler = handler;
  }

  void startPictureInPicture(@Nullable RectF sourceRectLogical) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
      throw new UnsupportedOperationException(
          "Picture-in-Picture requires API level 26 (Android 8.0) or higher.");
    }
    if (activity == null) {
      throw new IllegalStateException(
          "Cannot start Picture-in-Picture: no Activity is available.");
    }

    if (pipRequestHandler != null) {
      pipRequestHandler.onPipRequested();
    }

    // Manual PiP runs in a dedicated activity so the main app stays usable behind the PiP
    // window and the window shows nothing but the video.
    PipActivityController.launch(activity, this, logicalToPixelRect(sourceRectLogical));
  }

  /** Converts a rect in Flutter logical pixels to physical pixels. */
  @Nullable
  private Rect logicalToPixelRect(@Nullable RectF logical) {
    if (logical == null || activity == null) {
      return null;
    }
    float density = activity.getResources().getDisplayMetrics().density;
    return new Rect(
        Math.round(logical.left * density),
        Math.round(logical.top * density),
        Math.round(logical.right * density),
        Math.round(logical.bottom * density));
  }

  /** Redirects video output to the dedicated PiP activity's surface. */
  void attachPipSurface(@NonNull Surface pipSurface) {
    exoPlayer.setVideoSurface(pipSurface);
  }

  /** Restores video output to the Flutter texture. Safe to call repeatedly. */
  void restoreFlutterSurface() {
    if (surface != null) {
      exoPlayer.setVideoSurface(surface);
    }
  }

  void notifyPipStarted() {
    if (videoPlayerCallbacks != null) {
      videoPlayerCallbacks.onPictureInPictureStarted();
    }
  }

  void notifyPipStopped() {
    if (videoPlayerCallbacks != null) {
      videoPlayerCallbacks.onPictureInPictureStopped();
    }
  }

  void stopPictureInPicture() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
      return;
    }
    if (PipActivityController.getPlayer() == this && PipActivityController.isInPipMode()) {
      // Bring the main task forward first so ending PiP doesn't drop the user on the launcher.
      if (activity != null) {
        bringHostActivityToFront();
      }
      PipActivityController.endPip(false, "stopPictureInPicture");
      return;
    }
    if (activity == null || !activity.isInPictureInPictureMode()) {
      return;
    }
    // Auto PiP keeps the host activity itself in PiP, and Android has no direct "exit PiP" API.
    // Bring the activity to front to restore full screen.
    bringHostActivityToFront();
  }

  /** Brings the host activity to the front, restoring it to full screen. */
  private void bringHostActivityToFront() {
    Intent intent = new Intent(activity, activity.getClass());
    intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT | Intent.FLAG_ACTIVITY_SINGLE_TOP);
    activity.startActivity(intent);
  }

  boolean isPictureInPictureSupported() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O || activity == null) {
      return false;
    }
    return activity
        .getPackageManager()
        .hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE);
  }

  boolean isPictureInPictureActive() {
    if (PipActivityController.getPlayer() == this && PipActivityController.isInPipMode()) {
      return true;
    }
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N || activity == null) {
      return false;
    }
    return activity.isInPictureInPictureMode();
  }

  void setAutoPictureInPicture(boolean enabled) {
    this.autoPipEnabled = enabled;

    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
      // API 31 未満では setAutoEnterEnabled が使えない。
      // Flutter 側のフォールバックに委ねるため、要求された enabled 値をそのまま通知。
      sendAutoPipChangedEvent(enabled);
      return;
    }
    if (activity == null) {
      android.util.Log.w("AutoPiP", "activity is null, cannot set auto PiP");
      sendAutoPipChangedEvent(false);
      return;
    }

    if (pipRequestHandler != null && enabled) {
      pipRequestHandler.onPipRequested();
    }

    applyAutoPipParams(enabled);

    sendAutoPipChangedEvent(enabled);
  }

  boolean isAutoPipEnabled() {
    return autoPipEnabled;
  }

  /**
   * Temporarily clears autoEnterEnabled on the host activity while the dedicated PiP activity is
   * showing, so leaving the app cannot pull the host activity into a second PiP window. The
   * autoPipEnabled flag is kept so {@link #updateAutoPipParams()} can restore the params later.
   */
  void suspendAutoEnter() {
    if (autoPipEnabled) {
      applyAutoPipParams(false);
    }
  }

  /** Returns the video aspect ratio, defaulting to 16:9 if unavailable. */
  Rational getVideoAspectRatio() {
    Format videoFormat = exoPlayer.getVideoFormat();
    if (videoFormat != null && videoFormat.width > 0 && videoFormat.height > 0) {
      return new Rational(videoFormat.width, videoFormat.height);
    }
    return new Rational(16, 9);
  }

  private void sendAutoPipChangedEvent(boolean enabled) {
    Map<String, Object> event = new HashMap<>();
    event.put("event", "autoPipChanged");
    event.put("enabled", enabled);
    eventSink.success(event);
  }

  @SuppressWarnings("SuspiciousNameCombination")
  @VisibleForTesting
  void sendInitialized() {
    if (isInitialized) {
      Map<String, Object> event = new HashMap<>();
      event.put("event", "initialized");
      event.put("duration", exoPlayer.getDuration());

      if (exoPlayer.getVideoFormat() != null) {
        Format videoFormat = exoPlayer.getVideoFormat();
        int width = videoFormat.width;
        int height = videoFormat.height;
        int rotationDegrees = videoFormat.rotationDegrees;
        // Switch the width/height if video was taken in portrait mode
        if (rotationDegrees == 90 || rotationDegrees == 270) {
          width = exoPlayer.getVideoFormat().height;
          height = exoPlayer.getVideoFormat().width;
        }
        event.put("width", width);
        event.put("height", height);

        // Rotating the video with ExoPlayer does not seem to be possible with a Surface,
        // so inform the Flutter code that the widget needs to be rotated to prevent
        // upside-down playback for videos with rotationDegrees of 180 (other orientations work
        // correctly without correction).
        if (rotationDegrees == 180) {
          event.put("rotationCorrection", rotationDegrees);
        }
      }

      eventSink.success(event);

      // Update PiP params with the actual video aspect ratio now that the
      // video format is known. When setAutoPictureInPicture was called before
      // initialization, getVideoAspectRatio() returned the 16:9 default.
      updateAutoPipParams();
    }
  }

  /** Re-applies auto PiP params with the current video aspect ratio if enabled. */
  void updateAutoPipParams() {
    if (autoPipEnabled) {
      applyAutoPipParams(true);
    }
  }

  /** Sets host-activity PiP params with the given autoEnter flag. */
  private void applyAutoPipParams(boolean autoEnterEnabled) {
    if (activity == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
      return;
    }
    activity.setPictureInPictureParams(
        new PictureInPictureParams.Builder()
            .setAspectRatio(getVideoAspectRatio())
            .setAutoEnterEnabled(autoEnterEnabled)
            .build());
  }

  boolean isDisposed() {
    return disposed;
  }

  void dispose() {
    disposed = true;
    // End any dedicated PiP session before releasing the player it renders from.
    PipActivityController.onPlayerDisposed(this);
    activity = null;
    if (isInitialized) {
      exoPlayer.stop();
    }
    textureEntry.release();
    eventChannel.setStreamHandler(null);
    if (surface != null) {
      surface.release();
    }
    if (exoPlayer != null) {
      exoPlayer.release();
    }
  }
}
