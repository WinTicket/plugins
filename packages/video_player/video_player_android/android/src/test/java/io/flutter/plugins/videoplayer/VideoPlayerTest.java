// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import android.app.Activity;
import android.app.PictureInPictureParams;
import android.content.pm.PackageManager;
import android.util.Rational;
import com.google.android.exoplayer2.ExoPlayer;
import com.google.android.exoplayer2.Format;
import com.google.android.exoplayer2.Player;
import com.google.android.exoplayer2.trackselection.DefaultTrackSelector;
import io.flutter.plugin.common.EventChannel;
import io.flutter.view.TextureRegistry;
import java.util.HashMap;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Captor;
import org.mockito.MockitoAnnotations;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
public class VideoPlayerTest {
  private ExoPlayer fakeExoPlayer;
  private EventChannel fakeEventChannel;
  private TextureRegistry.SurfaceTextureEntry fakeSurfaceTextureEntry;
  private VideoPlayerOptions fakeVideoPlayerOptions;
  private QueuingEventSink fakeEventSink;
  private DefaultTrackSelector trackSelector;

  @Captor private ArgumentCaptor<HashMap<String, Object>> eventCaptor;
  @Captor private ArgumentCaptor<Player.Listener> listenerCaptor;

  @Before
  public void before() {
    MockitoAnnotations.openMocks(this);

    fakeExoPlayer = mock(ExoPlayer.class);
    fakeEventChannel = mock(EventChannel.class);
    fakeSurfaceTextureEntry = mock(TextureRegistry.SurfaceTextureEntry.class);
    fakeVideoPlayerOptions = mock(VideoPlayerOptions.class);
    fakeEventSink = mock(QueuingEventSink.class);
    trackSelector = new DefaultTrackSelector(RuntimeEnvironment.getApplication());
  }

  @Test
  public void sendInitializedSendsExpectedEvent_90RotationDegrees() {
    VideoPlayer videoPlayer =
        new VideoPlayer(
            fakeExoPlayer,
            fakeEventChannel,
            fakeSurfaceTextureEntry,
            fakeVideoPlayerOptions,
            fakeEventSink,
            trackSelector);
    Format testFormat =
        new Format.Builder().setWidth(100).setHeight(200).setRotationDegrees(90).build();

    when(fakeExoPlayer.getVideoFormat()).thenReturn(testFormat);
    when(fakeExoPlayer.getDuration()).thenReturn(10L);

    videoPlayer.isInitialized = true;
    videoPlayer.sendInitialized();

    verify(fakeEventSink).success(eventCaptor.capture());
    HashMap<String, Object> event = eventCaptor.getValue();

    assertEquals(event.get("event"), "initialized");
    assertEquals(event.get("duration"), 10L);
    assertEquals(event.get("width"), 200);
    assertEquals(event.get("height"), 100);
    assertEquals(event.get("rotationCorrection"), null);
  }

  @Test
  public void sendInitializedSendsExpectedEvent_270RotationDegrees() {
    VideoPlayer videoPlayer =
        new VideoPlayer(
            fakeExoPlayer,
            fakeEventChannel,
            fakeSurfaceTextureEntry,
            fakeVideoPlayerOptions,
            fakeEventSink,
            trackSelector);
    Format testFormat =
        new Format.Builder().setWidth(100).setHeight(200).setRotationDegrees(270).build();

    when(fakeExoPlayer.getVideoFormat()).thenReturn(testFormat);
    when(fakeExoPlayer.getDuration()).thenReturn(10L);

    videoPlayer.isInitialized = true;
    videoPlayer.sendInitialized();

    verify(fakeEventSink).success(eventCaptor.capture());
    HashMap<String, Object> event = eventCaptor.getValue();

    assertEquals(event.get("event"), "initialized");
    assertEquals(event.get("duration"), 10L);
    assertEquals(event.get("width"), 200);
    assertEquals(event.get("height"), 100);
    assertEquals(event.get("rotationCorrection"), null);
  }

  @Test
  public void sendInitializedSendsExpectedEvent_0RotationDegrees() {
    VideoPlayer videoPlayer =
        new VideoPlayer(
            fakeExoPlayer,
            fakeEventChannel,
            fakeSurfaceTextureEntry,
            fakeVideoPlayerOptions,
            fakeEventSink,
            trackSelector);
    Format testFormat =
        new Format.Builder().setWidth(100).setHeight(200).setRotationDegrees(0).build();

    when(fakeExoPlayer.getVideoFormat()).thenReturn(testFormat);
    when(fakeExoPlayer.getDuration()).thenReturn(10L);

    videoPlayer.isInitialized = true;
    videoPlayer.sendInitialized();

    verify(fakeEventSink).success(eventCaptor.capture());
    HashMap<String, Object> event = eventCaptor.getValue();

    assertEquals(event.get("event"), "initialized");
    assertEquals(event.get("duration"), 10L);
    assertEquals(event.get("width"), 100);
    assertEquals(event.get("height"), 200);
    assertEquals(event.get("rotationCorrection"), null);
  }

  @Test
  public void sendInitializedSendsExpectedEvent_180RotationDegrees() {
    VideoPlayer videoPlayer =
        new VideoPlayer(
            fakeExoPlayer,
            fakeEventChannel,
            fakeSurfaceTextureEntry,
            fakeVideoPlayerOptions,
            fakeEventSink,
            trackSelector);
    Format testFormat =
        new Format.Builder().setWidth(100).setHeight(200).setRotationDegrees(180).build();

    when(fakeExoPlayer.getVideoFormat()).thenReturn(testFormat);
    when(fakeExoPlayer.getDuration()).thenReturn(10L);

    videoPlayer.isInitialized = true;
    videoPlayer.sendInitialized();

    verify(fakeEventSink).success(eventCaptor.capture());
    HashMap<String, Object> event = eventCaptor.getValue();

    assertEquals(event.get("event"), "initialized");
    assertEquals(event.get("duration"), 10L);
    assertEquals(event.get("width"), 100);
    assertEquals(event.get("height"), 200);
    assertEquals(event.get("rotationCorrection"), 180);
  }

  @Test
  public void isPlayingChangeSendsExpectedEvent() {
    new VideoPlayer(
        fakeExoPlayer,
        fakeEventChannel,
        fakeSurfaceTextureEntry,
        fakeVideoPlayerOptions,
        fakeEventSink,
        trackSelector);

    verify(fakeExoPlayer).addListener(listenerCaptor.capture());
    listenerCaptor.getValue().onIsPlayingChanged(false);

    verify(fakeEventSink).success(eventCaptor.capture());
    HashMap<String, Object> event = eventCaptor.getValue();
    assertEquals(event.get("event"), "isPlayingStateUpdate");
    assertEquals(event.get("isPlaying"), false);
  }

  @Test
  @Config(sdk = 28)
  public void enterAutoPictureInPictureEntersOnAndroid9WhenEligible() {
    Activity activity = mock(Activity.class);
    PackageManager packageManager = mock(PackageManager.class);
    when(activity.getPackageManager()).thenReturn(packageManager);
    when(packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE))
        .thenReturn(true);
    when(fakeExoPlayer.isPlaying()).thenReturn(true);
    when(activity.enterPictureInPictureMode(any(PictureInPictureParams.class))).thenReturn(true);

    VideoPlayer videoPlayer = createVideoPlayer();
    VideoPlayer.PipRequestHandler pipRequestHandler = mock(VideoPlayer.PipRequestHandler.class);
    videoPlayer.setActivity(activity);
    videoPlayer.setPipRequestHandler(pipRequestHandler);
    videoPlayer.setAutoPictureInPicture(true);

    assertTrue(videoPlayer.enterAutoPictureInPicture());

    verify(pipRequestHandler).onPipRequested();
    ArgumentCaptor<PictureInPictureParams> paramsCaptor =
        ArgumentCaptor.forClass(PictureInPictureParams.class);
    verify(activity).enterPictureInPictureMode(paramsCaptor.capture());
    assertEquals(new Rational(16, 9), paramsCaptor.getValue().getAspectRatio());
  }

  @Test
  @Config(sdk = 28)
  public void enterAutoPictureInPictureReturnsFalseWhenSystemRejectsPip() {
    Activity activity = mock(Activity.class);
    PackageManager packageManager = mock(PackageManager.class);
    when(activity.getPackageManager()).thenReturn(packageManager);
    when(packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE))
        .thenReturn(true);
    when(fakeExoPlayer.isPlaying()).thenReturn(true);
    when(activity.enterPictureInPictureMode(any(PictureInPictureParams.class)))
        .thenThrow(
            new IllegalStateException(
                "enterPictureInPictureMode: Device doesn't support picture-in-picture mode."));

    VideoPlayer videoPlayer = createVideoPlayer();
    videoPlayer.setActivity(activity);
    videoPlayer.setAutoPictureInPicture(true);

    assertFalse(videoPlayer.enterAutoPictureInPicture());
    verify(activity).enterPictureInPictureMode(any(PictureInPictureParams.class));
  }

  @Test
  @Config(sdk = 28)
  public void enterAutoPictureInPictureDoesNotEnterWhenIneligible() {
    Activity activity = mock(Activity.class);
    PackageManager packageManager = mock(PackageManager.class);
    when(activity.getPackageManager()).thenReturn(packageManager);
    when(packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE))
        .thenReturn(true);
    when(fakeExoPlayer.isPlaying()).thenReturn(true);

    VideoPlayer videoPlayer = createVideoPlayer();
    videoPlayer.setActivity(activity);

    assertFalse(videoPlayer.enterAutoPictureInPicture());

    videoPlayer.setAutoPictureInPicture(true);
    when(fakeExoPlayer.isPlaying()).thenReturn(false);
    assertFalse(videoPlayer.enterAutoPictureInPicture());

    when(fakeExoPlayer.isPlaying()).thenReturn(true);
    when(packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE))
        .thenReturn(false);
    assertFalse(videoPlayer.enterAutoPictureInPicture());

    when(packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE))
        .thenReturn(true);
    when(activity.isInPictureInPictureMode()).thenReturn(true);
    assertFalse(videoPlayer.enterAutoPictureInPicture());

    verify(activity, never()).enterPictureInPictureMode(any(PictureInPictureParams.class));
  }

  @Test
  @Config(sdk = 31)
  public void enterAutoPictureInPictureDoesNotEnterExplicitlyOnAndroid12() {
    Activity activity = mock(Activity.class);
    when(fakeExoPlayer.isPlaying()).thenReturn(true);

    VideoPlayer videoPlayer = createVideoPlayer();
    videoPlayer.setActivity(activity);
    videoPlayer.setAutoPictureInPicture(true);

    assertFalse(videoPlayer.enterAutoPictureInPicture());
    verify(activity, never()).enterPictureInPictureMode(any(PictureInPictureParams.class));
  }

  private VideoPlayer createVideoPlayer() {
    return new VideoPlayer(
        fakeExoPlayer,
        fakeEventChannel,
        fakeSurfaceTextureEntry,
        fakeVideoPlayerOptions,
        fakeEventSink,
        trackSelector);
  }
}
