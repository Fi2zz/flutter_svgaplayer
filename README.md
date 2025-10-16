# flutter_svgaplayer

A **Flutter package** for parsing and rendering **SVGA animations** efficiently.  
SVGA is a lightweight and powerful animation format used for **dynamic UI effects** in mobile applications.

<p align="center">
  <img src="https://raw.githubusercontent.com/Fi2zz/flutter_svgaplayer/master/example.gif" width="300"/>
  <img src="https://raw.githubusercontent.com/Fi2zz/flutter_svgaplayer/master/example1.gif" width="300"/>
</p>

---

## 🚀 **Features**

✔️ Parse and render **SVGA animations** in Flutter.  
✔️ Load SVGA files from **network URLs**.  
✔️ Supports **custom dynamic elements** (text, images, custom drawing).  
✔️ **Optimized playback performance** with animation controllers.  
✔️ Works on **Android, iOS, Web, macOS, Linux & Desktop**.  
✔️ Easy **loop, stop, and seek** functions.  
✔️ **Flexible sizing** and **fit options**.  
✔️ **Custom loading spinners** and **callbacks**.

---

## 📌 **Installation**

Add **flutter_svgaplayer** to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_svgaplayer:
    git:
      url: https://github.com/Fi2zz/flutter_svgaplayer.git
```

Then, install dependencies:

```sh
flutter pub get
```

---

## 🎬 **Basic Usage**

### ✅ **Playing an SVGA Animation from Network URL**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_svgaplayer/flutter_svgaplayer.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("Flutter SVGA Example")),
        body: Center(
          child: SVGAPlayer(
            url: "https://example.com/sample.svga",
            fit: BoxFit.contain,
            loopCount: 0, // 0 means infinite loop
            onLoaded: () {
              print("SVGA animation loaded!");
            },
          ),
        ),
      ),
    );
  }
}
```

---

## 🎨 **Custom Loading Spinner**

```dart
SVGAPlayer(
  url: "https://example.com/sample.svga",
  fit: BoxFit.cover,
  loadingSpinner: () => CircularProgressIndicator(),
  size: Size(200, 200),
);
```

---

## 🎭 **Advanced Usage: Using SVGAController**

### ✅ **Controlling Animation Playback**

```dart
class MySVGAWidget extends StatefulWidget {
  @override
  _MySVGAWidgetState createState() => _MySVGAWidgetState();
}

class _MySVGAWidgetState extends State<MySVGAWidget>
    with SingleTickerProviderStateMixin {
  late SVGAController _controller;

  @override
  void initState() {
    super.initState();
    _controller = SVGAController(vsync: this);
    _loadAnimation();
  }

  Future<void> _loadAnimation() async {
    try {
      await _controller.load("https://example.com/sample.svga");
      _controller.repeat(count: 3); // Play 3 times
    } catch (e) {
      print("Failed to load SVGA: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SVGAPlayer(controller: _controller);
  }
}
```

---

## 🎨 **Customization & Dynamic Elements**

### ✅ **Adding Dynamic Text**

```dart
// Create a TextPainter for dynamic text
final textPainter = TextPainter(
  text: TextSpan(
    text: "Hello SVGA!",
    style: TextStyle(color: Colors.red, fontSize: 18),
  ),
  textDirection: TextDirection.ltr,
);

// Set dynamic text using controller method
controller.setDynamicItemText(textPainter, "text_layer");
```

---

### ✅ **Replacing an Image Dynamically**

```dart
// Set dynamic image from URL
controller.setDynamicItemImageWithUrl(
  "https://example.com/new_image.png",
  "image_layer",
);

// Or set image directly
controller.videoItem?.dynamicItem.setImage(image, "image_layer");
```

---

### ✅ **Hiding a Layer**

```dart
// Hide a specific layer
controller.setDynamicHidden(true, "layer_to_hide");

// Show the layer again
controller.setDynamicHidden(false, "layer_to_hide");
```

---

### ✅ **Custom Drawing**

```dart
// Add custom drawing function
controller.videoItem?.dynamicItem.setDynamicDrawer(
  (Canvas canvas, int frameIndex) {
    // Custom drawing logic here
    final paint = Paint()..color = Colors.blue;
    canvas.drawCircle(Offset(50, 50), 20, paint);
  },
  "custom_layer",
);
```

---

## 🎯 **Playback Controls**

```dart
// Basic playback controls
controller.forward();              // Play once from current position
controller.reverse();              // Play in reverse
controller.repeat(count: 5);       // Loop 5 times (0 = infinite)
controller.stop();                 // Stop animation
controller.reset();                // Reset to first frame

// Advanced controls
controller.play(reverse: true);    // Play with reverse option
controller.value = 0.5;            // Jump to 50% of animation

// Animation information
int currentFrame = controller.currentFrame;  // Get current frame index
int totalFrames = controller.frames;         // Get total frame count
bool isLoaded = controller.loaded;           // Check if animation is loaded

// Clear animation
controller.clear();                // Clear current frame
controller.clearVideoItem();       // Clear video item and free memory
```

---

## 🛠 **Common Issues & Solutions**

### ❌ **Black Screen when Loading SVGA**

✅ **Solution:** Check if the SVGA file URL is accessible and the animation has loaded successfully.

```dart
SVGAPlayer(
  url: "https://example.com/sample.svga",
  onLoaded: () {
    print("SVGA loaded successfully!");
  },
  loadingSpinner: () => CircularProgressIndicator(),
);
```

---

### ❌ **SVGA Not Loading from Network**

✅ **Solution:** Ensure the SVGA file is accessible via HTTPS and handle loading errors.

```dart
Future<void> loadSVGA() async {
  try {
    await controller.load("https://example.com/sample.svga");
    controller.repeat();
  } catch (e) {
    print("Failed to load SVGA: $e");
    // Handle error appropriately
  }
}
```

---

### ❌ **Animation Freezes or Doesn't Play**

✅ **Solution:** Check if the animation is loaded before trying to play it.

```dart
if (controller.loaded) {
  controller.repeat();
} else {
  // Wait for loading to complete
  controller.addLoadListener((loaded) {
    if (loaded) {
      controller.repeat();
    }
  });
}
```

---

### ❌ **Memory Issues with Large SVGA Files**

✅ **Solution:** Use `clipRect` and `filterQuality` options to optimize performance.

```dart
SVGAPlayer(
  url: "https://example.com/large_animation.svga",
  clipRect: true,  // Prevent drawing outside bounds
  filterQuality: FilterQuality.low,  // Reduce memory usage
  clearsAfterStop: true,  // Clear canvas after animation stops
);
```

---

## 📱 **Supported Platforms**

| Platform   | Supported | Notes        |
| ---------- | --------- | ------------ |
| ✅ Android | ✔️ Yes    | Full support |
| ✅ iOS     | ✔️ Yes    | Full support |
| ✅ Linux   | ✔️ Yes    | Full support |
| ✅ Web     | ✔️ Yes    | Full support |
| ✅ macOS   | ✔️ Yes    | Full support |
| ✅ Windows | ✔️ Yes    | Full support |

---

## 🔄 **Changelog**

See the latest changes in [`CHANGELOG.md`](CHANGELOG.md).

---

## 📜 **License**

This package is licensed under the **MIT License**. See [`LICENSE`](LICENSE) for details.

---

## 🤝 **Contributing**

- If you find a **bug**, report it in the project issues.
- Pull requests are welcome! Please follow the project's coding standards.
- Make sure to test your changes on multiple platforms before submitting.

---

## 📚 **API Reference**

### SVGAPlayer Properties

| Property          | Type              | Default             | Description                         |
| ----------------- | ----------------- | ------------------- | ----------------------------------- |
| `url`             | `String?`         | `null`              | Network URL of the SVGA file        |
| `controller`      | `SVGAController?` | `null`              | Custom animation controller         |
| `fit`             | `BoxFit`          | `BoxFit.contain`    | How to fit the animation in the box |
| `size`            | `Size?`           | `null`              | Custom size for the animation       |
| `loopCount`       | `int?`            | `0`                 | Number of loops (0 = infinite)      |
| `autoload`        | `bool?`           | `true`              | Whether to auto-load the animation  |
| `clearsAfterStop` | `bool`            | `true`              | Clear canvas after animation stops  |
| `filterQuality`   | `FilterQuality`   | `FilterQuality.low` | Image filter quality                |
| `clipRect`        | `bool?`           | `null`              | Whether to clip drawing to bounds   |
| `loadingSpinner`  | `LoadingSpinner?` | `null`              | Custom loading widget               |
| `onLoaded`        | `VoidCallback?`   | `null`              | Callback when animation loads       |

---

🚀 **Enjoy using SVGA animations in your Flutter app!** 🚀
