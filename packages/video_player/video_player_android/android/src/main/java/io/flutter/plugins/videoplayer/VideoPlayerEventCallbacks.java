// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

import androidx.annotation.NonNull;
import java.util.HashMap;
import java.util.Map;

/**
 * Implementation of {@link VideoPlayerCallbacks} that sends PiP events through the existing
 * {@link QueuingEventSink} using the HashMap-based event format.
 *
 * <p>This reuses the same event sink that {@link VideoPlayer} uses for playback events, ensuring
 * PiP events are delivered through the same EventChannel stream.
 */
final class VideoPlayerEventCallbacks implements VideoPlayerCallbacks {
  private final QueuingEventSink eventSink;

  VideoPlayerEventCallbacks(@NonNull QueuingEventSink eventSink) {
    this.eventSink = eventSink;
  }

  @Override
  public void onPictureInPictureStarted() {
    Map<String, Object> event = new HashMap<>();
    event.put("event", "pipStarted");
    eventSink.success(event);
  }

  @Override
  public void onPictureInPictureStopped() {
    Map<String, Object> event = new HashMap<>();
    event.put("event", "pipStopped");
    eventSink.success(event);
  }
}
