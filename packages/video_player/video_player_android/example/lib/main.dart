// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

import 'package:flutter/material.dart';

import 'mini_controller.dart';

void main() {
  runApp(
    MaterialApp(
      home: _App(),
    ),
  );
}

class _App extends StatefulWidget {
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  late MiniController _assetController;
  late MiniController _remoteController;

  @override
  void initState() {
    super.initState();
    _assetController = MiniController.asset('assets/Butterfly-209.mp4');
    _remoteController = MiniController.network(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
    );

    _assetController.addListener(_onStateChanged);
    _remoteController.addListener(_onStateChanged);

    _assetController.initialize().then((_) => setState(() {}));
    _assetController.play();
    _remoteController.initialize();
  }

  void _onStateChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _assetController.removeListener(_onStateChanged);
    _remoteController.removeListener(_onStateChanged);
    _assetController.dispose();
    _remoteController.dispose();
    super.dispose();
  }

  /// Returns the controller that is currently in PiP mode, or null.
  MiniController? get _pipController {
    if (_assetController.isPipActive) {
      return _assetController;
    }
    if (_remoteController.isPipActive) {
      return _remoteController;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final MiniController? pip = _pipController;

    // PiP mode: show only the video, filling the entire window.
    if (pip != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: AspectRatio(
            aspectRatio: pip.value.aspectRatio,
            child: VideoPlayer(pip),
          ),
        ),
      );
    }

    // Normal mode: tabbed layout with controls.
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        key: const ValueKey<String>('home_page'),
        appBar: AppBar(
          title: const Text('Video player example'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(
                icon: Icon(Icons.cloud),
                text: 'Remote',
              ),
              Tab(icon: Icon(Icons.insert_drive_file), text: 'Asset'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _VideoTab(controller: _remoteController, label: 'With remote mp4'),
            _VideoTab(controller: _assetController, label: 'With assets mp4'),
          ],
        ),
      ),
    );
  }
}

class _VideoTab extends StatelessWidget {
  const _VideoTab({
    Key? key,
    required this.controller,
    required this.label,
  }) : super(key: key);

  final MiniController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          Container(padding: const EdgeInsets.only(top: 20.0)),
          Text(label),
          Container(
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  VideoPlayer(controller),
                  _ControlsOverlay(controller: controller),
                  VideoProgressIndicator(controller),
                ],
              ),
            ),
          ),
          _PipControls(controller: controller),
        ],
      ),
    );
  }
}

class _PipControls extends StatefulWidget {
  const _PipControls({Key? key, required this.controller}) : super(key: key);

  final MiniController controller;

  @override
  State<_PipControls> createState() => _PipControlsState();
}

class _PipControlsState extends State<_PipControls> {
  late VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      if (mounted) {
        setState(() {});
      }
    };
    widget.controller.addListener(_listener);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Picture-in-Picture',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Active: ${widget.controller.isPipActive}'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: widget.controller.isPipActive
                ? () => widget.controller.stopPictureInPicture()
                : null,
            icon: const Icon(Icons.fullscreen_exit),
            label: const Text('Stop PiP'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Auto PiP'),
            value: widget.controller.isAutoPipEnabled,
            onChanged: (bool enabled) {
              widget.controller.setAutoPictureInPicture(enabled);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _ControlsOverlay extends StatelessWidget {
  const _ControlsOverlay({Key? key, required this.controller})
      : super(key: key);

  static const List<double> _examplePlaybackRates = <double>[
    0.25,
    0.5,
    1.0,
    1.5,
    2.0,
    3.0,
    5.0,
    10.0,
  ];

  final MiniController controller;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 50),
          reverseDuration: const Duration(milliseconds: 200),
          child: controller.value.isPlaying
              ? const SizedBox.shrink()
              : Container(
                  color: Colors.black26,
                  child: const Center(
                    child: Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 100.0,
                      semanticLabel: 'Play',
                    ),
                  ),
                ),
        ),
        GestureDetector(
          onTap: () {
            controller.value.isPlaying ? controller.pause() : controller.play();
          },
        ),
        Align(
          alignment: Alignment.topRight,
          child: PopupMenuButton<double>(
            initialValue: controller.value.playbackSpeed,
            tooltip: 'Playback speed',
            onSelected: (double speed) {
              controller.setPlaybackSpeed(speed);
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuItem<double>>[
                for (final double speed in _examplePlaybackRates)
                  PopupMenuItem<double>(
                    value: speed,
                    child: Text('${speed}x'),
                  )
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                // Using less vertical padding as the text is also longer
                // horizontally, so it feels like it would need more spacing
                // horizontally (matching the aspect ratio of the video).
                vertical: 12,
                horizontal: 16,
              ),
              child: Text('${controller.value.playbackSpeed}x'),
            ),
          ),
        ),
      ],
    );
  }
}
