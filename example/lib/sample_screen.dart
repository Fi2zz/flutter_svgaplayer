import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svgaplayer/flutter_svgaplayer.dart';

class SampleScreen extends StatefulWidget {
  final String? name;
  final String image;
  final void Function(MovieEntity entity)? dynamicCallback;
  const SampleScreen({
    super.key,
    required this.image,
    this.name,
    this.dynamicCallback,
  });

  @override
  State<SampleScreen> createState() => _SampleScreenState();
}

class _SampleScreenState extends State<SampleScreen>
    with SingleTickerProviderStateMixin {
  late SVGAController controller;
  bool isLoading = true;
  Color backgroundColor = Color(0xFFFFFFFF);
  bool allowOverflow = true;
  FilterQuality filterQuality = kIsWeb ? FilterQuality.high : FilterQuality.low;
  BoxFit fit = BoxFit.contain;
  late double containerWidth;
  late double containerHeight;
  bool hideOptions = true;

  @override
  void initState() {
    super.initState();
    controller = SVGAController(vsync: this);
    // _loadAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    containerWidth = math.min(350, MediaQuery.of(context).size.width);
    containerHeight = math.min(350, MediaQuery.of(context).size.height);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  // void _playAnimation() {
  //   if (controller?.isCompleted == true) {
  //     controller?.reset();
  //   }
  //   controller?.repeat(); // or animationController.forward();
  // }

  @override
  Widget build(BuildContext context) {
    Size size = Size(containerWidth, containerHeight);

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(middle: Text(widget.name ?? "")),
      child: Padding(
        padding: EdgeInsetsGeometry.only(
          top: kMinInteractiveDimensionCupertino,
        ),

        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                "Url: ${widget.image}",
                style: TextStyle(color: CupertinoColors.white),
              ),
            ),

            Center(
              child: SVGAPlayer(
                url: widget.image,
                controller: controller,
                loadingSpinner: () => CupertinoActivityIndicator(),
                // fit: fit,
                onLoaded: () => controller.play(),
                clearsAfterStop: false,
                clipRect: allowOverflow,
                filterQuality: filterQuality,
                size: size,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
