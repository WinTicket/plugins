## NEXT

* Adds Swift Package Manager support (`ios/video_player_avfoundation/Package.swift`).
  The native sources moved from `ios/Classes` to
  `ios/video_player_avfoundation/Sources/video_player_avfoundation`.
* Updates Pigeon to 29.0.4 and regenerates the Dart and Objective-C messages.
  The Pigeon channel names now include the package name.
* Raises the minimum iOS version to 13.0 and the minimum Flutter version to 3.41.0
  (the first version that provides the `FlutterFramework` Swift package).
* Fixes violations of new analysis option use_named_constants.
* Fixes avoid_redundant_argument_values lint warnings and minor typos.
* Ignores unnecessary import warnings in preparation for [upcoming Flutter changes](https://github.com/flutter/flutter/pull/106316).

## 2.3.5

* Updates references to the obsolete master branch.

## 2.3.4

* Removes unnecessary imports.
* Fixes library_private_types_in_public_api, sort_child_properties_last and use_key_in_widget_constructors
  lint warnings.

## 2.3.3

* Fix XCUITest based on the new voice over announcement for tooltips.
  See: https://github.com/flutter/flutter/pull/87684

## 2.3.2

* Applies the standardized transform for videos with different orientations.

## 2.3.1

* Renames internal method channels to avoid potential confusion with the
  default implementation's method channel.
* Updates Pigeon to 2.0.1.

## 2.3.0

* Updates Pigeon to ^1.0.16.

## 2.2.18

* Wait to initialize m3u8 videos until size is set, fixing aspect ratio.
* Adjusts test timeouts for network-dependent native tests to avoid flake.

## 2.2.17

* Splits from `video_player` as a federated implementation.
