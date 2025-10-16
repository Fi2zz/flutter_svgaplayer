import 'package:flutter/widgets.dart';
import 'proto/svga.pb.dart';
import 'controller.dart';
import 'painter.dart';

/// Typedef for a function that returns a loading spinner widget
typedef LoadingSpinner = Widget Function();

/// A Flutter widget for playing SVGA animations
///
/// SVGAPlayer is a StatefulWidget that can play SVGA animations from a URL.
/// It provides various customization options including fit modes, loop counts,
/// custom loading spinners, and performance optimizations.
class SVGAPlayer extends StatefulWidget {
  /// Optional controller for manual animation control
  /// If null, the player will create its own controller and auto-play
  final SVGAController? controller;

  /// How the animation should be inscribed into the available space
  /// Defaults to BoxFit.contain
  final BoxFit fit;

  /// Whether to clear the canvas after animation stops
  /// Defaults to true for better performance
  final bool clearsAfterStop;

  /// URL of the SVGA file to load and play
  final String? url;

  /// Custom loading spinner widget function
  /// Called while the SVGA file is being loaded
  final LoadingSpinner? loadingSpinner;
  final bool? showLoadingSpinner;

  /// Callback function called when the SVGA file is loaded
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

  /// Number of times to loop the animation
  /// 0 means infinite loop, null means play once
  final int? loopCount;

  /// If `null`, the viewbox size of [MovieEntity] will be use.
  ///
  /// Defaults to null.
  final Size? size;

  /// Creates an SVGAPlayer widget
  ///
  /// [url] - The URL of the SVGA file to play
  /// [controller] - Optional controller for manual control
  /// [fit] - How to fit the animation in the available space
  /// [filterQuality] - Quality of image filtering
  /// [clipRect] - Whether to clip drawing to canvas bounds
  /// [clearsAfterStop] - Whether to clear canvas after animation stops
  /// [size] - Fixed size for the player widget
  /// [loopCount] - Number of loops (0 for infinite)
  /// [loadingSpinner] - Custom loading widget
  /// [onLoaded] - Callback when animation is loaded
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
    this.showLoadingSpinner = true,
    this.onLoaded,
  });

  @override
  State<StatefulWidget> createState() => _SVGAPlayerState();
}

/// Private state class for SVGAPlayer
///
/// Manages the lifecycle of SVGA animation playback including loading,
/// controller management, and widget rebuilding.
class _SVGAPlayerState extends State<SVGAPlayer> with TickerProviderStateMixin {
  /// The controller used for animation playback
  late SVGAController _controller;

  /// Whether the player should auto-play (when no external controller is provided)
  bool get _autoplable => widget.controller == null;

  /// Whether the SVGA file has been loaded
  bool _loaded = false;

  /// Loads the SVGA file from the provided URL
  ///
  /// Throws an exception if no URL is provided when auto-loading is enabled.
  Future<void> _load() async {
    assert(
      widget.controller != null || widget.url != null,
      'either controller or url must be set',
    );
    bool autoplable = widget.url != null && _autoplable;
    if (!autoplable) return;
    _controller.load(widget.url!).then((value) => _autoplay());
  }

  int? get _loopCount {
    if (widget.loopCount == null) return null;

    final loopCount = widget.loopCount!;

    if (loopCount <= 0) return null;
    return loopCount;
  }

  /// Automatically starts playing the animation after loading
  ///
  /// Only plays if auto-play is enabled and the controller is loaded.
  _autoplay() {
    if (_controller.loaded == false) return;
    _controller.repeat(count: _loopCount);
  }

  @override
  void initState() {
    super.initState();
    _initController();
    _load();
  }

  /// Handles the loaded state change and triggers widget rebuild
  ///
  /// [loaded] - The new loaded state
  _handleLoaded(bool loaded) {
    // to trigger rebuild
    if (loaded != _loaded) {
      widget.onLoaded?.call();
      setState(() => _loaded = loaded);
    }
  }

  /// Initializes the animation controller and sets up listeners
  ///
  /// [reset] - Whether to reset the existing controller before initialization
  _initController({bool reset = false}) {
    if (reset) _resetController();
    _controller = widget.controller ?? SVGAController(vsync: this);
    _controller.attach();
    _controller.addListener(_handleChange);
    _controller.addLoadListener(_handleLoaded);
    _controller.addStatusListener(_handleStatusChange);
  }

  /// Resets the controller by removing listeners and disposing it
  _resetController() {
    _controller.removeListener(_handleChange);
    _controller.removeStatusListener(_handleStatusChange);
    _controller.removeLoadListener(_handleLoaded);
    _controller.dispose();
  }

  /// Handles animation value changes
  /// Currently empty but can be used for custom change handling
  _handleChange() {}

  @override
  void didUpdateWidget(SVGAPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload if URL changes
    if (widget.url != oldWidget.url) _load();
    // Reinitialize controller if it changes
    if (widget.controller != oldWidget.controller) {
      _initController(reset: true);
    }
  }

  /// Handles animation status changes
  ///
  /// Clears the canvas when animation completes if clearsAfterStop is enabled.
  /// [status] - The new animation status
  void _handleStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (widget.clearsAfterStop) {
        _controller.clear();
      } else {}
    }
  }

  /// Calculates the size of the player widget
  ///
  /// Returns the appropriate size based on the loaded video dimensions
  /// and any size constraints provided.
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

  /// Creates a placeholder widget to show while loading
  ///
  /// Returns either a custom loading spinner or a sized box placeholder.
  _placeholder() {
    final loadingSpinner = widget.loadingSpinner;
    final size = widget.size;
    final showLoadingSpinner = widget.showLoadingSpinner;
    if (loadingSpinner != null && showLoadingSpinner == true) {
      final spinner = loadingSpinner();
      if (size == null) return spinner;
      return SizedBox.fromSize(size: size, child: loadingSpinner());
    }
    if (_size.isEmpty) return SizedBox.shrink();
    return SizedBox.fromSize(size: size);
  }

  @override
  Widget build(BuildContext context) {
    // Show placeholder while loading
    if (_loaded == false) return _placeholder();

    // Render the SVGA animation using CustomPaint
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
