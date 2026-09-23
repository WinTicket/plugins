// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import android.app.Activity;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.PluginRegistry;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.mockito.ArgumentCaptor;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.annotation.Config;

@RunWith(RobolectricTestRunner.class)
public class VideoPlayerPluginTest {
  @Test
  public void initPluginDoesNotThrow() {
    final VideoPlayerPlugin plugin = new VideoPlayerPlugin();
  }

  @Test
  @Config(sdk = 28)
  public void userLeaveHintListenerFollowsActivityLifecycle() {
    VideoPlayerPlugin plugin = new VideoPlayerPlugin();
    ActivityPluginBinding firstBinding = mock(ActivityPluginBinding.class);
    ActivityPluginBinding secondBinding = mock(ActivityPluginBinding.class);
    when(firstBinding.getActivity()).thenReturn(mock(Activity.class));
    when(secondBinding.getActivity()).thenReturn(mock(Activity.class));

    plugin.onAttachedToActivity(firstBinding);
    ArgumentCaptor<PluginRegistry.UserLeaveHintListener> firstListener =
        ArgumentCaptor.forClass(PluginRegistry.UserLeaveHintListener.class);
    verify(firstBinding).addOnUserLeaveHintListener(firstListener.capture());

    plugin.onDetachedFromActivityForConfigChanges();
    verify(firstBinding).removeOnUserLeaveHintListener(firstListener.getValue());

    plugin.onReattachedToActivityForConfigChanges(secondBinding);
    ArgumentCaptor<PluginRegistry.UserLeaveHintListener> secondListener =
        ArgumentCaptor.forClass(PluginRegistry.UserLeaveHintListener.class);
    verify(secondBinding).addOnUserLeaveHintListener(secondListener.capture());

    plugin.onDetachedFromActivity();
    verify(secondBinding).removeOnUserLeaveHintListener(secondListener.getValue());
  }

  @Test
  @Config(sdk = 25)
  public void listenerIsNotRegisteredBeforeAndroid8() {
    VideoPlayerPlugin plugin = new VideoPlayerPlugin();
    ActivityPluginBinding binding = mock(ActivityPluginBinding.class);
    when(binding.getActivity()).thenReturn(mock(Activity.class));

    plugin.onAttachedToActivity(binding);

    verify(binding, never()).addOnUserLeaveHintListener(any());
  }

  @Test
  @Config(sdk = 31)
  public void listenerIsNotRegisteredOnAndroid12() {
    VideoPlayerPlugin plugin = new VideoPlayerPlugin();
    ActivityPluginBinding binding = mock(ActivityPluginBinding.class);
    when(binding.getActivity()).thenReturn(mock(Activity.class));

    plugin.onAttachedToActivity(binding);

    verify(binding, never()).addOnUserLeaveHintListener(any());
  }
}
