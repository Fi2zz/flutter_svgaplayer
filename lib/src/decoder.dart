import 'dart:ui' as ui;
import 'package:archive/archive.dart' show ZLibDecoder;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'timeline.dart';
import 'proto/svga.pb.dart';

typedef Bytes = List<int>;
const _filterKey = 'SvgaDecoder';
Bytes decodeBytes(Bytes bytes) => ZLibDecoder().decodeBytes(bytes);

Future<ui.Image?> decodeImage(
  String key,
  Uint8List bytes, {
  DebugTimeline? debugTl,
}) async {
  DebugTimeline task = DebugTimeline(
    filterKey: _filterKey,
    parent: debugTl?.task,
  );
  task.start('DecodeImage', () => {'key': key, 'length': bytes.length});
  try {
    final image = await decodeImageFromList(bytes);
    task.finish(() => {'imageSize': '${image.width}x${image.height}'});
    return image;
  } catch (e, stack) {
    task.finish(() => {'error': '$e', 'stack': '$stack'});
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

Future<MovieEntity?> decoder({required Bytes bytes}) async {
  DebugTimeline tl = DebugTimeline(filterKey: _filterKey);
  tl.start('DecodeFromBuffer', () => {'length': bytes.length});
  final buffer = decodeBytes(bytes);
  tl.instant(
    'MovieEntity.fromBuffer()',
    () => {'inflatedLength': buffer.length},
  );
  final movie = MovieEntity.fromBuffer(buffer);
  tl.instant(
    'prepareResources()',
    () => {'images': movie.images.keys.join(',')},
  );

  for (var sprite in movie.sprites) {
    List<ShapeEntity>? lastShape;
    for (var frame in sprite.frames) {
      if (frame.shapes.isNotEmpty && frame.shapes.isNotEmpty) {
        if (frame.shapes[0].type == ShapeEntity_ShapeType.KEEP &&
            lastShape != null) {
          frame.shapes = lastShape;
        } else if (frame.shapes.isNotEmpty == true) {
          lastShape = frame.shapes;
        }
      }
    }
  }
  if (movie.images.isEmpty) return Future.value(movie);
  return Future.wait(
    movie.images.entries.map((item) async {
      // result null means a decoding error occurred
      final bytes = Uint8List.fromList(item.value);
      final decoded = await decodeImage(item.key, bytes, debugTl: tl);
      if (decoded != null) {
        movie.bitmapCache[item.key] = decoded;
      }
    }),
  ).then((_) => movie).whenComplete(() => tl.finish());
}
