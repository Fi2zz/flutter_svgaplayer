import 'dart:ui' as ui;
import 'package:archive/archive.dart' show ZLibDecoder;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'debug_timeline.dart';
import 'proto/svga.pb.dart';

/// Type alias for a list of bytes
typedef Bytes = List<int>;

/// Filter key used for debug timeline tracking
const _filterKey = 'SvgaDecoder';

/// Decompresses bytes using ZLib decompression
/// 
/// [bytes] - The compressed bytes to decompress
/// Returns the decompressed bytes
Bytes decodeBytes(Bytes bytes) => ZLibDecoder().decodeBytes(bytes);

/// Asynchronously decodes image bytes into a Flutter Image object
/// 
/// This function handles image decoding with error reporting and debug timeline tracking.
/// If decoding fails, it reports the error through Flutter's error reporting system.
/// 
/// [key] - Identifier for the image (used for debugging)
/// [bytes] - The image bytes to decode
/// [debugTl] - Optional debug timeline for performance tracking
/// 
/// Returns a Future that resolves to a ui.Image or null if decoding fails
Future<ui.Image?> decodeImage(
  String key,
  Uint8List bytes, {
  DebugTimeline? debugTl,
}) async {
  // Create debug timeline task for tracking image decoding performance
  DebugTimeline task = DebugTimeline(
    filterKey: _filterKey,
    parent: debugTl?.task,
  );
  task.start('DecodeImage', () => {'key': key, 'length': bytes.length});
  try {
    // Decode the image bytes into a Flutter Image object
    final image = await decodeImageFromList(bytes);
    task.finish(() => {'imageSize': '${image.width}x${image.height}'});
    return image;
  } catch (e, stack) {
    // Log the error and stack trace in debug timeline
    task.finish(() => {'error': '$e', 'stack': '$stack'});
    
    // Report error through Flutter's error reporting system in debug mode
    assert(() {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: stack,
          library: 'svgaplayer',
          context: ErrorDescription('during prepare resource'),
          informationCollector: () sync* {
            yield ErrorSummary('Decoding image failed.');
          },
        ),
      );
      return true;
    }());
    return null;
  }
}

/// Decodes SVGA file bytes into a MovieEntity object
/// 
/// This is the main decoder function that:
/// 1. Decompresses the SVGA file bytes using ZLib
/// 2. Parses the protobuf data into a MovieEntity
/// 3. Processes sprite frames and handles KEEP shape types
/// 4. Decodes all embedded images and caches them
/// 
/// [bytes] - The compressed SVGA file bytes
/// 
/// Returns a Future that resolves to a MovieEntity or null if decoding fails
Future<MovieEntity?> decoder({required Bytes bytes}) async {
  // Create debug timeline for tracking the entire decoding process
  DebugTimeline tl = DebugTimeline(filterKey: _filterKey);
  tl.start('DecodeFromBuffer', () => {'length': bytes.length});
  
  // Decompress the SVGA file bytes
  final buffer = decodeBytes(bytes);
  tl.instant(
    'MovieEntity.fromBuffer()',
    () => {'inflatedLength': buffer.length},
  );
  
  // Parse the decompressed bytes into a MovieEntity using protobuf
  final movie = MovieEntity.fromBuffer(buffer);
  tl.instant(
    'prepareResources()',
    () => {'images': movie.images.keys.join(',')},
  );

  // Process sprite frames to handle KEEP shape types
  // KEEP shapes reference the previous frame's shapes for optimization
  for (var sprite in movie.sprites) {
    List<ShapeEntity>? lastShape;
    for (var frame in sprite.frames) {
      if (frame.shapes.isNotEmpty && frame.shapes.isNotEmpty) {
        // If current frame has KEEP type, use the last frame's shapes
        if (frame.shapes[0].type == ShapeEntity_ShapeType.KEEP &&
            lastShape != null) {
          frame.shapes = lastShape;
        } else if (frame.shapes.isNotEmpty == true) {
          // Store current shapes as last shapes for future KEEP references
          lastShape = frame.shapes;
        }
      }
    }
  }
  
  // If no images to decode, return the movie entity immediately
  if (movie.images.isEmpty) return Future.value(movie);
  
  // Decode all embedded images and cache them in the movie entity
  return Future.wait(
    movie.images.entries.map((item) async {
      // result null means a decoding error occurred
      final bytes = Uint8List.fromList(item.value);
      final decoded = await decodeImage(item.key, bytes, debugTl: tl);
      if (decoded != null) {
        // Cache the decoded image in the movie entity for later use
        movie.bitmapCache[item.key] = decoded;
      }
    }),
  ).then((_) => movie).whenComplete(() => tl.finish());
}
