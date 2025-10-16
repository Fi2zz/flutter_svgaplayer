import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'proto/svga.pb.dart';
import 'controller.dart';

/// Creates a new path that is drawn from the segments of `source`.
///
/// Dash intervals are controled by the `dashArray` - see [CircularIntervalList]
/// for examples.
///
/// `dashOffset` specifies an initial starting point for the dashing.
///
/// Passing a `source` that is an empty path will return an empty path.
Path dashPath(
  Path source, {
  required CircularIntervalList<double> dashArray,
  DashOffset? dashOffset,
}) {
  assert(dashArray != null); // ignore: unnecessary_null_comparison
  dashOffset = dashOffset ?? const DashOffset.absolute(0.0);
  final Path dest = Path();
  for (final PathMetric metric in source.computeMetrics()) {
    double distance = dashOffset._calculate(metric.length);
    bool draw = true;
    while (distance < metric.length) {
      final double len = dashArray.next;
      if (draw) {
        dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
      }
      distance += len;
      draw = !draw;
    }
  }

  return dest;
}

/// Enum for dash offset calculation types
enum _DashOffsetType { Absolute, Percentage }

/// Specifies the starting position of a dash array on a path, either as a
/// percentage or absolute value.
///
/// The internal value will be guaranteed to not be null.
class DashOffset {
  /// Create a DashOffset that will be measured as a percentage of the length
  /// of the segment being dashed.
  ///
  /// `percentage` will be clamped between 0.0 and 1.0.
  DashOffset.percentage(double percentage)
    : _rawVal = percentage.clamp(0.0, 1.0),
      _dashOffsetType = _DashOffsetType.Percentage;

  /// Create a DashOffset that will be measured in terms of absolute pixels
  /// along the length of a [Path] segment.
  const DashOffset.absolute(double start)
    : _rawVal = start,
      _dashOffsetType = _DashOffsetType.Absolute;

  /// The raw value for the dash offset
  final double _rawVal;
  
  /// The type of dash offset calculation
  final _DashOffsetType _dashOffsetType;

  /// Calculates the actual dash offset based on the path length
  /// 
  /// [length] - The length of the path segment
  /// Returns the calculated offset value
  double _calculate(double length) {
    return _dashOffsetType == _DashOffsetType.Absolute
        ? _rawVal
        : length * _rawVal;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is DashOffset &&
        other._rawVal == _rawVal &&
        other._dashOffsetType == _dashOffsetType;
  }

  @override
  int get hashCode => Object.hash(_rawVal, _dashOffsetType);
}

/// A circular array of dash offsets and lengths.
///
/// For example, the array `[5, 10]` would result in dashes 5 pixels long
/// followed by blank spaces 10 pixels long.  The array `[5, 10, 5]` would
/// result in a 5 pixel dash, a 10 pixel gap, a 5 pixel dash, a 5 pixel gap,
/// a 10 pixel dash, etc.
///
/// Note that this does not quite conform to an [Iterable<T>], because it does
/// not have a moveNext.
class CircularIntervalList<T> {
  /// Creates a circular interval list with the given values
  CircularIntervalList(this._vals);

  /// The list of values to cycle through
  final List<T> _vals;
  
  /// Current index in the circular list
  int _idx = 0;

  /// Gets the next value in the circular list
  /// Automatically wraps around to the beginning when reaching the end
  T get next {
    if (_idx >= _vals.length) {
      _idx = 0;
    }
    return _vals[_idx++];
  }
}

/// Custom painter for rendering SVGA animations
/// 
/// SVGAPainter is responsible for:
/// - Rendering SVGA animation frames on a canvas
/// - Handling transformations, clipping, and scaling
/// - Drawing sprites, shapes, bitmaps, and dynamic content
/// - Managing paint styles and effects
class SVGAPainter extends CustomPainter {
  /// How the animation should fit within the available space
  final BoxFit fit;
  
  /// The controller that manages the animation state
  final SVGAController controller;
  
  /// Gets the current frame index from the controller
  int get currentFrame => controller.currentFrame;
  
  /// Gets the movie entity containing animation data
  MovieEntity get videoItem => controller.videoItem!;
  
  /// Quality setting for image filtering
  final FilterQuality filterQuality;

  /// Whether to clip drawing to canvas bounds
  /// Guaranteed to draw within the canvas bounds when true
  final bool clipRect;
  
  /// Creates an SVGAPainter with the specified configuration
  /// 
  /// [controller] - The animation controller
  /// [fit] - How to fit the animation in the available space
  /// [filterQuality] - Quality of image filtering
  /// [clipRect] - Whether to clip to canvas bounds
  SVGAPainter(
    this.controller, {
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.low,
    this.clipRect = true,
  }) : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    // Handle canvas clearing request
    if (controller.canvasNeedsClear) {
      // mark cleared
      controller.canvasNeedsClear = false;
      return;
    }
    
    // Skip painting if size is empty or no video data
    if (size.isEmpty || controller.videoItem == null) return;
    
    final params = videoItem.params;
    final Size viewBoxSize = Size(params.viewBoxWidth, params.viewBoxHeight);
    if (viewBoxSize.isEmpty) return;
    
    // Save canvas state before transformations
    canvas.save();
    try {
      final canvasRect = Offset.zero & size;
      
      // Clip to canvas bounds if requested
      if (clipRect) canvas.clipRect(canvasRect);
      
      // Scale and position the animation to fit the canvas
      scaleCanvasToViewBox(canvas, canvasRect, Offset.zero & viewBoxSize);
      
      // Draw all sprites for the current frame
      drawSprites(canvas, size);
    } finally {
      // Always restore canvas state
      canvas.restore();
    }
  }

  /// Scales and positions the canvas to fit the SVGA viewbox
  /// 
  /// Applies the specified BoxFit mode to scale the animation appropriately
  /// and centers it within the available canvas space.
  /// 
  /// [canvas] - The canvas to transform
  /// [canvasRect] - The available canvas rectangle
  /// [viewBoxRect] - The SVGA animation's viewbox rectangle
  void scaleCanvasToViewBox(Canvas canvas, Rect canvasRect, Rect viewBoxRect) {
    final fittedSizes = applyBoxFit(fit, viewBoxRect.size, canvasRect.size);

    // scale viewbox size (source) to canvas size (destination)
    var sx = fittedSizes.destination.width / fittedSizes.source.width;
    var sy = fittedSizes.destination.height / fittedSizes.source.height;
    final Size scaledHalfViewBoxSize =
        Size(viewBoxRect.size.width * sx, viewBoxRect.size.height * sy) / 2.0;
    final Size halfCanvasSize = canvasRect.size / 2.0;
    
    // center align
    final Offset shift = Offset(
      halfCanvasSize.width - scaledHalfViewBoxSize.width,
      halfCanvasSize.height - scaledHalfViewBoxSize.height,
    );
    if (shift != Offset.zero) canvas.translate(shift.dx, shift.dy);
    if (sx != 1.0 && sy != 1.0) canvas.scale(sx, sy);
  }

  /// Draws all sprites for the current animation frame
  /// 
  /// Iterates through all sprites in the animation and renders them
  /// with appropriate transformations, clipping, and effects.
  /// 
  /// [canvas] - The canvas to draw on
  /// [size] - The size of the canvas
  void drawSprites(Canvas canvas, Size size) {
    for (final sprite in videoItem.sprites) {
      final imageKey = sprite.imageKey;
      // var matteKey = sprite.matteKey;
      
      // Skip hidden sprites or sprites without image keys
      if (imageKey.isEmpty ||
          videoItem.dynamicItem.dynamicHidden[imageKey] == true) {
        continue;
      }
      
      final frameItem = sprite.frames[currentFrame];
      final needTransform = frameItem.hasTransform();
      final needClip = frameItem.hasClipPath();
      
      // Apply transformation if needed
      if (needTransform) {
        canvas.save();
        canvas.transform(
          Float64List.fromList(<double>[
            frameItem.transform.a,
            frameItem.transform.b,
            0.0,
            0.0,
            frameItem.transform.c,
            frameItem.transform.d,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0,
            0.0,
            frameItem.transform.tx,
            frameItem.transform.ty,
            0.0,
            1.0,
          ]),
        );
      }
      
      // Apply clipping if needed
      if (needClip) {
        canvas.save();
        canvas.clipPath(buildDPath(frameItem.clipPath));
      }

      // Calculate frame rectangle and alpha
      final frameRect = Rect.fromLTRB(
        0,
        0,
        frameItem.layout.width,
        frameItem.layout.height,
      );
      final frameAlpha = frameItem.hasAlpha()
          ? (frameItem.alpha * 255).toInt()
          : 255;
      
      // Draw bitmap, shapes, and dynamic content
      drawBitmap(canvas, imageKey, frameRect, frameAlpha);
      drawShape(canvas, frameItem.shapes, frameAlpha);
      
      // Draw dynamic custom content if available
      final dynamicDrawer = videoItem.dynamicItem.dynamicDrawer[imageKey];
      if (dynamicDrawer != null) {
        dynamicDrawer(canvas, currentFrame);
      }
      
      // Restore canvas states
      if (needClip) {
        canvas.restore();
      }
      if (needTransform) {
        canvas.restore();
      }
    }
  }

  /// Draws a bitmap image for a sprite
  /// 
  /// Renders either a dynamic replacement image or the original cached bitmap
  /// with the specified frame rectangle and alpha transparency.
  /// 
  /// [canvas] - The canvas to draw on
  /// [imageKey] - The key identifying the image
  /// [frameRect] - The rectangle to draw the image in
  /// [alpha] - The alpha transparency value (0-255)
  void drawBitmap(Canvas canvas, String imageKey, Rect frameRect, int alpha) {
    // Get dynamic image or fallback to cached bitmap
    final bitmap =
        videoItem.dynamicItem.dynamicImages[imageKey] ??
        videoItem.bitmapCache[imageKey];
    if (bitmap == null) return;

    final bitmapPaint = Paint();
    bitmapPaint.filterQuality = filterQuality;
    // Fix bitmap aliasing issues
    bitmapPaint.isAntiAlias = true;
    bitmapPaint.color = Color.fromARGB(alpha, 0, 0, 0);

    Rect srcRect = Rect.fromLTRB(
      0,
      0,
      bitmap.width.toDouble(),
      bitmap.height.toDouble(),
    );
    Rect dstRect = frameRect;
    canvas.drawImageRect(bitmap, srcRect, dstRect, bitmapPaint);
    
    // Draw any dynamic text overlay
    drawTextOnBitmap(canvas, imageKey, frameRect, alpha);
  }

  /// Draws vector shapes for a sprite frame
  /// 
  /// Renders all shapes with their fill colors, stroke styles, and effects.
  /// Handles various stroke properties like line caps, joins, and dash patterns.
  /// 
  /// [canvas] - The canvas to draw on
  /// [shapes] - The list of shapes to draw
  /// [frameAlpha] - The frame's alpha transparency value
  void drawShape(Canvas canvas, List<ShapeEntity> shapes, int frameAlpha) {
    if (shapes.isEmpty) return;
    
    for (var shape in shapes) {
      final path = buildPath(shape);
      
      // Apply shape transformation if needed
      if (shape.hasTransform()) {
        canvas.save();
        canvas.transform(
          Float64List.fromList(<double>[
            shape.transform.a,
            shape.transform.b,
            0.0,
            0.0,
            shape.transform.c,
            shape.transform.d,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0,
            0.0,
            shape.transform.tx,
            shape.transform.ty,
            0.0,
            1.0,
          ]),
        );
      }

      // Draw fill if specified
      final fill = shape.styles.fill;
      if (fill.isInitialized()) {
        final paint = Paint();
        paint.isAntiAlias = true;
        paint.style = PaintingStyle.fill;
        paint.color = Color.fromARGB(
          (fill.a * frameAlpha).toInt(),
          (fill.r * 255).toInt(),
          (fill.g * 255).toInt(),
          (fill.b * 255).toInt(),
        );
        canvas.drawPath(path, paint);
      }
      
      // Draw stroke if specified
      final strokeWidth = shape.styles.strokeWidth;
      if (strokeWidth > 0) {
        final paint = Paint();
        paint.style = PaintingStyle.stroke;
        
        // Set stroke color if specified
        if (shape.styles.stroke.isInitialized()) {
          paint.color = Color.fromARGB(
            (shape.styles.stroke.a * frameAlpha).toInt(),
            (shape.styles.stroke.r * 255).toInt(),
            (shape.styles.stroke.g * 255).toInt(),
            (shape.styles.stroke.b * 255).toInt(),
          );
        }
        
        paint.strokeWidth = strokeWidth;
        
        // Set line cap style
        final lineCap = shape.styles.lineCap;
        switch (lineCap) {
          case ShapeEntity_ShapeStyle_LineCap.LineCap_BUTT:
            paint.strokeCap = StrokeCap.butt;
            break;
          case ShapeEntity_ShapeStyle_LineCap.LineCap_ROUND:
            paint.strokeCap = StrokeCap.round;
            break;
          case ShapeEntity_ShapeStyle_LineCap.LineCap_SQUARE:
            paint.strokeCap = StrokeCap.square;
            break;
          default:
        }
        
        // Set line join style
        final lineJoin = shape.styles.lineJoin;
        switch (lineJoin) {
          case ShapeEntity_ShapeStyle_LineJoin.LineJoin_MITER:
            paint.strokeJoin = StrokeJoin.miter;
            break;
          case ShapeEntity_ShapeStyle_LineJoin.LineJoin_ROUND:
            paint.strokeJoin = StrokeJoin.round;
            break;
          case ShapeEntity_ShapeStyle_LineJoin.LineJoin_BEVEL:
            paint.strokeJoin = StrokeJoin.bevel;
            break;
          default:
        }
        
        paint.strokeMiterLimit = shape.styles.miterLimit;
        
        // Handle dash patterns
        List<double> lineDash = [
          shape.styles.lineDashI,
          shape.styles.lineDashII,
          shape.styles.lineDashIII,
        ];
        
        if (lineDash[0] > 0 || lineDash[1] > 0) {
          // Draw dashed line
          canvas.drawPath(
            dashPath(
              path,
              dashArray: CircularIntervalList([
                lineDash[0] < 1.0 ? 1.0 : lineDash[0],
                lineDash[1] < 0.1 ? 0.1 : lineDash[1],
              ]),
              dashOffset: DashOffset.absolute(lineDash[2]),
            ),
            paint,
          );
        } else {
          // Draw solid line
          canvas.drawPath(path, paint);
        }
      }
      
      // Restore transformation if applied
      if (shape.hasTransform()) {
        canvas.restore();
      }
    }
  }

  /// Valid SVG path command characters
  static const _validMethods = 'MLHVCSQRZmlhvcsqrz';

  /// Builds a Flutter Path from a ShapeEntity
  /// 
  /// Converts SVGA shape data into Flutter Path objects for rendering.
  /// Supports different shape types: SHAPE (SVG path), ELLIPSE, and RECT.
  /// 
  /// [shape] - The shape entity to convert
  /// Returns a Flutter Path object
  Path buildPath(ShapeEntity shape) {
    final path = Path();
    
    if (shape.type == ShapeEntity_ShapeType.SHAPE) {
      // Build path from SVG path data
      final args = shape.shape;
      final argD = args.d;
      return buildDPath(argD, path: path);
    } else if (shape.type == ShapeEntity_ShapeType.ELLIPSE) {
      // Build ellipse path
      final args = shape.ellipse;
      final xv = args.x;
      final yv = args.y;
      final rxv = args.radiusX;
      final ryv = args.radiusY;
      final rect = Rect.fromLTWH(xv - rxv, yv - ryv, rxv * 2, ryv * 2);
      if (!rect.isEmpty) path.addOval(rect);
    } else if (shape.type == ShapeEntity_ShapeType.RECT) {
      // Build rectangle path
      final args = shape.rect;
      final xv = args.x;
      final yv = args.y;
      final wv = args.width;
      final hv = args.height;
      final crv = args.cornerRadius;
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(xv, yv, wv, hv),
        Radius.circular(crv),
      );
      if (!rrect.isEmpty) path.addRRect(rrect);
    }
    return path;
  }

  /// Builds a Flutter Path from SVG path data string
  /// 
  /// Parses SVG path commands and converts them to Flutter Path operations.
  /// Supports caching for performance optimization.
  /// 
  /// [argD] - The SVG path data string
  /// [path] - Optional existing path to modify
  /// Returns a Flutter Path object
  Path buildDPath(String argD, {Path? path}) {
    // Check cache first for performance
    if (videoItem.pathCache[argD] != null) {
      return videoItem.pathCache[argD]!;
    }
    
    path ??= Path();
    
    // Preprocess the path data string
    final d = argD
        .replaceAllMapped(RegExp('([a-df-zA-Z])'), (match) {
          return "|||${match.group(1)} ";
        })
        .replaceAll(RegExp(","), " ");
    
    // Current position tracking
    var currentPointX = 0.0;
    var currentPointY = 0.0;
    double? currentPointX1;
    double? currentPointY1;
    double? currentPointX2;
    double? currentPointY2;
    
    // Process each path command
    d.split("|||").forEach((segment) {
      if (segment.isEmpty) {
        return;
      }
      
      final firstLetter = segment.substring(0, 1);
      if (_validMethods.contains(firstLetter)) {
        final args = segment.substring(1).trim().split(" ");
        
        // Handle different SVG path commands
        if (firstLetter == "M") {
          // Move to absolute
          currentPointX = double.parse(args[0]);
          currentPointY = double.parse(args[1]);
          path!.moveTo(currentPointX, currentPointY);
        } else if (firstLetter == "m") {
          // Move to relative
          currentPointX += double.parse(args[0]);
          currentPointY += double.parse(args[1]);
          path!.moveTo(currentPointX, currentPointY);
        } else if (firstLetter == "L") {
          // Line to absolute
          currentPointX = double.parse(args[0]);
          currentPointY = double.parse(args[1]);
          path!.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "l") {
          // Line to relative
          currentPointX += double.parse(args[0]);
          currentPointY += double.parse(args[1]);
          path!.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "H") {
          // Horizontal line to absolute
          currentPointX = double.parse(args[0]);
          path!.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "h") {
          // Horizontal line to relative
          currentPointX += double.parse(args[0]);
          path!.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "V") {
          // Vertical line to absolute
          currentPointY = double.parse(args[0]);
          path!.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "v") {
          // Vertical line to relative
          currentPointY += double.parse(args[0]);
          path!.lineTo(currentPointX, currentPointY);
        } else if (firstLetter == "C") {
          // Cubic Bezier curve absolute
          currentPointX1 = double.parse(args[0]);
          currentPointY1 = double.parse(args[1]);
          currentPointX2 = double.parse(args[2]);
          currentPointY2 = double.parse(args[3]);
          currentPointX = double.parse(args[4]);
          currentPointY = double.parse(args[5]);
          path!.cubicTo(
            currentPointX1!,
            currentPointY1!,
            currentPointX2!,
            currentPointY2!,
            currentPointX,
            currentPointY,
          );
        } else if (firstLetter == "c") {
          // Cubic Bezier curve relative
          currentPointX1 = currentPointX + double.parse(args[0]);
          currentPointY1 = currentPointY + double.parse(args[1]);
          currentPointX2 = currentPointX + double.parse(args[2]);
          currentPointY2 = currentPointY + double.parse(args[3]);
          currentPointX += double.parse(args[4]);
          currentPointY += double.parse(args[5]);
          path!.cubicTo(
            currentPointX1!,
            currentPointY1!,
            currentPointX2!,
            currentPointY2!,
            currentPointX,
            currentPointY,
          );
        } else if (firstLetter == "S") {
          // Smooth cubic Bezier curve absolute
          if (currentPointX1 != null &&
              currentPointY1 != null &&
              currentPointX2 != null &&
              currentPointY2 != null) {
            currentPointX1 = currentPointX - currentPointX2! + currentPointX;
            currentPointY1 = currentPointY - currentPointY2! + currentPointY;
            currentPointX2 = double.parse(args[0]);
            currentPointY2 = double.parse(args[1]);
            currentPointX = double.parse(args[2]);
            currentPointY = double.parse(args[3]);
            path!.cubicTo(
              currentPointX1!,
              currentPointY1!,
              currentPointX2!,
              currentPointY2!,
              currentPointX,
              currentPointY,
            );
          } else {
            currentPointX1 = double.parse(args[0]);
            currentPointY1 = double.parse(args[1]);
            currentPointX = double.parse(args[2]);
            currentPointY = double.parse(args[3]);
            path!.quadraticBezierTo(
              currentPointX1!,
              currentPointY1!,
              currentPointX,
              currentPointY,
            );
          }
        } else if (firstLetter == "s") {
          // Smooth cubic Bezier curve relative
          if (currentPointX1 != null &&
              currentPointY1 != null &&
              currentPointX2 != null &&
              currentPointY2 != null) {
            currentPointX1 = currentPointX - currentPointX2! + currentPointX;
            currentPointY1 = currentPointY - currentPointY2! + currentPointY;
            currentPointX2 = currentPointX + double.parse(args[0]);
            currentPointY2 = currentPointY + double.parse(args[1]);
            currentPointX += double.parse(args[2]);
            currentPointY += double.parse(args[3]);
            path!.cubicTo(
              currentPointX1!,
              currentPointY1!,
              currentPointX2!,
              currentPointY2!,
              currentPointX,
              currentPointY,
            );
          } else {
            currentPointX1 = currentPointX + double.parse(args[0]);
            currentPointY1 = currentPointY + double.parse(args[1]);
            currentPointX += double.parse(args[2]);
            currentPointY += double.parse(args[3]);
            path!.quadraticBezierTo(
              currentPointX1!,
              currentPointY1!,
              currentPointX,
              currentPointY,
            );
          }
        } else if (firstLetter == "Q") {
          // Quadratic Bezier curve absolute
          currentPointX1 = double.parse(args[0]);
          currentPointY1 = double.parse(args[1]);
          currentPointX = double.parse(args[2]);
          currentPointY = double.parse(args[3]);
          path!.quadraticBezierTo(
            currentPointX1!,
            currentPointY1!,
            currentPointX,
            currentPointY,
          );
        } else if (firstLetter == "q") {
          // Quadratic Bezier curve relative
          currentPointX1 = currentPointX + double.parse(args[0]);
          currentPointY1 = currentPointY + double.parse(args[1]);
          currentPointX += double.parse(args[2]);
          currentPointY += double.parse(args[3]);
          path!.quadraticBezierTo(
            currentPointX1!,
            currentPointY1!,
            currentPointX,
            currentPointY,
          );
        } else if (firstLetter == "Z" || firstLetter == "z") {
          // Close path
          path!.close();
        }
      }
      
      // Cache the built path for performance
      videoItem.pathCache[argD] = path!;
    });
    return path;
  }

  /// Draws dynamic text overlay on a bitmap
  /// 
  /// Renders custom text content that has been set via the dynamic entity.
  /// The text is centered within the frame rectangle.
  /// 
  /// [canvas] - The canvas to draw on
  /// [imageKey] - The key identifying the sprite
  /// [frameRect] - The rectangle of the frame
  /// [frameAlpha] - The frame's alpha transparency value
  void drawTextOnBitmap(
    Canvas canvas,
    String imageKey,
    Rect frameRect,
    int frameAlpha,
  ) {
    var dynamicText = videoItem.dynamicItem.dynamicText;
    if (dynamicText.isEmpty) return;
    if (dynamicText[imageKey] == null) return;

    TextPainter? textPainter = dynamicText[imageKey];

    // Center the text within the frame rectangle
    textPainter?.paint(
      canvas,
      Offset(
        (frameRect.width - textPainter.width) / 2.0,
        (frameRect.height - textPainter.height) / 2.0,
      ),
    );
  }

  @override
  bool shouldRepaint(SVGAPainter oldDelegate) {
    // Always repaint if canvas needs clearing
    if (controller.canvasNeedsClear == true) {
      return true;
    }

    // Repaint if any relevant properties have changed
    return !(oldDelegate.controller == controller &&
        oldDelegate.controller.videoItem == controller.videoItem &&
        oldDelegate.fit == fit &&
        oldDelegate.filterQuality == filterQuality &&
        oldDelegate.clipRect == clipRect);
  }
}
