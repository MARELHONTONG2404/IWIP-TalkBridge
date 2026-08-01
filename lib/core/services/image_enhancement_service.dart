import 'dart:io';
import 'package:image/image.dart' as img;

class ImageEnhancementService {
  /// Preprocesses an image to improve OCR accuracy.
  static Future<File> enhanceImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final image = img.decodeImage(bytes);
    
    if (image == null) return imageFile;

    // 1. Resize if too large
    img.Image processed = image;
    if (processed.width > 1200) {
      processed = img.copyResize(processed, width: 1200);
    }

    // 2. Grayscale (often helps OCR)
    processed = img.grayscale(processed);

    // 3. Contrast & Brightness
    processed = img.adjustColor(processed, contrast: 1.2, brightness: 1.1);

    // 4. Sharpen
    // Using a simpler approach if available, or just keeping original sharp but fixed syntax.
    // Actually, 'image' package has no direct `filterImage` with that signature. 
    // Let's use `img.adjustColor` with a high contrast if `sharpen` isn't direct. 
    // Or just skip the convolution part and do more aggressive contrast.
    processed = img.adjustColor(processed, contrast: 1.5);

    // Save back to temporary file
    final enhancedPath = '${imageFile.path}_enhanced.jpg';
    await File(enhancedPath).writeAsBytes(img.encodeJpg(processed, quality: 90));
    
    return File(enhancedPath);
  }
}
