// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static java.lang.Math.toIntExact;

import android.app.Activity;
import android.content.Context;
import android.os.Build;
import android.util.LongSparseArray;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.OnPictureInPictureModeChangedProvider;
import androidx.core.app.PictureInPictureModeChangedInfo;
import androidx.core.util.Consumer;
import com.google.android.exoplayer2.DefaultLoadControl;
import io.flutter.FlutterInjector;
import io.flutter.Log;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.PluginRegistry;
import io.flutter.plugins.videoplayer.Messages.AndroidVideoPlayerApi;
import io.flutter.plugins.videoplayer.Messages.BufferMessage;
import io.flutter.plugins.videoplayer.Messages.CreateMessage;
import io.flutter.plugins.videoplayer.Messages.DurationMessage;
import io.flutter.plugins.videoplayer.Messages.IsPlayingMessage;
import io.flutter.plugins.videoplayer.Messages.LoopingMessage;
import io.flutter.plugins.videoplayer.Messages.MaxVideoResolutionMessage;
import io.flutter.plugins.videoplayer.Messages.MixWithOthersMessage;
import io.flutter.plugins.videoplayer.Messages.PipStatusMessage;
import io.flutter.plugins.videoplayer.Messages.PlaybackSpeedMessage;
import io.flutter.plugins.videoplayer.Messages.PositionMessage;
import io.flutter.plugins.videoplayer.Messages.TextureMessage;
import io.flutter.plugins.videoplayer.Messages.VolumeMessage;
import io.flutter.view.TextureRegistry;
import java.util.Map;

/** Android platform implementation of the VideoPlayerPlugin. */
public class VideoPlayerPlugin implements FlutterPlugin, ActivityAware, AndroidVideoPlayerApi {
  private static final String TAG = "VideoPlayerPlugin";
  private final LongSparseArray<VideoPlayer> videoPlayers = new LongSparseArray<>();
  private FlutterState flutterState;
  private VideoPlayerOptions options = new VideoPlayerOptions();
  @Nullable private Activity activity;
  // Tracks which player last requested PiP, so events go to the right player.
  private long lastPipPlayerId = -1;
  @Nullable private Consumer<PictureInPictureModeChangedInfo> pipModeChangedListener;
  private final PluginRegistry.UserLeaveHintListener userLeaveHintListener =
      this::onUserLeaveHint;
  @Nullable private ActivityPluginBinding userLeaveHintBinding;

  /** Register this with the v2 embedding for the plugin to respond to lifecycle callbacks. */
  public VideoPlayerPlugin() {}

  @Override
  public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
    final FlutterInjector injector = FlutterInjector.instance();
    this.flutterState =
            new FlutterState(
                    binding.getApplicationContext(),
                    binding.getBinaryMessenger(),
                    injector.flutterLoader()::getLookupKeyForAsset,
                    injector.flutterLoader()::getLookupKeyForAsset,
                    binding.getTextureRegistry());
    flutterState.startListening(this, binding.getBinaryMessenger());
  }

  @Override
  public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
    if (flutterState == null) {
      Log.wtf(TAG, "Detached from the engine before registering to it.");
    }
    flutterState.stopListening(binding.getBinaryMessenger());
    flutterState = null;
    unregisterUserLeaveHintListener();
    onDestroy();
  }

  // -- ActivityAware implementation --

  @Override
  public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
    setActivityOnAllPlayers(activity);
    registerPipModeChangedListener(binding);
    registerUserLeaveHintListener(binding);
  }

  @Override
  public void onDetachedFromActivityForConfigChanges() {
    unregisterUserLeaveHintListener();
    activity = null;
    setActivityOnAllPlayers(null);
  }

  @Override
  public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
    activity = binding.getActivity();
    setActivityOnAllPlayers(activity);
    registerPipModeChangedListener(binding);
    registerUserLeaveHintListener(binding);
  }

  @Override
  public void onDetachedFromActivity() {
    unregisterUserLeaveHintListener();
    activity = null;
    setActivityOnAllPlayers(null);
    pipModeChangedListener = null;
  }

  private void setActivityOnAllPlayers(@Nullable Activity activity) {
    for (int i = 0; i < videoPlayers.size(); i++) {
      videoPlayers.valueAt(i).setActivity(activity);
    }
  }

  // Registers a listener for PiP mode changes. This requires the host Activity to implement
  // OnPictureInPictureModeChangedProvider (e.g. FlutterFragmentActivity). If the Activity is a
  // plain FlutterActivity (which extends Activity directly), PiP mode change events will not be
  // delivered and the Dart side will not receive pipStarted/pipStopped events.
  private void registerPipModeChangedListener(@NonNull ActivityPluginBinding binding) {
    Activity boundActivity = binding.getActivity();
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
        && boundActivity instanceof OnPictureInPictureModeChangedProvider) {
      OnPictureInPictureModeChangedProvider provider =
          (OnPictureInPictureModeChangedProvider) boundActivity;

      // Remove existing listener to prevent double registration on config changes.
      if (pipModeChangedListener != null) {
        provider.removeOnPictureInPictureModeChangedListener(pipModeChangedListener);
      }

      pipModeChangedListener =
          info -> {
            if (lastPipPlayerId < 0) {
              return;
            }
            VideoPlayer player = videoPlayers.get(lastPipPlayerId);
            if (player == null || player.videoPlayerCallbacks == null) {
              return;
            }
            if (info.isInPictureInPictureMode()) {
              player.videoPlayerCallbacks.onPictureInPictureStarted();
            } else {
              player.videoPlayerCallbacks.onPictureInPictureStopped();
              // Auto PiP が有効な場合は lastPipPlayerId を保持する。
              // リセットすると、2回目以降の auto PiP 進入時に pipStarted イベントが
              // 送信されず、Dart 側が PiP を認識できなくなる。
              if (!player.isAutoPipEnabled()) {
                lastPipPlayerId = -1;
              }
            }
          };
      provider.addOnPictureInPictureModeChangedListener(pipModeChangedListener);
    }
  }

  private void registerUserLeaveHintListener(@NonNull ActivityPluginBinding binding) {
    unregisterUserLeaveHintListener();
    if (!VideoPlayer.supportsExplicitAutoPictureInPicture()) {
      return;
    }
    userLeaveHintBinding = binding;
    binding.addOnUserLeaveHintListener(userLeaveHintListener);
  }

  private void unregisterUserLeaveHintListener() {
    if (userLeaveHintBinding != null) {
      userLeaveHintBinding.removeOnUserLeaveHintListener(userLeaveHintListener);
    }
    userLeaveHintBinding = null;
  }

  private void onUserLeaveHint() {
    VideoPlayer player = videoPlayers.get(lastPipPlayerId);
    if (player != null) {
      player.enterAutoPictureInPicture();
    }
  }

  private void disposeAllPlayers() {
    for (int i = 0; i < videoPlayers.size(); i++) {
      videoPlayers.valueAt(i).dispose();
    }
    videoPlayers.clear();
  }

  private void onDestroy() {
    // The whole FlutterView is being destroyed. Here we release resources acquired for all
    // instances
    // of VideoPlayer. Once https://github.com/flutter/flutter/issues/19358 is resolved this may
    // be replaced with just asserting that videoPlayers.isEmpty().
    // https://github.com/flutter/flutter/issues/20989 tracks this.
    disposeAllPlayers();
  }

  @Override
  public void initialize() {
    disposeAllPlayers();
  }

  public TextureMessage create(CreateMessage arg) {
    TextureRegistry.SurfaceTextureEntry handle =
        flutterState.textureRegistry.createSurfaceTexture();
    EventChannel eventChannel =
        new EventChannel(
            flutterState.binaryMessenger, "flutter.io/videoPlayer/videoEvents" + handle.id());

    VideoPlayer player;
    if (arg.getAsset() != null) {
      String assetLookupKey;
      if (arg.getPackageName() != null) {
        assetLookupKey =
            flutterState.keyForAssetAndPackageName.get(arg.getAsset(), arg.getPackageName());
      } else {
        assetLookupKey = flutterState.keyForAsset.get(arg.getAsset());
      }
      player =
          new VideoPlayer(
              flutterState.applicationContext,
              eventChannel,
              handle,
              "asset:///" + assetLookupKey,
              null,
              null,
              options);
    } else {
      @SuppressWarnings("unchecked")
      Map<String, String> httpHeaders = arg.getHttpHeaders();
      player =
          new VideoPlayer(
              flutterState.applicationContext,
              eventChannel,
              handle,
              arg.getUri(),
              arg.getFormatHint(),
              httpHeaders,
              options);
    }
    // Provide Activity reference, PiP event callbacks, and PiP tracking for PiP support.
    player.setActivity(activity);
    player.videoPlayerCallbacks = new VideoPlayerEventCallbacks(player.eventSink);
    final long playerId = handle.id();
    player.setPipRequestHandler(() -> lastPipPlayerId = playerId);

    videoPlayers.put(handle.id(), player);

    return new TextureMessage.Builder().setTextureId(handle.id()).build();
  }

  public void dispose(TextureMessage arg) {
    long textureId = arg.getTextureId();
    VideoPlayer player = videoPlayers.get(textureId);
    player.dispose();
    videoPlayers.remove(textureId);
    // Reset lastPipPlayerId if the disposed player was the PiP player.
    if (lastPipPlayerId == textureId) {
      lastPipPlayerId = -1;
    }
  }

  public void setLooping(LoopingMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    player.setLooping(arg.getIsLooping());
  }

  public void setVolume(VolumeMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    player.setVolume(arg.getVolume());
  }

  public void setPlaybackSpeed(PlaybackSpeedMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    player.setPlaybackSpeed(arg.getSpeed());
  }

  public void play(TextureMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    player.play();
  }

  public PositionMessage position(TextureMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    PositionMessage result =
        new PositionMessage.Builder()
            .setPosition(player.getPosition())
            .setTextureId(arg.getTextureId())
            .build();
    player.sendBufferingUpdate();
    return result;
  }

  public DurationMessage duration(TextureMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    DurationMessage result =
            new DurationMessage.Builder()
                .setDuration(player.getDuration())
                .setTextureId(arg.getTextureId())
                .build();
    player.sendBufferingUpdate();
    return result;
  }

  public IsPlayingMessage isPlaying(TextureMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    IsPlayingMessage result =
            new IsPlayingMessage.Builder()
                    .setIsPlaying(player.getIsPlaying())
                    .setTextureId(arg.getTextureId())
                    .build();
    return result;
  }

  public void seekTo(PositionMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    player.seekTo(arg.getPosition().intValue());
  }

  public void pause(TextureMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    player.pause();
  }

  @Override
  public void setMixWithOthers(MixWithOthersMessage arg) {
    options.mixWithOthers = arg.getMixWithOthers();
  }

  @Override
  public void setBuffer(BufferMessage arg) {
    if (arg == null) return;
    VideoPlayerBuffer buffer = new VideoPlayerBuffer();
    buffer.minBufferMs = (arg.getMinBufferMs() == null)
        ? DefaultLoadControl.DEFAULT_MIN_BUFFER_MS
        : toIntExact(arg.getMinBufferMs());
    buffer.maxBufferMs = (arg.getMaxBufferMs() == null)
        ? DefaultLoadControl.DEFAULT_MAX_BUFFER_MS
        : toIntExact(arg.getMaxBufferMs());
    buffer.bufferForPlaybackMs = (arg.getBufferForPlaybackMs() == null)
        ? DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_MS
        : toIntExact(arg.getBufferForPlaybackMs());
    buffer.bufferForPlaybackAfterRebufferMs = (arg.getBufferForPlaybackAfterRebufferMs() == null)
        ? DefaultLoadControl.DEFAULT_BUFFER_FOR_PLAYBACK_AFTER_REBUFFER_MS
        : toIntExact(arg.getBufferForPlaybackAfterRebufferMs());
    options.buffer = buffer;
  }

  @Override
  public void setMaxVideoResolution(MaxVideoResolutionMessage arg) {
    if (arg == null) {
      return;
    }
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    if (player != null) {
      long rawWidth = arg.getWidth() == null ? 0 : arg.getWidth();
      long rawHeight = arg.getHeight() == null ? 0 : arg.getHeight();
      int width = rawWidth > Integer.MAX_VALUE ? Integer.MAX_VALUE : toIntExact(rawWidth);
      int height = rawHeight > Integer.MAX_VALUE ? Integer.MAX_VALUE : toIntExact(rawHeight);
      player.setMaxVideoResolution(width, height);
    }
  }

  @Override
  public void stopPictureInPicture(TextureMessage arg) {
    VideoPlayer player = videoPlayers.get(arg.getTextureId());
    player.stopPictureInPicture();
  }

  @Override
  public void setAutoPictureInPicture(@NonNull PipStatusMessage msg) {
    VideoPlayer player = videoPlayers.get(msg.getTextureId());
    if (player != null) {
      // Disable auto PiP on all other players to avoid Activity-level params conflict.
      if (msg.getValue()) {
        for (int i = 0; i < videoPlayers.size(); i++) {
          long key = videoPlayers.keyAt(i);
          if (key != msg.getTextureId() && videoPlayers.valueAt(i).isAutoPipEnabled()) {
            videoPlayers.valueAt(i).setAutoPictureInPicture(false);
          }
        }
      }
      player.setAutoPictureInPicture(msg.getValue());
    }
  }

  private interface KeyForAssetFn {
    String get(String asset);
  }

  private interface KeyForAssetAndPackageName {
    String get(String asset, String packageName);
  }

  private static final class FlutterState {
    private final Context applicationContext;
    private final BinaryMessenger binaryMessenger;
    private final KeyForAssetFn keyForAsset;
    private final KeyForAssetAndPackageName keyForAssetAndPackageName;
    private final TextureRegistry textureRegistry;

    FlutterState(
        Context applicationContext,
        BinaryMessenger messenger,
        KeyForAssetFn keyForAsset,
        KeyForAssetAndPackageName keyForAssetAndPackageName,
        TextureRegistry textureRegistry) {
      this.applicationContext = applicationContext;
      this.binaryMessenger = messenger;
      this.keyForAsset = keyForAsset;
      this.keyForAssetAndPackageName = keyForAssetAndPackageName;
      this.textureRegistry = textureRegistry;
    }

    void startListening(VideoPlayerPlugin methodCallHandler, BinaryMessenger messenger) {
      AndroidVideoPlayerApi.setup(messenger, methodCallHandler);
    }

    void stopListening(BinaryMessenger messenger) {
      AndroidVideoPlayerApi.setup(messenger, null);
    }
  }
}
