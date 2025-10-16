import 'package:example/sample_screen.dart';
import 'package:flutter_svgaplayer/flutter_svgaplayer.dart';
import 'package:flutter/cupertino.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return CupertinoApp(home: HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? svgaUrl;

  final samples = const <String>[
    "assets/angel.svga",
    "assets/pin_jump.svga",
    "assets/audio_biling.svga",
    "assets/lion.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/EmptyState.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/HamburgerArrow.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/PinJump.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/TwitterHeart.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/Walkthrough.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/kingset.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/halloween.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/heartbeat.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/matteBitmap.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/matteBitmap_1.x.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/matteRect.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/mutiMatte.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/posche.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/rose.svga",
    "https://cdn.jsdelivr.net/gh/svga/SVGA-Samples@master/Rocket.svga",
  ].map((e) => [e.split('/').last, e]).toList(growable: false);

  /// Navigate to the [SampleScreen] showing the animation at the given
  /// [sample] URL.
  ///
  /// The [sample] is a list of 2 elements, where the first is the display name
  /// of the sample, and the second is the URL of the animation.
  ///
  /// The [dynamicCallback] parameter of [SampleScreen] is set to the value
  /// in [dynamicSamples] for the given [sample] name, or null if there is no
  /// entry in that map.
  void _goToSample(BuildContext context, List<String> sample) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (context) => SampleScreen(
          name: sample.first,
          image: sample.last,
          dynamicCallback: dynamicSamples[sample.first],
        ),
      ),
    );
  }

  final dynamicSamples = <String, void Function(MovieEntity entity)>{
    "kingset.svga": (entity) => entity.dynamicItem
      ..setText(
        TextPainter(
          text: TextSpan(
            text: "Hello, World!",
            style: TextStyle(
              fontSize: 28,
              color: CupertinoColors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        "banner",
      )
      ..setImageWithUrl(
        "https://github.com/PonyCui/resources/blob/master/svga_replace_avatar.png?raw=true",
        "99",
      )
      ..setDynamicDrawer((canvas, frameIndex) {
        canvas.drawRect(
          Rect.fromLTWH(0, 0, 88, 88),
          Paint()..color = CupertinoColors.systemRed,
        ); // draw by yourself.
      }, "banner"),
  };

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('SVGA Flutter Samples'),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: samples.length,

          itemBuilder: (context, index) {
            return CupertinoButton(
              onPressed: () => _goToSample(context, samples[index]),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        samples[index].first,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                  Text(
                    samples[index].last,
                    style: TextStyle(
                      fontSize: 12,
                      color: CupertinoColors.white,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
