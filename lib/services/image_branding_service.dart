import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class ImageBrandingService {
  static const String logoAssetPath = 'assets/EzyPics_header.png';
  static const int blueBorderWidth = 20;
  static const int whiteFramePadding = 60; // Increased for more white space
  static const int logoHeight = 280; // Even larger logo
  static const double imageScale = 0.65; // Scale image to 65% for more white space around image

  /// Brands an image with EzyPics frame and returns the branded image file
  static Future<File?> brandImage(File originalImageFile) async {
    try {
      // Load original image
      final originalBytes = await originalImageFile.readAsBytes();
      final originalImage = img.decodeImage(originalBytes);
      if (originalImage == null) {
        print('Error: Could not decode original image');
        return null;
      }

      // Load logo
      final logoData = await rootBundle.load(logoAssetPath);
      final logoImage = img.decodeImage(logoData.buffer.asUint8List());
      if (logoImage == null) {
        print('Error: Could not decode logo image from $logoAssetPath');
        return null;
      }

      // Scale original image to 80% for better fit in frame
      final scaledImageWidth = (originalImage.width * imageScale).round();
      final scaledImageHeight = (originalImage.height * imageScale).round();
      final scaledImage = img.copyResize(
        originalImage,
        width: scaledImageWidth,
        height: scaledImageHeight,
      );
      
      // Logo width maintains aspect ratio
      final logoAspectRatio = logoImage.width / logoImage.height;
      final logoWidth = (logoHeight * logoAspectRatio).round();
      
      // Resize logo to desired height while maintaining aspect ratio
      final resizedLogo = img.copyResize(
        logoImage,
        width: logoWidth,
        height: logoHeight,
      );
      
      // Calculate total dimensions: blue border + white frame + logo + scaled image
      final totalWidth = blueBorderWidth * 2 + whiteFramePadding * 2 + scaledImageWidth;
      final totalHeight = blueBorderWidth * 2 + whiteFramePadding * 2 + 
                         logoHeight + 10 + // logo + gap
                         scaledImageHeight;

      // Create canvas with blue background (border)
      final brandedImage = img.Image(
        width: totalWidth,
        height: totalHeight,
      );
      
      // Fill with blue color (EzyPics blue - you can adjust this color)
      img.fill(brandedImage, color: img.ColorRgb8(33, 150, 243)); // Material blue

      // Draw white frame area
      final whiteFrameTop = blueBorderWidth;
      final whiteFrameLeft = blueBorderWidth;
      final whiteFrameWidth = totalWidth - (blueBorderWidth * 2);
      final whiteFrameHeight = totalHeight - (blueBorderWidth * 2);
      
      // Create white frame image and composite it
      final whiteFrame = img.Image(width: whiteFrameWidth, height: whiteFrameHeight);
      img.fill(whiteFrame, color: img.ColorRgb8(255, 255, 255));
      img.compositeImage(
        brandedImage,
        whiteFrame,
        dstX: whiteFrameLeft,
        dstY: whiteFrameTop,
      );

      // Draw logo at top center
      final logoTop = blueBorderWidth + whiteFramePadding;
      final logoLeft = (totalWidth - logoWidth) ~/ 2;
      img.compositeImage(
        brandedImage,
        resizedLogo,
        dstX: logoLeft,
        dstY: logoTop,
      );

      // Draw scaled image below logo
      final imageTop = logoTop + logoHeight + 10;
      final imageLeft = (totalWidth - scaledImageWidth) ~/ 2;
      img.compositeImage(
        brandedImage,
        scaledImage,
        dstX: imageLeft,
        dstY: imageTop,
      );

      // Note: Text overlay "via EzyPics" can be added here in the future
      // For now, the text is included in the share message

      // Save branded image to temp file
      final brandedBytes = Uint8List.fromList(img.encodePng(brandedImage));
      if (brandedBytes.isEmpty) {
        print('Error: Encoded branded image bytes are empty');
        return null;
      }
      
      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/branded_${DateTime.now().millisecondsSinceEpoch}.png');
      await tempFile.writeAsBytes(brandedBytes);
      
      if (!await tempFile.exists()) {
        print('Error: Branded image file was not created');
        return null;
      }
      
      final fileSize = await tempFile.length();
      print('Branded image created: ${tempFile.path} (${fileSize} bytes)');
      
      return tempFile;
    } catch (e, stackTrace) {
      print('Error branding image: $e');
      print('Stack trace: $stackTrace');
      return null;
    }
  }
}
