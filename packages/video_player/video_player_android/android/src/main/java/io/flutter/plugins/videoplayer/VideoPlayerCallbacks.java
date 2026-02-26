// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package io.flutter.plugins.videoplayer;

/**
 * Callbacks representing Picture-in-Picture events invoked by {@link VideoPlayer}.
 *
 * <p>In the actual plugin, this will always be {@link VideoPlayerEventCallbacks}, which creates the
 * expected events to send back through the event channel. In tests methods can be overridden in
 * order to assert results.
 */
public interface VideoPlayerCallbacks {
  void onPictureInPictureStarted();

  void onPictureInPictureStopped();
}
