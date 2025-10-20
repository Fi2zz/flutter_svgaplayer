import 'dart:math';
import 'package:flutter/widgets.dart';
import 'decoder.dart';
import 'proto/svga.pb.dart';
import 'loader.dart';

/// SVGA animation controller that extends Flutter's AnimationController
///
/// This controller manages the lifecycle of SVGA animations, including loading,
/// playback control, and dynamic content manipulation. It provides methods to
/// load SVGA files from URLs, control animation playback, and modify dynamic
/// elements like text and images during runtime.
class SVGAController extends AnimationController {
  /// The loaded SVGA movie entity containing animation data
  MovieEntity? _videoItem;

  /// Flag indicating whether the canvas needs to be cleared on next frame
  bool canvasNeedsClear = false;

  /// Creates a new SVGA controller
  ///
  /// [vsync] is required for animation synchronization with the display refresh rate
  SVGAController({required super.vsync}) : super(duration: Duration.zero);

  /// Whether the SVGA animation has been successfully loaded
  bool loaded = false;

  /// Adds a listener that gets called when the loaded state changes
  ///
  /// [listener] function that receives the current loaded state as a boolean
  addLoadListener(Function(bool) listener) =>
      addListener(() => listener(loaded));

  /// Removes a previously added load listener
  ///
  /// [listener] the listener function to remove
  removeLoadListener(Function(bool) listener) =>
      removeListener(() => listener(loaded));

  /// Loads an SVGA animation from the specified URL
  ///
  /// [url] the network URL of the SVGA file to load
  /// Returns the loaded MovieEntity or null if loading failed
  /// Throws an exception if the loading process encounters an error
  Future<MovieEntity?> load(String url) async {
    assert(_attached, 'please set SVGAPlayer.controller to this controller');
    loaded = false;
    try {
      // Load raw bytes from the URL
      final bytes = await loader(url: url);
      // Decode the bytes into a MovieEntity
      final entity = await decoder(bytes: bytes);
      // Set the video item which will configure animation duration
      videoItem = entity;
      loaded = entity != null;
      notifyListeners();
      return entity;
    } catch (e) {
      // Re-throw the exception to allow caller to handle it
      rethrow;
    }
  }

  /// Sets dynamic text content for a specific layer
  ///
  /// [textPainter] the TextPainter containing the text to display
  /// [forKey] the layer key/name where the text should be applied
  setDynamicItemText(TextPainter textPainter, String forKey) {
    if (_videoItem == null) return;
    videoItem?.dynamicItem.setText(textPainter, forKey);
  }

  /// Sets a dynamic image from URL for a specific layer
  ///
  /// [url] the URL of the image to load and display
  /// [forKey] the layer key/name where the image should be applied
  setDynamicItemImageWithUrl(String url, String forKey) {
    if (_videoItem == null) return;
    videoItem?.dynamicItem.setImageWithUrl(url, forKey);
  }

  /// Shows or hides a specific layer
  ///
  /// [hidden] true to hide the layer, false to show it
  /// [forKey] the layer key/name to modify
  setDynamicHidden(bool hidden, String forKey) {
    if (_videoItem == null) return;
    videoItem?.dynamicItem.setHidden(hidden, forKey);
  }

  /// Sets the video item and configures animation parameters
  ///
  /// This setter automatically calculates the animation duration based on
  /// the SVGA file's frame count and FPS. It also handles cleanup of the
  /// previous video item if auto-release is enabled.
  set videoItem(MovieEntity? value) {
    assert(!isDisposed, '$this has been disposed!');
    if (isDisposed) return;

    // Stop current animation if running
    if (isAnimating) {
      stop();
    }

    // Clear canvas if no new value
    if (value == null) {
      clear();
    }

    // Dispose previous video item if auto-release is enabled
    if (_videoItem != null && _videoItem!.autorelease) {
      _videoItem!.dispose();
    }

    _videoItem = value;

    if (value != null) {
      final movieParams = value.params;

      // Validate SVGA file parameters
      assert(
        movieParams.viewBoxWidth >= 0 &&
            movieParams.viewBoxHeight >= 0 &&
            movieParams.frames >= 1,
        "Invalid SVGA file!",
      );

      int fps = movieParams.fps;
      // Avoid dividing by 0, use 20 FPS by default
      // Reference: https://github.com/svga/SVGAPlayer-Web/blob/1c5711db068a25006316f9890b11d6666d531c39/src/videoEntity.js#L51
      if (fps == 0) fps = 20;

      // Calculate total animation duration
      duration = Duration(
        milliseconds: (movieParams.frames / fps * 1000).toInt(),
      );
    } else {
      duration = Duration.zero;
    }

    // Reset animation progress after video item changed
    reset();
  }

  /// Gets the currently loaded video item
  MovieEntity? get videoItem => _videoItem;

  /// Current drawing frame index of [videoItem], returns 0 if [videoItem] is null.
  ///
  /// The frame index is calculated based on the current animation progress
  /// and is clamped between 0 and the total frame count minus 1.
  int get currentFrame {
    final videoItem = _videoItem;
    if (videoItem == null) return 0;
    return min(
      videoItem.params.frames - 1,
      max(0, (videoItem.params.frames.toDouble() * value).toInt()),
    );
  }

  /// Total frames of [videoItem], returns 0 if [videoItem] is null.
  ///
  /// This represents the total number of frames in the SVGA animation.
  int get frames {
    final videoItem = _videoItem;
    if (videoItem == null) return 0;
    return videoItem.params.frames;
  }

  /// Marks the canvas for clearing on the next frame
  ///
  /// This is useful when you want to clear the current frame display
  /// without disposing the entire animation.
  void clear() {
    canvasNeedsClear = true;
    if (!isDisposed) notifyListeners();
  }

  /// Disposes the current video item and frees its resources
  ///
  /// This method should be called when you no longer need the video item
  /// to prevent memory leaks.
  void clearVideoItem() {
    videoItem?.dispose();
  }

  /// Plays the animation forward from the specified position
  ///
  /// [from] optional starting position (0.0 to 1.0), defaults to current position
  /// Returns a TickerFuture that completes when the animation finishes
  @override
  TickerFuture forward({double? from}) {
    _checkLoaded('forward');
    return super.forward(from: from);
  }

  /// Plays the animation in reverse from the specified position
  ///
  /// [from] optional starting position (0.0 to 1.0), defaults to current position
  /// Returns a TickerFuture that completes when the animation finishes
  @override
  TickerFuture reverse({double? from}) {
    _checkLoaded('reverse');
    return super.reverse(from: from);
  }

  /// Repeats the animation with the specified parameters
  ///
  /// [min] minimum value for the animation (defaults to 0.0)
  /// [max] maximum value for the animation (defaults to 1.0)
  /// [reverse] whether to reverse the animation direction
  /// [period] duration for each cycle (defaults to the animation's duration)
  /// [count] number of times to repeat (null for infinite)
  /// Returns a TickerFuture that completes when all repetitions finish
  @override
  TickerFuture repeat({
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    int? count,
  }) {
    _checkLoaded('repeat');

    return super.repeat(
      min: min,
      max: max,
      reverse: reverse,
      period: period,
      count: count,
    );
  }

  /// Checks if the video item is loaded and throws an assertion error if not
  ///
  /// This is an internal method used to ensure the controller is in a valid
  /// state before performing animation operations.
  _checkLoaded([String? method]) {
    assert(
      _videoItem != null,
      'SVGAController.$method() called after dispose()?',
    );
    assert(
      _attached != false,
      'please set SVGAPlayer.controller to this controller',
    );
    assert(_videoItem != null, 'SVGAController.videoItem not loaded!');
  }

  /// Flag indicating whether this controller has been disposed
  bool isDisposed = false;

  /// Disposes the controller and frees all associated resources
  ///
  /// This method cleans up the video item, marks the controller as disposed,
  /// and calls the parent dispose method. After calling this method, the
  /// controller should not be used anymore.
  @override
  void dispose() {
    clearVideoItem();
    isDisposed = true;
    _attached = false;
    super.dispose();
  }

  /// Plays the animation with optional parameters
  ///
  /// [from] optional starting position (0.0 to 1.0)
  /// [reverse] whether to play in reverse direction
  /// Returns a TickerFuture that completes when the animation finishes
  TickerFuture play({double? from, bool reverse = false}) {
    _checkLoaded('play');
    return reverse ? this.reverse(from: from) : forward(from: from);
  }

  bool _attached = false;
  attach() => _attached = true;
}
