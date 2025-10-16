import 'dart:ui' as ui show Image;
import 'package:http/http.dart';
import 'package:flutter/painting.dart';

/// Typedef for a custom drawing function that can be used to draw custom content
/// 
/// [canvas] - The canvas to draw on
/// [frameIndex] - The current frame index of the animation
typedef SVGACustomDrawer = Function(Canvas canvas, int frameIndex);

/// A class that manages dynamic content for SVGA animations
/// 
/// SVGADynamicEntity allows you to dynamically modify SVGA animations by:
/// - Hiding/showing specific layers
/// - Replacing images in specific layers
/// - Adding custom text to specific layers
/// - Adding custom drawing functions to specific layers
/// 
/// All dynamic content is identified by string keys that correspond to
/// layer names or identifiers in the SVGA file.
class SVGADynamicEntity {
  /// Map storing hidden state for each layer
  /// Key: layer identifier, Value: whether the layer should be hidden
  final Map<String, bool> dynamicHidden = {};
  
  /// Map storing replacement images for each layer
  /// Key: layer identifier, Value: the replacement image
  final Map<String, ui.Image> dynamicImages = {};
  
  /// Map storing custom text painters for each layer
  /// Key: layer identifier, Value: the text painter for rendering text
  final Map<String, TextPainter> dynamicText = {};
  
  /// Map storing custom drawing functions for each layer
  /// Key: layer identifier, Value: the custom drawing function
  final Map<String, SVGACustomDrawer> dynamicDrawer = {};

  /// Sets the hidden state for a specific layer
  /// 
  /// [value] - Whether the layer should be hidden (true) or visible (false)
  /// [forKey] - The layer identifier to apply the hidden state to
  void setHidden(bool value, String forKey) {
    dynamicHidden[forKey] = value;
  }

  /// Sets a replacement image for a specific layer
  /// 
  /// [image] - The ui.Image to use as replacement
  /// [forKey] - The layer identifier to apply the image to
  void setImage(ui.Image image, String forKey) {
    dynamicImages[forKey] = image;
  }

  /// Sets a replacement image for a specific layer by loading from a URL
  /// 
  /// This method downloads the image from the provided URL and decodes it.
  /// The operation is asynchronous and will complete when the image is loaded.
  /// 
  /// [url] - The URL of the image to download and use as replacement
  /// [forKey] - The layer identifier to apply the image to
  /// 
  /// Returns a Future that completes when the image is loaded and set
  Future<void> setImageWithUrl(String url, String forKey) async {
    dynamicImages[forKey] = await decodeImageFromList(
      (await get(Uri.parse(url))).bodyBytes,
    );
  }

  /// Sets custom text for a specific layer
  /// 
  /// The TextPainter will be used to render text content on the specified layer.
  /// If the TextPainter doesn't have a textDirection set, it will be set to
  /// left-to-right and the painter will be laid out.
  /// 
  /// [textPainter] - The configured TextPainter for rendering text
  /// [forKey] - The layer identifier to apply the text to
  void setText(TextPainter textPainter, String forKey) {
    // Ensure text direction is set for proper text rendering
    if (textPainter.textDirection == null) {
      textPainter.textDirection = TextDirection.ltr;
      textPainter.layout();
    }
    dynamicText[forKey] = textPainter;
  }

  /// Sets a custom drawing function for a specific layer
  /// 
  /// The custom drawer function will be called during animation rendering
  /// and can be used to draw custom content on the canvas.
  /// 
  /// [drawer] - The custom drawing function
  /// [forKey] - The layer identifier to apply the custom drawer to
  void setDynamicDrawer(SVGACustomDrawer drawer, String forKey) {
    dynamicDrawer[forKey] = drawer;
  }

  /// Resets all dynamic content
  /// 
  /// Clears all dynamic modifications including hidden states, images,
  /// text, and custom drawing functions. After calling this method,
  /// the animation will render with its original content.
  void reset() {
    dynamicHidden.clear();
    dynamicImages.clear();
    dynamicText.clear();
    dynamicDrawer.clear();
  }
}
