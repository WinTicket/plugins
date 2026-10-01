// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class FakeController extends ValueNotifier<VideoPlayerValue>
    implements VideoPlayerController {
  FakeController() : super(VideoPlayerValue(duration: Duration.zero));

  FakeController.value(VideoPlayerValue value) : super(value);

  @override
  Future<void> dispose() async {
    super.dispose();
  }

  @override
  int textureId = VideoPlayerController.kUninitializedTextureId;

  @override
  String get dataSource => '';

  @override
  Map<String, String> get httpHeaders => <String, String>{};

  @override
  DataSourceType get dataSourceType => DataSourceType.file;

  @override
  String get package => '';

  @override
  Future<Duration> get position async => value.position;

  @override
  Future<Duration?> get duration async => value.duration;

  @override
  Future<void> seekTo(Duration moment) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setMaxVideoResolution(int? width, int? height) async {}

  @override
  Future<void> initialize() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> setLooping(bool looping) async {}

  @override
  VideoFormat? get formatHint => null;

  @override
  Future<ClosedCaptionFile> get closedCaptionFile => _loadClosedCaption();

  @override
  VideoPlayerOptions? get videoPlayerOptions => null;

  @override
  void setCaptionOffset(Duration delay) {}

  @override
  Future<void> setClosedCaptionFile(
    Future<ClosedCaptionFile>? closedCaptionFile,
  ) async {}

  @override
  Future<bool> get isPlaying async => value.isPlaying;

  @override
  Future<void> setBuffer(Buffer buffer) async {}

  @override
  Future<void> stopPictureInPicture() async {}

  @override
  Future<void> setAutoPictureInPicture(bool enabled) async {}

  @override
  Future<void> setRequiresLinearPlayback(bool requiresLinearPlayback) async {}

  @override
  void Function(bool isActive)? onPipActiveChanged;

  final List<_FakePipSourceRectRegistration> _pipSourceRectProviders =
      <_FakePipSourceRectRegistration>[];

  @override
  void addPipSourceRectProvider(
    Rect? Function() provider, {
    bool isExplicit = false,
  }) {
    _pipSourceRectProviders.removeWhere(
        (_FakePipSourceRectRegistration r) => r.provider == provider);
    _pipSourceRectProviders
        .add(_FakePipSourceRectRegistration(provider, isExplicit));
  }

  @override
  void removePipSourceRectProvider(Rect? Function() provider) {
    _pipSourceRectProviders.removeWhere(
        (_FakePipSourceRectRegistration r) => r.provider == provider);
  }

  @override
  Rect? get pipSourceRectForTesting {
    final Iterable<_FakePipSourceRectRegistration> explicit =
        _pipSourceRectProviders
            .where((_FakePipSourceRectRegistration r) => r.isExplicit);
    for (final _FakePipSourceRectRegistration registration
        in explicit.toList().reversed) {
      final Rect? rect = registration.provider();
      if (rect != null) {
        return rect;
      }
    }
    for (final _FakePipSourceRectRegistration registration
        in _pipSourceRectProviders.reversed) {
      final Rect? rect = registration.provider();
      if (rect != null) {
        return rect;
      }
    }
    return null;
  }
}

class _FakePipSourceRectRegistration {
  _FakePipSourceRectRegistration(this.provider, this.isExplicit);
  final Rect? Function() provider;
  final bool isExplicit;
}

Future<ClosedCaptionFile> _loadClosedCaption() async =>
    _FakeClosedCaptionFile();

class _FakeClosedCaptionFile extends ClosedCaptionFile {
  @override
  List<Caption> get captions {
    return <Caption>[
      const Caption(
        text: 'one',
        number: 0,
        start: Duration(milliseconds: 100),
        end: Duration(milliseconds: 200),
      ),
      const Caption(
        text: 'two',
        number: 1,
        start: Duration(milliseconds: 300),
        end: Duration(milliseconds: 400),
      ),
    ];
  }
}

void main() {
  void _verifyPlayStateRespondsToLifecycle(
    VideoPlayerController controller, {
    required bool shouldPlayInBackground,
  }) {
    expect(controller.value.isPlaying, true);
    _ambiguate(WidgetsBinding.instance)!
        .handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(controller.value.isPlaying, shouldPlayInBackground);
    _ambiguate(WidgetsBinding.instance)!
        .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(controller.value.isPlaying, true);
  }

  testWidgets('update texture', (WidgetTester tester) async {
    final FakeController controller = FakeController();
    await tester.pumpWidget(VideoPlayer(controller));
    expect(find.byType(Texture), findsNothing);

    controller.textureId = 123;
    controller.value = controller.value.copyWith(
      duration: const Duration(milliseconds: 100),
      isInitialized: true,
    );

    await tester.pump();
    expect(find.byType(Texture), findsOneWidget);
  });

  testWidgets('update controller', (WidgetTester tester) async {
    final FakeController controller1 = FakeController();
    controller1.textureId = 101;
    await tester.pumpWidget(VideoPlayer(controller1));
    expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is Texture && widget.textureId == 101,
        ),
        findsOneWidget);

    final FakeController controller2 = FakeController();
    controller2.textureId = 102;
    await tester.pumpWidget(VideoPlayer(controller2));
    expect(
        find.byWidgetPredicate(
          (Widget widget) => widget is Texture && widget.textureId == 102,
        ),
        findsOneWidget);
  });

  testWidgets('provides the video source rect for PiP restore',
      (WidgetTester tester) async {
    final FakeController controller = FakeController()..textureId = 123;

    await tester.pumpWidget(
      Center(
        child: SizedBox(
          width: 320,
          height: 180,
          child: VideoPlayer(controller),
        ),
      ),
    );

    expect(
      controller.pipSourceRectForTesting,
      tester.getRect(find.byType(Texture)),
    );

    await tester.pumpWidget(const SizedBox.shrink());

    expect(controller.pipSourceRectForTesting, isNull);
  });

  testWidgets('親が rebuild されても PiP 復帰先の優先順位が変わらない',
      (WidgetTester tester) async {
    final FakeController controller = FakeController()..textureId = 123;

    // 同一インスタンスを使い回し、rebuild 時に didUpdateWidget が呼ばれるのを
    // 先に mount された方だけにする。
    final Widget laterPlayer = VideoPlayer(controller);

    Widget build(int rebuildCount) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: <Widget>[
            // 先に mount された方 (rebuild 対象)。
            Positioned(
              left: 0,
              top: 0,
              width: 100 + rebuildCount.toDouble(),
              height: 100,
              child: VideoPlayer(controller),
            ),
            // 後から mount された方。優先されるべき。
            Positioned(
              left: 200,
              top: 0,
              width: 100,
              height: 100,
              child: laterPlayer,
            ),
          ],
        ),
      );
    }

    await tester.pumpWidget(build(0));
    final Rect? before = controller.pipSourceRectForTesting;
    expect(before?.left, 200);

    // 先に mount された方だけが rebuild されても、優先順位は変わらない。
    await tester.pumpWidget(build(1));
    expect(controller.pipSourceRectForTesting?.left, 200);
  });

  testWidgets(
      '同じ controller を共有する場合、後から mount された方が優先され、 '
      'unmount されると先に mount された方に戻る',
      (WidgetTester tester) async {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    final VideoPlayerController controller =
        VideoPlayerController.file(File(''));
    await tester.runAsync(controller.initialize);
    addTearDown(() => tester.runAsync(controller.dispose));

    // 詳細画面の映像 (先に mount) と、アプリ内 PiP (後から mount) を想定する。
    Widget build({required bool showLaterPlayer}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: <Widget>[
            Positioned(
              left: 0,
              top: 0,
              width: 100,
              height: 100,
              child: VideoPlayer(controller),
            ),
            if (showLaterPlayer)
              Positioned(
                left: 200,
                top: 0,
                width: 100,
                height: 100,
                child: VideoPlayer(controller),
              ),
          ],
        ),
      );
    }

    await tester.pumpWidget(build(showLaterPlayer: false));
    expect(controller.pipSourceRectForTesting?.left, 0);

    await tester.pumpWidget(build(showLaterPlayer: true));
    expect(controller.pipSourceRectForTesting?.left, 200);

    // 後から mount された方が消えると、先に mount された方が候補に戻る。
    await tester.pumpWidget(build(showLaterPlayer: false));
    expect(controller.pipSourceRectForTesting?.left, 0);
  });

  testWidgets('controller が変わると PiP 復帰先の provider が新しい controller に移る',
      (WidgetTester tester) async {
    final FakeController oldController = FakeController()..textureId = 1;
    final FakeController newController = FakeController()..textureId = 2;

    Widget build(FakeController controller) {
      return SizedBox(width: 100, height: 100, child: VideoPlayer(controller));
    }

    await tester.pumpWidget(build(oldController));
    expect(oldController.pipSourceRectForTesting, isNotNull);
    expect(newController.pipSourceRectForTesting, isNull);

    await tester.pumpWidget(build(newController));
    expect(oldController.pipSourceRectForTesting, isNull);
    expect(newController.pipSourceRectForTesting, isNotNull);
  });

  group('タブ構成 (IndexedStack + アプリ内 PiP) での PiP 復帰先', () {
    // example の Race タブと同じ構成。
    // - 詳細タブ (index 0) の映像は、他のタブへ切り替えても IndexedStack で裏に残る。
    // - アプリ内 PiP は、詳細タブ以外を表示している間だけ後から mount される。
    // - stow 中の PiP は画面端の外へ移動する。
    const Rect detailRect = Rect.fromLTWH(0, 0, 320, 180);
    const Rect pipRect = Rect.fromLTWH(624, 494, 160, 90);
    const Rect stowedPipRect = Rect.fromLTWH(808, 494, 160, 90);

    // 実アプリではスクロールやタブ切り替えで詳細側だけが rebuild されるため、
    // PiP 側の VideoPlayer は同一インスタンスを使い回して didUpdateWidget を
    // 呼ばせない。
    Widget buildRace(
      VideoPlayerController controller, {
      required Widget pipPlayer,
      required int tabIndex,
      bool isStowed = false,
    }) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 800,
            height: 600,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: IndexedStack(
                    index: tabIndex,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.topLeft,
                        child: SizedBox(
                          width: 320,
                          height: 180,
                          child: VideoPlayer(controller),
                        ),
                      ),
                      const SizedBox.expand(),
                      const SizedBox.expand(),
                    ],
                  ),
                ),
                if (tabIndex != 0)
                  Positioned(
                    right: isStowed ? -168.0 : 16.0,
                    bottom: 16,
                    width: 160,
                    height: 90,
                    child: pipPlayer,
                  ),
              ],
            ),
          ),
        ),
      );
    }

    Future<VideoPlayerController> createController(
      WidgetTester tester,
    ) async {
      VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
      final VideoPlayerController controller =
          VideoPlayerController.file(File(''));
      await tester.runAsync(controller.initialize);
      addTearDown(() => tester.runAsync(controller.dispose));
      return controller;
    }

    testWidgets('詳細タブを表示している間は、詳細の映像が復帰先になる',
        (WidgetTester tester) async {
      final VideoPlayerController controller = await createController(tester);
      final Widget pipPlayer = VideoPlayer(controller);
      Widget race(int tabIndex, {bool isStowed = false}) => buildRace(
            controller,
            pipPlayer: pipPlayer,
            tabIndex: tabIndex,
            isStowed: isStowed,
          );

      await tester.pumpWidget(race(0));

      expect(controller.pipSourceRectForTesting, detailRect);
    });

    testWidgets('他のタブへ切り替えて詳細タブが裏に残っても、アプリ内 PiP が復帰先になる',
        (WidgetTester tester) async {
      final VideoPlayerController controller = await createController(tester);
      final Widget pipPlayer = VideoPlayer(controller);
      Widget race(int tabIndex, {bool isStowed = false}) => buildRace(
            controller,
            pipPlayer: pipPlayer,
            tabIndex: tabIndex,
            isStowed: isStowed,
          );

      await tester.pumpWidget(race(0));
      await tester.pumpWidget(race(1));
      expect(controller.pipSourceRectForTesting, pipRect);

      // タブ間を行き来して詳細タブが rebuild されても、PiP が優先され続ける。
      await tester.pumpWidget(race(2));
      expect(controller.pipSourceRectForTesting, pipRect);
      await tester.pumpWidget(race(1));
      expect(controller.pipSourceRectForTesting, pipRect);
    });

    testWidgets('詳細タブへ戻って PiP が消えると、詳細の映像が復帰先に戻る',
        (WidgetTester tester) async {
      final VideoPlayerController controller = await createController(tester);
      final Widget pipPlayer = VideoPlayer(controller);
      Widget race(int tabIndex, {bool isStowed = false}) => buildRace(
            controller,
            pipPlayer: pipPlayer,
            tabIndex: tabIndex,
            isStowed: isStowed,
          );

      await tester.pumpWidget(race(1));
      expect(controller.pipSourceRectForTesting, pipRect);

      await tester.pumpWidget(race(0));
      expect(controller.pipSourceRectForTesting, detailRect);
    });

    testWidgets('PiP を stow して画面外にあっても、PiP が復帰先になる',
        (WidgetTester tester) async {
      final VideoPlayerController controller = await createController(tester);
      final Widget pipPlayer = VideoPlayer(controller);
      Widget race(int tabIndex, {bool isStowed = false}) => buildRace(
            controller,
            pipPlayer: pipPlayer,
            tabIndex: tabIndex,
            isStowed: isStowed,
          );

      await tester.pumpWidget(race(1));
      await tester.pumpWidget(race(1, isStowed: true));

      expect(controller.pipSourceRectForTesting, stowedPipRect);
    });

    testWidgets('詳細タブをスクロールして映像が見切れると、アプリ内 PiP が復帰先になる',
        (WidgetTester tester) async {
      final VideoPlayerController controller = await createController(tester);
      final GlobalKey<_RaceTabsHarnessState> key =
          GlobalKey<_RaceTabsHarnessState>();
      await tester.pumpWidget(_RaceTabsHarness(key: key, controller: controller));
      expect(controller.pipSourceRectForTesting, detailRect);

      // 映像が上に見切れても、キャッシュ範囲内では詳細側の VideoPlayer は残る。
      key.currentState!.scrollTo(300);
      await tester.pump();

      expect(controller.pipSourceRectForTesting, pipRect);
    });

    testWidgets('PiP が出た後に詳細だけが rebuild されても、アプリ内 PiP が復帰先になる',
        (WidgetTester tester) async {
      final VideoPlayerController controller = await createController(tester);
      final GlobalKey<_RaceTabsHarnessState> key =
          GlobalKey<_RaceTabsHarnessState>();
      await tester.pumpWidget(_RaceTabsHarness(key: key, controller: controller));

      key.currentState!.scrollTo(300);
      await tester.pump();
      expect(controller.pipSourceRectForTesting, pipRect);

      key.currentState!.rebuild();
      await tester.pump();

      expect(controller.pipSourceRectForTesting, pipRect);
    });

    testWidgets('大きくスクロールして詳細の映像が破棄されても、アプリ内 PiP が復帰先になる',
        (WidgetTester tester) async {
      final VideoPlayerController controller = await createController(tester);
      final GlobalKey<_RaceTabsHarnessState> key =
          GlobalKey<_RaceTabsHarnessState>();
      await tester.pumpWidget(_RaceTabsHarness(key: key, controller: controller));

      key.currentState!.scrollTo(1500);
      await tester.pump();

      expect(controller.pipSourceRectForTesting, pipRect);
    });

    testWidgets('スクロールした状態でタブを切り替えて戻っても、アプリ内 PiP が復帰先になる',
        (WidgetTester tester) async {
      final VideoPlayerController controller = await createController(tester);
      final GlobalKey<_RaceTabsHarnessState> key =
          GlobalKey<_RaceTabsHarnessState>();
      await tester.pumpWidget(_RaceTabsHarness(key: key, controller: controller));

      key.currentState!.scrollTo(300);
      await tester.pump();
      key.currentState!.selectTab(1);
      await tester.pump();
      expect(controller.pipSourceRectForTesting, pipRect);

      // 詳細タブへ戻っても、映像はまだ見切れているので PiP のまま。
      key.currentState!.selectTab(0);
      await tester.pump();
      expect(controller.pipSourceRectForTesting, pipRect);
    });

    testWidgets('スクロールを戻して映像が見えると、詳細の映像が復帰先に戻る',
        (WidgetTester tester) async {
      final VideoPlayerController controller = await createController(tester);
      final GlobalKey<_RaceTabsHarnessState> key =
          GlobalKey<_RaceTabsHarnessState>();
      await tester.pumpWidget(_RaceTabsHarness(key: key, controller: controller));

      key.currentState!.scrollTo(300);
      await tester.pump();
      expect(controller.pipSourceRectForTesting, pipRect);

      key.currentState!.scrollTo(0);
      await tester.pump();
      expect(controller.pipSourceRectForTesting, detailRect);
    });
  });

  testWidgets('non-zero rotationCorrection value is used',
      (WidgetTester tester) async {
    final FakeController controller = FakeController.value(
        VideoPlayerValue(duration: Duration.zero, rotationCorrection: 180));
    controller.textureId = 1;
    await tester.pumpWidget(VideoPlayer(controller));
    final Transform actualRotationCorrection =
        find.byType(Transform).evaluate().single.widget as Transform;
    final Float64List actualRotationCorrectionStorage =
        actualRotationCorrection.transform.storage;
    final Float64List expectedMatrixStorage =
        Matrix4.rotationZ(math.pi).storage;
    expect(actualRotationCorrectionStorage.length,
        equals(expectedMatrixStorage.length));
    for (int i = 0; i < actualRotationCorrectionStorage.length; i++) {
      expect(actualRotationCorrectionStorage[i],
          moreOrLessEquals(expectedMatrixStorage[i]));
    }
  });

  testWidgets('no transform when rotationCorrection is zero',
      (WidgetTester tester) async {
    final FakeController controller =
        FakeController.value(VideoPlayerValue(duration: Duration.zero));
    controller.textureId = 1;
    await tester.pumpWidget(VideoPlayer(controller));
    expect(find.byType(Transform), findsNothing);
  });

  group('ClosedCaption widget', () {
    testWidgets('uses a default text style', (WidgetTester tester) async {
      const String text = 'foo';
      await tester
          .pumpWidget(const MaterialApp(home: ClosedCaption(text: text)));

      final Text textWidget = tester.widget<Text>(find.text(text));
      expect(textWidget.style!.fontSize, 36.0);
      expect(textWidget.style!.color, Colors.white);
    });

    testWidgets('uses given text and style', (WidgetTester tester) async {
      const String text = 'foo';
      const TextStyle textStyle = TextStyle(fontSize: 14.725);
      await tester.pumpWidget(const MaterialApp(
        home: ClosedCaption(
          text: text,
          textStyle: textStyle,
        ),
      ));
      expect(find.text(text), findsOneWidget);

      final Text textWidget = tester.widget<Text>(find.text(text));
      expect(textWidget.style!.fontSize, textStyle.fontSize);
    });

    testWidgets('handles null text', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ClosedCaption()));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('handles empty text', (WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: ClosedCaption(text: '')));
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('Passes text contrast ratio guidelines',
        (WidgetTester tester) async {
      const String text = 'foo';
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: ClosedCaption(text: text),
        ),
      ));
      expect(find.text(text), findsOneWidget);

      await expectLater(tester, meetsGuideline(textContrastGuideline));
    }, skip: isBrowser);
  });

  group('VideoPlayerController', () {
    late FakeVideoPlayerPlatform fakeVideoPlayerPlatform;

    setUp(() {
      fakeVideoPlayerPlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakeVideoPlayerPlatform;
    });

    group('initialize', () {
      test('started app lifecycle observing', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        await controller.play();
        _verifyPlayStateRespondsToLifecycle(controller,
            shouldPlayInBackground: false);
      });

      test('asset', () async {
        final VideoPlayerController controller = VideoPlayerController.asset(
          'a.avi',
        );
        await controller.initialize();

        expect(fakeVideoPlayerPlatform.dataSources[0].asset, 'a.avi');
        expect(fakeVideoPlayerPlatform.dataSources[0].package, null);
      });

      test('network', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();

        expect(
          fakeVideoPlayerPlatform.dataSources[0].uri,
          'https://127.0.0.1',
        );
        expect(
          fakeVideoPlayerPlatform.dataSources[0].formatHint,
          null,
        );
        expect(
          fakeVideoPlayerPlatform.dataSources[0].httpHeaders,
          <String, String>{},
        );
      });

      test('network with hint', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
          formatHint: VideoFormat.dash,
        );
        await controller.initialize();

        expect(
          fakeVideoPlayerPlatform.dataSources[0].uri,
          'https://127.0.0.1',
        );
        expect(
          fakeVideoPlayerPlatform.dataSources[0].formatHint,
          VideoFormat.dash,
        );
        expect(
          fakeVideoPlayerPlatform.dataSources[0].httpHeaders,
          <String, String>{},
        );
      });

      test('network with some headers', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
          httpHeaders: <String, String>{'Authorization': 'Bearer token'},
        );
        await controller.initialize();

        expect(
          fakeVideoPlayerPlatform.dataSources[0].uri,
          'https://127.0.0.1',
        );
        expect(
          fakeVideoPlayerPlatform.dataSources[0].formatHint,
          null,
        );
        expect(
          fakeVideoPlayerPlatform.dataSources[0].httpHeaders,
          <String, String>{'Authorization': 'Bearer token'},
        );
      });

      test('init errors', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'http://testing.com/invalid_url',
        );

        late Object error;
        fakeVideoPlayerPlatform.forceInitError = true;
        await controller.initialize().catchError((Object e) => error = e);
        final PlatformException platformEx = error as PlatformException;
        expect(platformEx.code, equals('VideoError'));
      });

      test('file', () async {
        final VideoPlayerController controller =
            VideoPlayerController.file(File('a.avi'));
        await controller.initialize();

        expect(fakeVideoPlayerPlatform.dataSources[0].uri, 'file://a.avi');
      });

      test('successful initialize on controller with error clears error',
          () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        fakeVideoPlayerPlatform.forceInitError = true;
        await controller.initialize().catchError((dynamic e) {});
        expect(controller.value.hasError, equals(true));
        fakeVideoPlayerPlatform.forceInitError = false;
        await controller.initialize();
        expect(controller.value.hasError, equals(false));
      });
    });

    test('contentUri', () async {
      final VideoPlayerController controller =
          VideoPlayerController.contentUri(Uri.parse('content://video'));
      await controller.initialize();

      expect(fakeVideoPlayerPlatform.dataSources[0].uri, 'content://video');
    });

    test('dispose', () async {
      final VideoPlayerController controller = VideoPlayerController.network(
        'https://127.0.0.1',
      );
      expect(
          controller.textureId, VideoPlayerController.kUninitializedTextureId);
      expect(await controller.position, Duration.zero);
      await controller.initialize();

      await controller.dispose();

      expect(controller.textureId, 0);
      expect(await controller.position, isNull);
    });

    test('calling dispose() on disposed controller does not throw', () async {
      final VideoPlayerController controller = VideoPlayerController.network(
        'https://127.0.0.1',
      );

      await controller.initialize();
      await controller.dispose();

      expect(() async => await controller.dispose(), returnsNormally);
    });

    test('play', () async {
      final VideoPlayerController controller = VideoPlayerController.network(
        'https://127.0.0.1',
      );
      await controller.initialize();
      expect(controller.value.isPlaying, isFalse);
      await controller.play();

      expect(controller.value.isPlaying, isTrue);

      // The two last calls will be "play" and then "setPlaybackSpeed". The
      // reason for this is that "play" calls "setPlaybackSpeed" internally.
      expect(
          fakeVideoPlayerPlatform
              .calls[fakeVideoPlayerPlatform.calls.length - 2],
          'play');
      expect(fakeVideoPlayerPlatform.calls.last, 'setPlaybackSpeed');
    });

    test('play before initialized does not call platform', () async {
      final VideoPlayerController controller = VideoPlayerController.network(
        'https://127.0.0.1',
      );
      expect(controller.value.isInitialized, isFalse);

      await controller.play();

      expect(fakeVideoPlayerPlatform.calls, isEmpty);
    });

    test('play restarts from beginning if video is at end', () async {
      final VideoPlayerController controller = VideoPlayerController.network(
        'https://127.0.0.1',
      );
      await controller.initialize();
      const Duration nonzeroDuration = Duration(milliseconds: 100);
      controller.value = controller.value.copyWith(duration: nonzeroDuration);
      await controller.seekTo(nonzeroDuration);
      expect(controller.value.isPlaying, isFalse);
      expect(controller.value.position, nonzeroDuration);

      await controller.play();

      expect(controller.value.isPlaying, isTrue);
      expect(controller.value.position, Duration.zero);
    });

    test('setLooping', () async {
      final VideoPlayerController controller = VideoPlayerController.network(
        'https://127.0.0.1',
      );
      await controller.initialize();
      expect(controller.value.isLooping, isFalse);
      await controller.setLooping(true);

      expect(controller.value.isLooping, isTrue);
    });

    test('pause', () async {
      final VideoPlayerController controller = VideoPlayerController.network(
        'https://127.0.0.1',
      );
      await controller.initialize();
      await controller.play();
      expect(controller.value.isPlaying, isTrue);

      await controller.pause();

      expect(controller.value.isPlaying, isFalse);
      expect(fakeVideoPlayerPlatform.calls.last, 'pause');
    });

    group('seekTo', () {
      test('works', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        expect(await controller.position, Duration.zero);

        await controller.seekTo(const Duration(milliseconds: 500));

        expect(await controller.position, const Duration(milliseconds: 500));
      });

      test('before initialized does not call platform', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        expect(controller.value.isInitialized, isFalse);

        await controller.seekTo(const Duration(milliseconds: 500));

        expect(fakeVideoPlayerPlatform.calls, isEmpty);
      });

      test('clamps values that are too high or low', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        expect(await controller.position, Duration.zero);

        await controller.seekTo(const Duration(seconds: 100));
        expect(await controller.position, const Duration(seconds: 1));

        await controller.seekTo(const Duration(seconds: -100));
        expect(await controller.position, Duration.zero);
      });
    });

    group('setVolume', () {
      test('works', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        expect(controller.value.volume, 1.0);

        const double volume = 0.5;
        await controller.setVolume(volume);

        expect(controller.value.volume, volume);
      });

      test('clamps values that are too high or low', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        expect(controller.value.volume, 1.0);

        await controller.setVolume(-1);
        expect(controller.value.volume, 0.0);

        await controller.setVolume(11);
        expect(controller.value.volume, 1.0);
      });
    });

    group('setPlaybackSpeed', () {
      test('works', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        expect(controller.value.playbackSpeed, 1.0);

        const double speed = 1.5;
        await controller.setPlaybackSpeed(speed);

        expect(controller.value.playbackSpeed, speed);
      });

      test('rejects negative values', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        expect(controller.value.playbackSpeed, 1.0);

        expect(() => controller.setPlaybackSpeed(-1), throwsArgumentError);
      });
    });

    group('scrubbing', () {
      testWidgets('restarts on release if already playing',
          (WidgetTester tester) async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        final VideoProgressIndicator progressWidget =
            VideoProgressIndicator(controller, allowScrubbing: true);

        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: progressWidget,
        ));

        await controller.play();
        expect(controller.value.isPlaying, isTrue);

        final Rect progressRect = tester.getRect(find.byWidget(progressWidget));
        await tester.dragFrom(progressRect.center, const Offset(1.0, 0.0));
        await tester.pumpAndSettle();

        expect(controller.value.position, lessThan(controller.value.duration));
        expect(controller.value.isPlaying, isTrue);

        await controller.pause();
      });

      testWidgets('does not restart when dragging to end',
          (WidgetTester tester) async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        final VideoProgressIndicator progressWidget =
            VideoProgressIndicator(controller, allowScrubbing: true);

        await tester.pumpWidget(Directionality(
          textDirection: TextDirection.ltr,
          child: progressWidget,
        ));

        await controller.play();
        expect(controller.value.isPlaying, isTrue);

        final Rect progressRect = tester.getRect(find.byWidget(progressWidget));
        await tester.dragFrom(progressRect.center, progressRect.centerRight);
        await tester.pumpAndSettle();

        expect(controller.value.position, controller.value.duration);
        expect(controller.value.isPlaying, isFalse);
      });
    });

    group('caption', () {
      test('works when seeking', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
          closedCaptionFile: _loadClosedCaption(),
        );

        await controller.initialize();
        expect(controller.value.position, Duration.zero);
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 100));
        expect(controller.value.caption.text, 'one');

        await controller.seekTo(const Duration(milliseconds: 250));
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 300));
        expect(controller.value.caption.text, 'two');

        await controller.seekTo(const Duration(milliseconds: 301));
        expect(controller.value.caption.text, 'two');

        await controller.seekTo(const Duration(milliseconds: 500));
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 300));
        expect(controller.value.caption.text, 'two');

        await controller.seekTo(const Duration(milliseconds: 301));
        expect(controller.value.caption.text, 'two');
      });

      test('works when seeking with captionOffset positive', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
          closedCaptionFile: _loadClosedCaption(),
        );

        await controller.initialize();
        controller.setCaptionOffset(const Duration(milliseconds: 100));
        expect(controller.value.position, Duration.zero);
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 100));
        expect(controller.value.caption.text, 'one');

        await controller.seekTo(const Duration(milliseconds: 101));
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 250));
        expect(controller.value.caption.text, 'two');

        await controller.seekTo(const Duration(milliseconds: 300));
        expect(controller.value.caption.text, 'two');

        await controller.seekTo(const Duration(milliseconds: 301));
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 500));
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 300));
        expect(controller.value.caption.text, 'two');

        await controller.seekTo(const Duration(milliseconds: 301));
        expect(controller.value.caption.text, '');
      });

      test('works when seeking with captionOffset negative', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
          closedCaptionFile: _loadClosedCaption(),
        );

        await controller.initialize();
        controller.setCaptionOffset(const Duration(milliseconds: -100));
        expect(controller.value.position, Duration.zero);
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 100));
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 200));
        expect(controller.value.caption.text, 'one');

        await controller.seekTo(const Duration(milliseconds: 250));
        expect(controller.value.caption.text, 'one');

        await controller.seekTo(const Duration(milliseconds: 300));
        expect(controller.value.caption.text, 'one');

        await controller.seekTo(const Duration(milliseconds: 301));
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 400));
        expect(controller.value.caption.text, 'two');

        await controller.seekTo(const Duration(milliseconds: 500));
        expect(controller.value.caption.text, 'two');

        await controller.seekTo(const Duration(milliseconds: 600));
        expect(controller.value.caption.text, '');

        await controller.seekTo(const Duration(milliseconds: 300));
        expect(controller.value.caption.text, 'one');
      });

      test('setClosedCaptionFile loads caption file', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );

        await controller.initialize();
        expect(controller.closedCaptionFile, null);

        await controller.setClosedCaptionFile(_loadClosedCaption());
        expect(
          (await controller.closedCaptionFile)!.captions,
          (await _loadClosedCaption()).captions,
        );
      });

      test('setClosedCaptionFile removes/changes caption file', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
          closedCaptionFile: _loadClosedCaption(),
        );

        await controller.initialize();
        expect(
          (await controller.closedCaptionFile)!.captions,
          (await _loadClosedCaption()).captions,
        );

        await controller.setClosedCaptionFile(null);
        expect(controller.closedCaptionFile, null);
      });
    });

    group('Platform callbacks', () {
      testWidgets('playing completed', (WidgetTester tester) async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        const Duration nonzeroDuration = Duration(milliseconds: 100);
        controller.value = controller.value.copyWith(duration: nonzeroDuration);
        expect(controller.value.isPlaying, isFalse);
        await controller.play();
        expect(controller.value.isPlaying, isTrue);
        final StreamController<VideoEvent> fakeVideoEventStream =
            fakeVideoPlayerPlatform.streams[controller.textureId]!;

        fakeVideoEventStream
            .add(VideoEvent(eventType: VideoEventType.completed));
        await tester.pumpAndSettle();

        expect(controller.value.isPlaying, isFalse);
        expect(controller.value.position, nonzeroDuration);
      });

      testWidgets('buffering status', (WidgetTester tester) async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        expect(controller.value.isBuffering, false);
        expect(controller.value.buffered, isEmpty);
        final StreamController<VideoEvent> fakeVideoEventStream =
            fakeVideoPlayerPlatform.streams[controller.textureId]!;

        fakeVideoEventStream
            .add(VideoEvent(eventType: VideoEventType.bufferingStart));
        await tester.pumpAndSettle();
        expect(controller.value.isBuffering, isTrue);

        const Duration bufferStart = Duration.zero;
        const Duration bufferEnd = Duration(milliseconds: 500);
        fakeVideoEventStream.add(VideoEvent(
            eventType: VideoEventType.bufferingUpdate,
            buffered: <DurationRange>[
              DurationRange(bufferStart, bufferEnd),
            ]));
        await tester.pumpAndSettle();
        expect(controller.value.isBuffering, isTrue);
        expect(controller.value.buffered.length, 1);
        expect(controller.value.buffered[0].toString(),
            DurationRange(bufferStart, bufferEnd).toString());

        fakeVideoEventStream
            .add(VideoEvent(eventType: VideoEventType.bufferingEnd));
        await tester.pumpAndSettle();
        expect(controller.value.isBuffering, isFalse);
      });

      test('native playback state updates isPlaying', () async {
        final VideoPlayerController controller = VideoPlayerController.network(
          'https://127.0.0.1',
        );
        await controller.initialize();
        final StreamController<VideoEvent> fakeVideoEventStream =
            fakeVideoPlayerPlatform.streams[controller.textureId]!;

        controller.value = controller.value.copyWith(isPlaying: true);
        fakeVideoEventStream.add(VideoEvent(
          eventType: VideoEventType.isPlayingStateUpdate,
          isPlaying: false,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(controller.value.isPlaying, isFalse);

        fakeVideoEventStream.add(VideoEvent(
          eventType: VideoEventType.isPlayingStateUpdate,
          isPlaying: true,
        ));
        await Future<void>.delayed(Duration.zero);

        expect(controller.value.isPlaying, isTrue);
        await controller.dispose();
      });
    });
  });

  group('DurationRange', () {
    test('uses given values', () {
      const Duration start = Duration(seconds: 2);
      const Duration end = Duration(seconds: 8);

      final DurationRange range = DurationRange(start, end);

      expect(range.start, start);
      expect(range.end, end);
      expect(range.toString(), contains('start: $start, end: $end'));
    });

    test('calculates fractions', () {
      const Duration start = Duration(seconds: 2);
      const Duration end = Duration(seconds: 8);
      const Duration total = Duration(seconds: 10);

      final DurationRange range = DurationRange(start, end);

      expect(range.startFraction(total), .2);
      expect(range.endFraction(total), .8);
    });
  });

  group('VideoPlayerValue', () {
    test('uninitialized()', () {
      final VideoPlayerValue uninitialized = VideoPlayerValue.uninitialized();

      expect(uninitialized.duration, equals(Duration.zero));
      expect(uninitialized.position, equals(Duration.zero));
      expect(uninitialized.caption, equals(Caption.none));
      expect(uninitialized.captionOffset, equals(Duration.zero));
      expect(uninitialized.buffered, isEmpty);
      expect(uninitialized.isPlaying, isFalse);
      expect(uninitialized.isLooping, isFalse);
      expect(uninitialized.isBuffering, isFalse);
      expect(uninitialized.volume, 1.0);
      expect(uninitialized.playbackSpeed, 1.0);
      expect(uninitialized.errorDescription, isNull);
      expect(uninitialized.size, equals(Size.zero));
      expect(uninitialized.isInitialized, isFalse);
      expect(uninitialized.hasError, isFalse);
      expect(uninitialized.aspectRatio, 1.0);
    });

    test('erroneous()', () {
      const String errorMessage = 'foo';
      final VideoPlayerValue error = VideoPlayerValue.erroneous(errorMessage);

      expect(error.duration, equals(Duration.zero));
      expect(error.position, equals(Duration.zero));
      expect(error.caption, equals(Caption.none));
      expect(error.captionOffset, equals(Duration.zero));
      expect(error.buffered, isEmpty);
      expect(error.isPlaying, isFalse);
      expect(error.isLooping, isFalse);
      expect(error.isBuffering, isFalse);
      expect(error.volume, 1.0);
      expect(error.playbackSpeed, 1.0);
      expect(error.errorDescription, errorMessage);
      expect(error.size, equals(Size.zero));
      expect(error.isInitialized, isFalse);
      expect(error.hasError, isTrue);
      expect(error.aspectRatio, 1.0);
    });

    test('toString()', () {
      const Duration duration = Duration(seconds: 5);
      const Size size = Size(400, 300);
      const Duration position = Duration(seconds: 1);
      const Caption caption = Caption(
          text: 'foo', number: 0, start: Duration.zero, end: Duration.zero);
      const Duration captionOffset = Duration(milliseconds: 250);
      final List<DurationRange> buffered = <DurationRange>[
        DurationRange(Duration.zero, const Duration(seconds: 4))
      ];
      const bool isInitialized = true;
      const bool isPlaying = true;
      const bool isLooping = true;
      const bool isBuffering = true;
      const double volume = 0.5;
      const double playbackSpeed = 1.5;

      final VideoPlayerValue value = VideoPlayerValue(
        duration: duration,
        size: size,
        position: position,
        caption: caption,
        captionOffset: captionOffset,
        buffered: buffered,
        isInitialized: isInitialized,
        isPlaying: isPlaying,
        isLooping: isLooping,
        isBuffering: isBuffering,
        volume: volume,
        playbackSpeed: playbackSpeed,
      );

      expect(
          value.toString(),
          'VideoPlayerValue(duration: 0:00:05.000000, '
          'size: Size(400.0, 300.0), '
          'position: 0:00:01.000000, '
          'caption: Caption(number: 0, start: 0:00:00.000000, end: 0:00:00.000000, text: foo), '
          'captionOffset: 0:00:00.250000, '
          'buffered: [DurationRange(start: 0:00:00.000000, end: 0:00:04.000000)], '
          'isInitialized: true, '
          'isPlaying: true, '
          'isLooping: true, '
          'isBuffering: true, '
          'volume: 0.5, '
          'playbackSpeed: 1.5, '
          'errorDescription: null)');
    });

    group('copyWith()', () {
      test('exact copy', () {
        final VideoPlayerValue original = VideoPlayerValue.uninitialized();
        final VideoPlayerValue exactCopy = original.copyWith();

        expect(exactCopy.toString(), original.toString());
      });
      test('errorDescription is not persisted when copy with null', () {
        final VideoPlayerValue original = VideoPlayerValue.erroneous('error');
        final VideoPlayerValue copy = original.copyWith(errorDescription: null);

        expect(copy.errorDescription, null);
      });
      test('errorDescription is changed when copy with another error', () {
        final VideoPlayerValue original = VideoPlayerValue.erroneous('error');
        final VideoPlayerValue copy =
            original.copyWith(errorDescription: 'new error');

        expect(copy.errorDescription, 'new error');
      });
      test('errorDescription is changed when copy with error', () {
        final VideoPlayerValue original = VideoPlayerValue.uninitialized();
        final VideoPlayerValue copy =
            original.copyWith(errorDescription: 'new error');

        expect(copy.errorDescription, 'new error');
      });
    });

    group('aspectRatio', () {
      test('640x480 -> 4:3', () {
        final VideoPlayerValue value = VideoPlayerValue(
          isInitialized: true,
          size: const Size(640, 480),
          duration: const Duration(seconds: 1),
        );
        expect(value.aspectRatio, 4 / 3);
      });

      test('no size -> 1.0', () {
        final VideoPlayerValue value = VideoPlayerValue(
          isInitialized: true,
          duration: const Duration(seconds: 1),
        );
        expect(value.aspectRatio, 1.0);
      });

      test('height = 0 -> 1.0', () {
        final VideoPlayerValue value = VideoPlayerValue(
          isInitialized: true,
          size: const Size(640, 0),
          duration: const Duration(seconds: 1),
        );
        expect(value.aspectRatio, 1.0);
      });

      test('width = 0 -> 1.0', () {
        final VideoPlayerValue value = VideoPlayerValue(
          isInitialized: true,
          size: const Size(0, 480),
          duration: const Duration(seconds: 1),
        );
        expect(value.aspectRatio, 1.0);
      });

      test('negative aspect ratio -> 1.0', () {
        final VideoPlayerValue value = VideoPlayerValue(
          isInitialized: true,
          size: const Size(640, -480),
          duration: const Duration(seconds: 1),
        );
        expect(value.aspectRatio, 1.0);
      });
    });
  });

  group('VideoPlayerOptions', () {
    late FakeVideoPlayerPlatform fakeVideoPlayerPlatform;

    setUp(() {
      fakeVideoPlayerPlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakeVideoPlayerPlatform;
    });

    test('setMixWithOthers', () async {
      final VideoPlayerController controller = VideoPlayerController.file(
          File(''),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true));
      await controller.initialize();
      expect(controller.videoPlayerOptions!.mixWithOthers, true);
    });

    test('true allowBackgroundPlayback continues playback', () async {
      final VideoPlayerController controller = VideoPlayerController.file(
        File(''),
        videoPlayerOptions: VideoPlayerOptions(
          allowBackgroundPlayback: true,
        ),
      );
      await controller.initialize();
      await controller.play();
      _verifyPlayStateRespondsToLifecycle(
        controller,
        shouldPlayInBackground: true,
      );
    });

    test('false allowBackgroundPlayback pauses playback', () async {
      final VideoPlayerController controller = VideoPlayerController.file(
        File(''),
        videoPlayerOptions: VideoPlayerOptions(),
      );
      await controller.initialize();
      await controller.play();
      _verifyPlayStateRespondsToLifecycle(
        controller,
        shouldPlayInBackground: false,
      );
    });
  });

  group('setMaxVideoResolution', () {
    late FakeVideoPlayerPlatform fakeVideoPlayerPlatform;

    setUp(() {
      fakeVideoPlayerPlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakeVideoPlayerPlatform;
    });

    test('forwards sanitized resolution', () async {
      final VideoPlayerController controller = VideoPlayerController.file(File(''));
      await controller.initialize();
      await controller.setMaxVideoResolution(1280, 720);
      expect(fakeVideoPlayerPlatform.calls.contains('setMaxVideoResolution'), isTrue);
      expect(fakeVideoPlayerPlatform.lastMaxVideoWidth, 1280);
      expect(fakeVideoPlayerPlatform.lastMaxVideoHeight, 720);
      await controller.dispose();
    });

    test('null resolution resets limit', () async {
      final VideoPlayerController controller = VideoPlayerController.file(File(''));
      await controller.initialize();
      await controller.setMaxVideoResolution(null, null);
      expect(fakeVideoPlayerPlatform.lastMaxVideoWidth, 0);
      expect(fakeVideoPlayerPlatform.lastMaxVideoHeight, 0);
      await controller.dispose();
    });
  });

  group('stopPictureInPicture', () {
    late FakeVideoPlayerPlatform fakeVideoPlayerPlatform;

    setUp(() {
      fakeVideoPlayerPlatform = FakeVideoPlayerPlatform();
      VideoPlayerPlatform.instance = fakeVideoPlayerPlatform;
    });

    test('forwards the current PiP source rect', () async {
      final VideoPlayerController controller =
          VideoPlayerController.file(File(''));
      const Rect sourceRect = Rect.fromLTWH(10, 20, 320, 180);
      await controller.initialize();
      controller.addPipSourceRectProvider(() => sourceRect);

      await controller.stopPictureInPicture();

      expect(fakeVideoPlayerPlatform.lastPipSourceRect, sourceRect);
      await controller.dispose();
    });

    test('supports stopping without a PiP source rect', () async {
      final VideoPlayerController controller =
          VideoPlayerController.file(File(''));
      await controller.initialize();

      await controller.stopPictureInPicture();

      expect(fakeVideoPlayerPlatform.lastPipSourceRect, isNull);
      await controller.dispose();
    });
  });

  test('VideoProgressColors', () {
    const Color playedColor = Color.fromRGBO(0, 0, 255, 0.75);
    const Color bufferedColor = Color.fromRGBO(0, 255, 0, 0.5);
    const Color backgroundColor = Color.fromRGBO(255, 255, 0, 0.25);

    const VideoProgressColors colors = VideoProgressColors(
        playedColor: playedColor,
        bufferedColor: bufferedColor,
        backgroundColor: backgroundColor);

    expect(colors.playedColor, playedColor);
    expect(colors.bufferedColor, bufferedColor);
    expect(colors.backgroundColor, backgroundColor);
  });
}

/// 詳細タブ (スクロールする ListView の先頭に映像) と、他のタブを IndexedStack で
/// 並べ、詳細タブ以外の表示中、または映像がスクロールで見切れた時に
/// アプリ内 PiP を出すテスト用ハーネス。アプリのレース詳細画面の構成を再現する。
class _RaceTabsHarness extends StatefulWidget {
  const _RaceTabsHarness({Key? key, required this.controller})
      : super(key: key);

  final VideoPlayerController controller;

  @override
  State<_RaceTabsHarness> createState() => _RaceTabsHarnessState();
}

class _RaceTabsHarnessState extends State<_RaceTabsHarness> {
  static const double _videoHeight = 180;

  final ScrollController _scrollController = ScrollController();
  // アプリ内 PiP は同一インスタンスを使い回し、詳細側だけが rebuild される状況にする。
  late final Widget _pipPlayer = VideoPlayer(widget.controller);
  int _tabIndex = 0;
  bool _isScrolledOut = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final bool isScrolledOut = _scrollController.offset > _videoHeight;
    if (isScrolledOut != _isScrolledOut) {
      setState(() {
        _isScrolledOut = isScrolledOut;
      });
    }
  }

  void selectTab(int index) {
    setState(() {
      _tabIndex = index;
    });
  }

  void scrollTo(double offset) {
    _scrollController.jumpTo(offset);
  }

  /// 状態を変えずに再 build する。詳細側の VideoPlayer だけが更新される。
  void rebuild() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final bool isPipVisible = _tabIndex != 0 || _isScrolledOut;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 800,
          height: 600,
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned.fill(
                child: IndexedStack(
                  index: _tabIndex,
                  children: <Widget>[
                    ListView(
                      controller: _scrollController,
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topLeft,
                          child: SizedBox(
                            width: 320,
                            height: _videoHeight,
                            child: VideoPlayer(widget.controller),
                          ),
                        ),
                        const SizedBox(height: 3000),
                      ],
                    ),
                    const SizedBox.expand(),
                    const SizedBox.expand(),
                  ],
                ),
              ),
              if (isPipVisible)
                Positioned(
                  right: 16,
                  bottom: 16,
                  width: 160,
                  height: 90,
                  child: _pipPlayer,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  Completer<bool> initialized = Completer<bool>();
  List<String> calls = <String>[];
  List<DataSource> dataSources = <DataSource>[];
  final Map<int, StreamController<VideoEvent>> streams =
      <int, StreamController<VideoEvent>>{};
  bool forceInitError = false;
  int nextTextureId = 0;
  final Map<int, Duration> _positions = <int, Duration>{};
  int? lastMaxVideoWidth;
  int? lastMaxVideoHeight;
  Rect? lastPipSourceRect;

  @override
  Future<int?> create(DataSource dataSource) async {
    calls.add('create');
    final StreamController<VideoEvent> stream = StreamController<VideoEvent>();
    streams[nextTextureId] = stream;
    if (forceInitError) {
      stream.addError(PlatformException(
          code: 'VideoError', message: 'Video player had error XYZ'));
    } else {
      stream.add(VideoEvent(
          eventType: VideoEventType.initialized,
          size: const Size(100, 100),
          duration: const Duration(seconds: 1)));
    }
    dataSources.add(dataSource);
    return nextTextureId++;
  }

  @override
  Future<void> dispose(int textureId) async {
    calls.add('dispose');
  }

  @override
  Future<void> init() async {
    calls.add('init');
    initialized.complete(true);
  }

  @override
  Stream<VideoEvent> videoEventsFor(int textureId) {
    return streams[textureId]!.stream;
  }

  @override
  Future<void> pause(int textureId) async {
    calls.add('pause');
  }

  @override
  Future<void> play(int textureId) async {
    calls.add('play');
  }

  @override
  Future<Duration> getPosition(int textureId) async {
    calls.add('position');
    return _positions[textureId] ?? Duration.zero;
  }

  @override
  Future<void> seekTo(int textureId, Duration position) async {
    calls.add('seekTo');
    _positions[textureId] = position;
  }

  @override
  Future<void> setLooping(int textureId, bool looping) async {
    calls.add('setLooping');
  }

  @override
  Future<void> setVolume(int textureId, double volume) async {
    calls.add('setVolume');
  }

  @override
  Future<void> setPlaybackSpeed(int textureId, double speed) async {
    calls.add('setPlaybackSpeed');
  }

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {
    calls.add('setMixWithOthers');
  }

  @override
  Future<void> setMaxVideoResolution(int textureId, int? width, int? height) async {
    calls.add('setMaxVideoResolution');
    lastMaxVideoWidth = width;
    lastMaxVideoHeight = height;
  }

  @override
  Future<void> stopPictureInPicture(int textureId, {Rect? sourceRect}) async {
    calls.add('stopPictureInPicture');
    lastPipSourceRect = sourceRect;
  }

  @override
  Widget buildView(int textureId) {
    return Texture(textureId: textureId);
  }
}

/// This allows a value of type T or T? to be treated as a value of type T?.
///
/// We use this so that APIs that have become non-nullable can still be used
/// with `!` and `?` on the stable branch.
T? _ambiguate<T>(T? value) => value;
