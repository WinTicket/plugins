// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// ignore_for_file: public_member_api_docs

/// An example of using the plugin, controlling lifecycle and playback of the
/// video.

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
  late VideoPlayerController _remoteController;
  late VideoPlayerController _assetController;
  late VideoPlayerController _raceController;

  @override
  void initState() {
    super.initState();
    _remoteController = VideoPlayerController.network(
      'https://flutter.github.io/assets-for-api-docs/assets/videos/bee.mp4',
      closedCaptionFile: _loadCaptions(),
      // videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      // iOSのPicture-in-Pictureでスキップ(早送り/巻き戻し)ボタンを隠す場合はtrueにする。
      videoPlayerOptions: VideoPlayerOptions(requiresLinearPlayback: true),
    );
    _assetController = VideoPlayerController.asset('assets/Butterfly-209.mp4');

    _remoteController.addListener(_onStateChanged);
    _assetController.addListener(_onStateChanged);

    _remoteController.setLooping(true);
    _remoteController.initialize();

    _assetController.setLooping(true);
    _assetController.initialize().then((_) => setState(() {}));
    _assetController.play();

    // Race タブ専用。Asset タブと同じ動画だが、PiP 復帰先の候補が混ざらないよう別 controller にする。
    _raceController = VideoPlayerController.asset('assets/Butterfly-209.mp4');
    _raceController.setLooping(true);
    _raceController.initialize().then((_) => setState(() {}));
    _raceController.play();
  }

  Future<ClosedCaptionFile> _loadCaptions() async {
    final String fileContents = await DefaultAssetBundle.of(context)
        .loadString('assets/bumble_bee_captions.vtt');
    return WebVTTCaptionFile(
        fileContents); // For vtt files, use WebVTTCaptionFile
  }

  void _onStateChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _remoteController.removeListener(_onStateChanged);
    _assetController.removeListener(_onStateChanged);
    _remoteController.dispose();
    _assetController.dispose();
    _raceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        key: const ValueKey<String>('home_page'),
        appBar: AppBar(
          title: const Text('Video player example'),
          actions: <Widget>[
            IconButton(
              key: const ValueKey<String>('push_tab'),
              icon: const Icon(Icons.navigation),
              onPressed: () {
                Navigator.push<_PlayerVideoAndPopPage>(
                  context,
                  MaterialPageRoute<_PlayerVideoAndPopPage>(
                    builder: (BuildContext context) => _PlayerVideoAndPopPage(),
                  ),
                );
              },
            )
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(
                icon: Icon(Icons.cloud),
                text: 'Remote',
              ),
              Tab(icon: Icon(Icons.insert_drive_file), text: 'Asset'),
              Tab(icon: Icon(Icons.list), text: 'List example'),
              Tab(icon: Icon(Icons.layers), text: 'Race'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _BumbleBeeRemoteVideo(controller: _remoteController),
            _ButterFlyAssetVideo(controller: _assetController),
            _ButterFlyAssetVideoInList(),
            _RaceScenario(controller: _raceController),
          ],
        ),
      ),
    );
  }
}

class _ButterFlyAssetVideoInList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: <Widget>[
        const _ExampleCard(title: 'Item a'),
        const _ExampleCard(title: 'Item b'),
        const _ExampleCard(title: 'Item c'),
        const _ExampleCard(title: 'Item d'),
        const _ExampleCard(title: 'Item e'),
        const _ExampleCard(title: 'Item f'),
        const _ExampleCard(title: 'Item g'),
        Card(
            child: Column(children: <Widget>[
          Column(
            children: <Widget>[
              const ListTile(
                leading: Icon(Icons.cake),
                title: Text('Video video'),
              ),
              Stack(
                  alignment: FractionalOffset.bottomRight +
                      const FractionalOffset(-0.1, -0.1),
                  children: <Widget>[
                    _ButterFlyAssetVideoStandalone(),
                    Image.asset('assets/flutter-mark-square-64.png'),
                  ]),
            ],
          ),
        ])),
        const _ExampleCard(title: 'Item h'),
        const _ExampleCard(title: 'Item i'),
        const _ExampleCard(title: 'Item j'),
        const _ExampleCard(title: 'Item k'),
        const _ExampleCard(title: 'Item l'),
      ],
    );
  }
}

/// A standalone asset video widget that manages its own controller (used in list).
class _ButterFlyAssetVideoStandalone extends StatefulWidget {
  @override
  _ButterFlyAssetVideoStandaloneState createState() =>
      _ButterFlyAssetVideoStandaloneState();
}

class _ButterFlyAssetVideoStandaloneState
    extends State<_ButterFlyAssetVideoStandalone> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/Butterfly-209.mp4');
    _controller.addListener(() {
      setState(() {});
    });
    _controller.setLooping(true);
    _controller.initialize().then((_) => setState(() {}));
    // _controller.play();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          const SizedBox(height: 20.0),
          const Text('With assets mp4'),
          Container(
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  VideoPlayer(_controller),
                  _ControlsOverlay(controller: _controller),
                  VideoProgressIndicator(_controller, allowScrubbing: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A filler card to show the video in a list of scrolling contents.
class _ExampleCard extends StatelessWidget {
  const _ExampleCard({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.airline_seat_flat_angled),
            title: Text(title),
          ),
          OverflowBar(
            children: <Widget>[
              TextButton(
                child: const Text('BUY TICKETS'),
                onPressed: () {
                  /* ... */
                },
              ),
              TextButton(
                child: const Text('SELL TICKETS'),
                onPressed: () {
                  /* ... */
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ButterFlyAssetVideo extends StatelessWidget {
  const _ButterFlyAssetVideo({Key? key, required this.controller})
      : super(key: key);

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          const SizedBox(height: 20.0),
          const Text('With assets mp4'),
          Container(
            padding: const EdgeInsets.all(20),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: <Widget>[
                  VideoPlayer(controller),
                  _ControlsOverlay(controller: controller),
                  VideoProgressIndicator(controller, allowScrubbing: true),
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

class _BumbleBeeRemoteVideo extends StatelessWidget {
  const _BumbleBeeRemoteVideo({Key? key, required this.controller})
      : super(key: key);

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: <Widget>[
          const SizedBox(height: 20.0),
          const Text('With remote mp4'),
          Container(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: 200,
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: <Widget>[
                    VideoPlayer(controller),
                    ClosedCaption(text: controller.value.caption.text),
                    _ControlsOverlay(controller: controller),
                    VideoProgressIndicator(controller, allowScrubbing: true),
                  ],
                ),
              ),
            ),
          ),
          Text(controller.value.isPlaying ? 'Playing' : 'Paused'),
          _PipControls(controller: controller),
          for (final int i in List<int>.generate(10, (int index) => index))
            Container(
              height: 100,
              color: i.isEven ? Colors.amberAccent : Colors.blueAccent,
            ),
        ],
      ),
    );
  }
}

/// アプリの「レース詳細」画面の構成を再現し、PiP 復帰先の決まり方を確認するシナリオ。
///
/// - 下部タブは IndexedStack で、非選択タブの映像は裏に残る。
/// - 詳細タブの映像が見えている間はアプリ内 PiP を出さない。
///   他のタブへ移動した時、または映像がスクロールで見切れた時にアプリ内 PiP を出す。
/// - アプリ内 PiP は画面端へ収納 (stow) できる。収納中も復帰先の候補になる。
///
/// 確認手順: Auto PiP を ON → ホームへ → ネイティブ PiP の復帰ボタンを押す。
/// 各状態 (投票タブ / スクロール見切れ / stow 中) で、復帰先が見えている映像に
/// なることを確認する。
class _RaceScenario extends StatefulWidget {
  const _RaceScenario({Key? key, required this.controller}) : super(key: key);

  final VideoPlayerController controller;

  @override
  State<_RaceScenario> createState() => _RaceScenarioState();
}

class _RaceScenarioState extends State<_RaceScenario> {
  static const double _videoHeight = 200;
  static const double _pipWidth = 160;
  static const double _pipHeight = 90;
  static const double _pipMargin = 16;
  // 収納時に画面端の外へ隠す余白。アプリの PiP の stow と同じ考え方。
  static const double _stowHiddenMargin = 8;
  static const double _stowHandleSize = 40;

  final ScrollController _scrollController = ScrollController();
  int _tabIndex = 0;
  bool _isScrolledOut = false;
  bool _isStowed = false;
  String _restoreRectText = '-';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  // 再生状態や進捗の表示を更新する。アプリと同様に、詳細側が頻繁に rebuild される。
  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _togglePlayback() {
    final VideoPlayerController controller = widget.controller;
    controller.value.isPlaying ? controller.pause() : controller.play();
  }

  void _onScroll() {
    final bool isScrolledOut = _scrollController.offset > _videoHeight;
    if (isScrolledOut == _isScrolledOut) {
      return;
    }
    setState(() {
      _isScrolledOut = isScrolledOut;
    });
  }

  void _checkRestoreRect() {
    // 動作確認用。復帰先として今選ばれる Rect を表示する。
    // ignore: invalid_use_of_visible_for_testing_member
    final Rect? rect = widget.controller.pipSourceRectForTesting;
    debugPrint('PiP restore rect: $rect');
    setState(() {
      _restoreRectText = rect == null ? 'null' : rect.toString();
    });
  }

  Widget _buildPlaybackControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Row(
        children: <Widget>[
          IconButton(
            key: const ValueKey<String>('race_play_pause'),
            tooltip: widget.controller.value.isPlaying ? 'Pause' : 'Play',
            icon: Icon(
              widget.controller.value.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
            ),
            onPressed: _togglePlayback,
          ),
          Expanded(
            child: VideoProgressIndicator(
              widget.controller,
              allowScrubbing: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTab() {
    return ListView(
      controller: _scrollController,
      children: <Widget>[
        SizedBox(
          height: _videoHeight,
          child: ColoredBox(
            color: Colors.black,
            child: Center(
              child: AspectRatio(
                aspectRatio: widget.controller.value.aspectRatio,
                child: VideoPlayer(widget.controller),
              ),
            ),
          ),
        ),
        _buildPlaybackControls(),
        _PipControls(controller: widget.controller),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ElevatedButton(
                onPressed: _checkRestoreRect,
                child: const Text('Check restore rect'),
              ),
              Text('Restore rect: $_restoreRectText'),
            ],
          ),
        ),
        for (final int i in List<int>.generate(10, (int index) => index))
          Container(
            height: 100,
            color: i.isEven ? Colors.amberAccent : Colors.blueAccent,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isPipVisible = _tabIndex != 0 || _isScrolledOut;

    return Scaffold(
      body: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: IndexedStack(
              index: _tabIndex,
              children: <Widget>[
                _buildDetailTab(),
                const Center(child: Text('Betting sheet')),
                const Center(child: Text('Betting input')),
              ],
            ),
          ),
          if (isPipVisible)
            Positioned(
              right: _isStowed ? -(_pipWidth + _stowHiddenMargin) : _pipMargin,
              bottom: _pipMargin,
              width: _pipWidth,
              height: _pipHeight,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: <Widget>[
                    VideoPlayer(widget.controller),
                    Center(
                      child: IconButton(
                        key: const ValueKey<String>('pip_play_pause'),
                        tooltip:
                            widget.controller.value.isPlaying ? 'Pause' : 'Play',
                        color: Colors.white,
                        icon: Icon(
                          widget.controller.value.isPlaying
                              ? Icons.pause_circle
                              : Icons.play_circle,
                        ),
                        onPressed: _togglePlayback,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isPipVisible)
            Positioned(
              right: 0,
              bottom: _pipMargin + (_pipHeight - _stowHandleSize) / 2,
              child: IconButton(
                key: const ValueKey<String>('toggle_stow'),
                tooltip: _isStowed ? 'Restore PiP' : 'Stow PiP',
                icon: Icon(
                  _isStowed ? Icons.chevron_left : Icons.chevron_right,
                ),
                onPressed: () => setState(() {
                  _isStowed = !_isStowed;
                }),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabIndex,
        onTap: (int index) => setState(() {
          _tabIndex = index;
        }),
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.videocam),
            label: 'Detail',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long),
            label: 'Sheet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.edit),
            label: 'Input',
          ),
        ],
      ),
    );
  }
}

class _PipControls extends StatefulWidget {
  const _PipControls({Key? key, required this.controller}) : super(key: key);

  final VideoPlayerController controller;

  @override
  State<_PipControls> createState() => _PipControlsState();
}

class _PipControlsState extends State<_PipControls> {
  // requiresLinearPlaybackはネイティブ側からの読み戻しイベントが無いため、
  // UI側でローカルに状態を保持する。初期値はVideoPlayerOptionsで渡した値と揃える。
  bool _requiresLinearPlayback = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
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
          Text('Active: ${widget.controller.value.isPipActive}'),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: widget.controller.value.isPipActive
                ? () => widget.controller.stopPictureInPicture()
                : null,
            icon: const Icon(Icons.fullscreen_exit),
            label: const Text('Stop PiP'),
          ),
          SwitchListTile(
            title: const Text('Require Linear Playback'),
            subtitle: const Text('PiPウィンドウのスキップボタンを隠す(iOSのみ)'),
            value: _requiresLinearPlayback,
            onChanged: (bool requiresLinearPlayback) {
              setState(() {
                _requiresLinearPlayback = requiresLinearPlayback;
              });
              widget.controller
                  .setRequiresLinearPlayback(requiresLinearPlayback);
            },
          ),
          SwitchListTile(
            title: const Text('Auto PiP'),
            value: widget.controller.value.isAutoPipEnabled,
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

  static const List<Duration> _exampleCaptionOffsets = <Duration>[
    Duration(seconds: -10),
    Duration(seconds: -3),
    Duration(seconds: -1, milliseconds: -500),
    Duration(milliseconds: -250),
    Duration.zero,
    Duration(milliseconds: 250),
    Duration(seconds: 1, milliseconds: 500),
    Duration(seconds: 3),
    Duration(seconds: 10),
  ];
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

  final VideoPlayerController controller;

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
          alignment: Alignment.topLeft,
          child: PopupMenuButton<Duration>(
            initialValue: controller.value.captionOffset,
            tooltip: 'Caption Offset',
            onSelected: (Duration delay) {
              controller.setCaptionOffset(delay);
            },
            itemBuilder: (BuildContext context) {
              return <PopupMenuItem<Duration>>[
                for (final Duration offsetDuration in _exampleCaptionOffsets)
                  PopupMenuItem<Duration>(
                    value: offsetDuration,
                    child: Text('${offsetDuration.inMilliseconds}ms'),
                  )
              ];
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
              child: Text('${controller.value.captionOffset.inMilliseconds}ms'),
            ),
          ),
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

class _PlayerVideoAndPopPage extends StatefulWidget {
  @override
  _PlayerVideoAndPopPageState createState() => _PlayerVideoAndPopPageState();
}

class _PlayerVideoAndPopPageState extends State<_PlayerVideoAndPopPage> {
  late VideoPlayerController _videoPlayerController;
  bool startedPlaying = false;

  @override
  void initState() {
    super.initState();

    _videoPlayerController =
        VideoPlayerController.asset('assets/Butterfly-209.mp4');
    _videoPlayerController.addListener(() {
      if (startedPlaying && !_videoPlayerController.value.isPlaying) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    super.dispose();
  }

  Future<bool> started() async {
    await _videoPlayerController.initialize();
    await _videoPlayerController.play();
    startedPlaying = true;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Center(
        child: FutureBuilder<bool>(
          future: started(),
          builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
            if (snapshot.data ?? false) {
              return AspectRatio(
                aspectRatio: _videoPlayerController.value.aspectRatio,
                child: VideoPlayer(_videoPlayerController),
              );
            } else {
              return const Text('waiting for video to load');
            }
          },
        ),
      ),
    );
  }
}
