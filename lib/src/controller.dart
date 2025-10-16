import 'dart:math';
import 'package:flutter/widgets.dart';
import 'decoder.dart';
import 'proto/svga.pb.dart';
import 'loader.dart';

class SVGAController extends AnimationController {
  MovieEntity? _videoItem;
  late bool canvasNeedsClear = false;

  SVGAController({required super.vsync}) : super(duration: Duration.zero);

  bool loaded = false;

  addLoadListener(Function(bool) listener) =>
      addListener(() => listener(loaded));
  removeLoadListener(Function(bool) listener) =>
      removeListener(() => listener(loaded));

  Future<MovieEntity?> load(String url) async {
    loaded = false;
    try {
      final bytes = await loader(url: url);
      final entity = await decoder(bytes: bytes);
      videoItem = entity;
      loaded = entity != null;
      notifyListeners();
      return entity;
    } catch (e) {
      // notifyListeners();
      rethrow;
    }
  }

  setDynamicItemText(TextPainter textPainter, String forKey) {
    if (_videoItem == null) return;
    videoItem?.dynamicItem.setText(textPainter, forKey);
  }

  setDynamicItemImageWithUrl(String url, String forKey) {
    if (_videoItem == null) return;
    videoItem?.dynamicItem.setImageWithUrl(url, forKey);
  }

  setDynamicHidden(bool hidden, String forKey) {
    if (_videoItem == null) return;
    videoItem?.dynamicItem.setHidden(hidden, forKey);
  }

  set videoItem(MovieEntity? value) {
    assert(!isDisposed, '$this has been disposed!');
    if (isDisposed) return;
    if (isAnimating) {
      stop();
    }
    if (value == null) {
      clear();
    }
    if (_videoItem != null && _videoItem!.autorelease) {
      _videoItem!.dispose();
    }
    _videoItem = value;
    if (value != null) {
      final movieParams = value.params;
      assert(
        movieParams.viewBoxWidth >= 0 &&
            movieParams.viewBoxHeight >= 0 &&
            movieParams.frames >= 1,
        "Invalid SVGA file!",
      );
      int fps = movieParams.fps;
      // avoid dividing by 0, use 20 by default
      // see https://github.com/svga/SVGAPlayer-Web/blob/1c5711db068a25006316f9890b11d6666d531c39/src/videoEntity.js#L51
      if (fps == 0) fps = 20;
      duration = Duration(
        milliseconds: (movieParams.frames / fps * 1000).toInt(),
      );
    } else {
      duration = Duration.zero;
    }
    // reset progress after videoitem changed
    reset();
  }

  MovieEntity? get videoItem => _videoItem;

  /// Current drawing frame index of [videoItem], returns 0 if [videoItem] is null.
  int get currentFrame {
    final videoItem = _videoItem;
    if (videoItem == null) return 0;
    return min(
      videoItem.params.frames - 1,
      max(0, (videoItem.params.frames.toDouble() * value).toInt()),
    );
  }

  /// Total frames of [videoItem], returns 0 if [videoItem] is null.
  int get frames {
    final videoItem = _videoItem;
    if (videoItem == null) return 0;
    return videoItem.params.frames;
  }

  void clear() {
    canvasNeedsClear = true;
    if (!isDisposed) notifyListeners();
  }

  void clearVideoItem() {
    videoItem?.dispose();
  }

  @override
  TickerFuture forward({double? from}) {
    assert(
      _videoItem != null,
      'SVGAController.forward() called after dispose()?',
    );
    _checkLoaded();
    return super.forward(from: from);
  }

  @override
  TickerFuture reverse({double? from}) {
    assert(
      _videoItem != null,
      'SVGAController.reverse() called after dispose()?',
    );

    _checkLoaded();
    return super.reverse(from: from);
  }

  @override
  TickerFuture repeat({
    double? min,
    double? max,
    bool reverse = false,
    Duration? period,
    int? count,
  }) {
    _checkLoaded();

    return super.repeat(
      min: min,
      max: max,
      reverse: reverse,
      period: period,
      count: count,
    );
  }

  _checkLoaded() {
    assert(_videoItem != null, 'SVGAController.videoItem not loaded!');
  }

  bool isDisposed = false;
  @override
  void dispose() {
    debugPrint('controller dispose');
    clearVideoItem();
    isDisposed = true;
    super.dispose();
  }

  TickerFuture play({double? from, bool reverse = false}) {
    return reverse ? this.reverse(from: from) : forward(from: from);
  }
}
