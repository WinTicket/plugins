// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'messages.g.dart';

/// An iOS implementation of [VideoPlayerPlatform] that uses the
/// Pigeon-generated [VideoPlayerApi].
class AVFoundationVideoPlayer extends VideoPlayerPlatform {
  final AVFoundationVideoPlayerApi _api = AVFoundationVideoPlayerApi();

  /// Registers this class as the default instance of [VideoPlayerPlatform].
  static void registerWith() {
    VideoPlayerPlatform.instance = AVFoundationVideoPlayer();
  }

  @override
  Future<void> init() {
    return _api.initialize();
  }

  @override
  Future<void> dispose(int textureId) {
    return _api.dispose(TextureMessage(textureId: textureId));
  }

  @override
  Future<int?> create(DataSource dataSource) async {
    String? asset;
    String? packageName;
    String? uri;
    String? formatHint;
    Map<String, String> httpHeaders = <String, String>{};
    switch (dataSource.sourceType) {
      case DataSourceType.asset:
        asset = dataSource.asset;
        packageName = dataSource.package;
        break;
      case DataSourceType.network:
        uri = dataSource.uri;
        formatHint = _videoFormatStringMap[dataSource.formatHint];
        httpHeaders = dataSource.httpHeaders;
        break;
      case DataSourceType.file:
        uri = dataSource.uri;
        break;
      case DataSourceType.contentUri:
        uri = dataSource.uri;
        break;
    }
    final CreateMessage message = CreateMessage(
      asset: asset,
      packageName: packageName,
      uri: uri,
      httpHeaders: httpHeaders,
      formatHint: formatHint,
    );

    final TextureMessage response = await _api.create(message);
    return response.textureId;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) {
    return _api.setLooping(LoopingMessage(
      textureId: textureId,
      isLooping: looping,
    ));
  }

  @override
  Future<void> play(int textureId) {
    return _api.play(TextureMessage(textureId: textureId));
  }

  @override
  Future<void> pause(int textureId) {
    return _api.pause(TextureMessage(textureId: textureId));
  }

  @override
  Future<void> setVolume(int textureId, double volume) {
    return _api.setVolume(VolumeMessage(
      textureId: textureId,
      volume: volume,
    ));
  }

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) {
    assert(speed > 0);

    return _api.setPlaybackSpeed(PlaybackSpeedMessage(
      textureId: textureId,
      speed: speed,
    ));
  }

  @override
  Future<void> seekTo(int textureId, Duration position) async {
    final StartMessage startResponse =
        await _api.start(TextureMessage(textureId: textureId));
    final startDuration = Duration(milliseconds: startResponse.start);
    return _api.seekTo(PositionMessage(
      textureId: textureId,
      position: position.inMilliseconds + startDuration.inMilliseconds,
    ));
  }

  @override
  Future<Duration> getPosition(int textureId) async {
    final PositionMessage response =
        await _api.position(TextureMessage(textureId: textureId));
    final StartMessage startResponse =
        await _api.start(TextureMessage(textureId: textureId));
    return Duration(milliseconds: response.position - startResponse.start);
  }

  @override
  Future<Duration> getDuration(int textureId) async {
    final DurationMessage durationResponse =
        await _api.duration(TextureMessage(textureId: textureId));
    return Duration(milliseconds: durationResponse.duration);
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return _eventChannelFor(textureId)
        .receiveBroadcastStream()
        .map((dynamic event) {
      final Map<dynamic, dynamic> map = event as Map<dynamic, dynamic>;
      switch (map['event']) {
        case 'initialized':
          return VideoEvent(
            eventType: VideoEventType.initialized,
            duration: Duration(milliseconds: map['duration'] as int),
            size: Size((map['width'] as num?)?.toDouble() ?? 0.0,
                (map['height'] as num?)?.toDouble() ?? 0.0),
          );
        case 'completed':
          return VideoEvent(
            eventType: VideoEventType.completed,
          );
        case 'bufferingUpdate':
          final List<dynamic> values = map['values'] as List<dynamic>;

          return VideoEvent(
            buffered: values.map<DurationRange>(_toDurationRange).toList(),
            eventType: VideoEventType.bufferingUpdate,
          );
        case 'bufferingStart':
          return VideoEvent(eventType: VideoEventType.bufferingStart);
        case 'bufferingEnd':
          return VideoEvent(eventType: VideoEventType.bufferingEnd);
        case 'isPlayingStateUpdate':
          return VideoEvent(
            eventType: VideoEventType.isPlayingStateUpdate,
            isPlaying: map['isPlaying'] as bool,
          );
        case 'pipStarted':
          return VideoEvent(eventType: VideoEventType.pipStarted);
        case 'pipStopped':
          return VideoEvent(eventType: VideoEventType.pipStopped);
        case 'pipRestoreUserInterface':
          return VideoEvent(
              eventType: VideoEventType.pipRestoreUserInterface);
        case 'autoPipChanged':
          return VideoEvent(
            eventType: VideoEventType.autoPipChanged,
            isAutoPipEnabled: map['enabled'] as bool? ?? false,
          );
        case 'playbackIntentUpdate':
          return VideoEvent(
            eventType: VideoEventType.playbackIntentUpdate,
            isPlaying: map['isPlaying'] as bool,
          );
        default:
          return VideoEvent(eventType: VideoEventType.unknown);
      }
    });
  }

  @override
  Widget buildView(int textureId) {
    return Texture(textureId: textureId);
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) {
    return _api
        .setMixWithOthers(MixWithOthersMessage(mixWithOthers: mixWithOthers));
  }

  @override
  Future<void> setBuffer(int textureId, Buffer buffer) {
    if (buffer.maxBufferMs == null) return Future.value();
    // maxBufferMsはミリ秒なので秒に変換する
    final second = (buffer.maxBufferMs! / 1000).toInt();
    return _api.setBuffer(BufferMessage(textureId: textureId, second: second));
  }

  @override
  Future<void> setMaxVideoResolution(int textureId, int? width, int? height) {
    final int sanitizedWidth = (width != null && width > 0) ? width : 0;
    final int sanitizedHeight = (height != null && height > 0) ? height : 0;
    return _api.setMaxVideoResolution(
      MaxVideoResolutionMessage(
        textureId: textureId,
        width: sanitizedWidth,
        height: sanitizedHeight,
      ),
    );
  }

  @override
  Future<bool> getIsPlaying(int textureId) async {
    final IsPlayingMessage isPlayingResponse =
        await _api.isPlaying(TextureMessage(textureId: textureId));
    return isPlayingResponse.isPlaying;
  }

  @override
  Future<void> stopPictureInPicture(int textureId, {Rect? sourceRect}) {
    return _api.stopPictureInPicture(PipStopMessage(
      textureId: textureId,
      x: sourceRect?.left,
      y: sourceRect?.top,
      width: sourceRect?.width,
      height: sourceRect?.height,
    ));
  }

  @override
  Future<void> setAutoPictureInPicture(int textureId, bool enabled) {
    return _api.setAutoPictureInPicture(
        PipStatusMessage(textureId: textureId, value: enabled));
  }

  @override
  Future<void> setRequiresLinearPlayback(
      int textureId, bool requiresLinearPlayback) {
    return _api.setRequiresLinearPlayback(
        PipStatusMessage(textureId: textureId, value: requiresLinearPlayback));
  }

  @override
  Future<void> completePipRestoreWithSourceRect(
      int textureId, double x, double y, double width, double height) {
    return _api.completePipRestoreWithSourceRect(PipSourceRectMessage(
      textureId: textureId,
      x: x,
      y: y,
      width: width,
      height: height,
    ));
  }

  EventChannel _eventChannelFor(int textureId) {
    return EventChannel('flutter.io/videoPlayer/videoEvents$textureId');
  }

  static const Map<VideoFormat, String> _videoFormatStringMap =
      <VideoFormat, String>{
    VideoFormat.ss: 'ss',
    VideoFormat.hls: 'hls',
    VideoFormat.dash: 'dash',
    VideoFormat.other: 'other',
  };

  DurationRange _toDurationRange(dynamic value) {
    final List<dynamic> pair = value as List<dynamic>;
    return DurationRange(
      Duration(milliseconds: pair[0] as int),
      Duration(milliseconds: pair[1] as int),
    );
  }
}
