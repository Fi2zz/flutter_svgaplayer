import 'package:flutter/widgets.dart';
import 'proto/svga.pb.dart';
import 'controller.dart';
import 'painter.dart';

typedef LoadingSpinner = Widget Function();

class SVGAPlayer extends StatefulWidget {
  final SVGAController? controller;

  final BoxFit fit;
  final bool clearsAfterStop;
  final String? url;
  final LoadingSpinner? loadingSpinner;
  final VoidCallback? onLoaded;

  /// Used to set the filterQuality of drawing the images inside SVGA.
  ///
  /// Defaults to [FilterQuality.low]
  final FilterQuality filterQuality;

  /// If `true`, the SVGA painter may draw beyond the expected canvas bounds
  /// and cause additional memory overhead.
  ///
  /// For backwards compatibility, defaults to `null`,
  /// which means allow drawing to overflow canvas bounds.
  final bool? clipRect;

  final int? loopCount;

  /// If `null`, the viewbox size of [MovieEntity] will be use.
  ///
  /// Defaults to null.
  final Size? size;
  const SVGAPlayer({
    super.key,
    this.url,
    this.controller,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.low,
    this.clipRect,
    this.clearsAfterStop = true,
    this.size,
    this.loopCount = 0,
    this.loadingSpinner,
    this.onLoaded,
  });

  @override
  State<StatefulWidget> createState() => _SVGAPlayerState();
}

class _SVGAPlayerState extends State<SVGAPlayer> with TickerProviderStateMixin {
  late SVGAController _controller;
  bool get _autoplable => widget.controller == null;
  bool _loaded = false;
  bool get _autoloadable {
    if (_autoplable) return true;
    return widget.url != null;
  }

  Future<void> _load() async {
    if (_autoloadable == false) return;
    if (widget.url == null) throw Exception('url must be set');
    await _controller.load(widget.url!);
    _autoplay();
  }

  _autoplay() {
    if (_autoplable == false) return;
    if (_controller.loaded == false) return;
    _controller.repeat(count: widget.loopCount);
  }

  @override
  void initState() {
    super.initState();
    _initController();
    _load();
  }

  _handleLoaded(bool loaded) {
    // to trigger rebuild
    if (loaded != _loaded) {
      widget.onLoaded?.call();
      setState(() => _loaded = loaded);
    }
  }

  _initController({bool reset = false}) {
    if (reset) _resetController();
    _controller = widget.controller ?? SVGAController(vsync: this);
    _controller.addListener(_handleChange);
    _controller.addLoadListener(_handleLoaded);
    _controller.addStatusListener(_handleStatusChange);
  }

  _resetController() {
    _controller.removeListener(_handleChange);
    _controller.removeStatusListener(_handleStatusChange);
    _controller.removeLoadListener(_handleLoaded);
    _controller.dispose();
  }

  _handleChange() {}
  @override
  void didUpdateWidget(SVGAPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.url != oldWidget.url) _load();
    if (widget.controller != oldWidget.controller) {
      _initController(reset: true);
    }
  }

  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (widget.clearsAfterStop) {
        _controller.clear();
      } else {}
    }
  }

  Size get _size {
    if (!_loaded) return Size.zero;
    final Size viewBoxSize;
    final video = _controller.videoItem!;
    final params = video.params;
    viewBoxSize = Size(params.viewBoxWidth, params.viewBoxHeight);
    // sugguest the size of CustomPaint
    Size size = viewBoxSize;
    if (widget.size != null) {
      return BoxConstraints.tight(widget.size!).constrain(viewBoxSize);
    }
    return size;
  }

  _placeholder() {
    final loadingSpinner = widget.loadingSpinner;
    final size = widget.size;
    if (loadingSpinner != null) {
      final spinner = loadingSpinner();
      if (size == null) return spinner;
      return SizedBox.fromSize(size: size, child: loadingSpinner());
    }
    if (_size.isEmpty) return SizedBox.shrink();
    return SizedBox.fromSize(size: size);
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded == false) return _placeholder();
    return IgnorePointer(
      child: CustomPaint(
        painter: SVGAPainter(
          // _SVGAPainter will auto repaint on _controller animating
          _controller,
          fit: widget.fit,
          filterQuality: widget.filterQuality,
          // default is allowing overflow for backward compatibility
          clipRect: widget.clipRect == false,
        ),
        size: _size,
      ),
    );
  }
}
