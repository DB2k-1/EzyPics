import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:native_exif/native_exif.dart';
import 'package:image/image.dart' as img;
import 'dart:ui' as ui;

class TestPhotoGenerator {
  static Future<bool> generateTestPhotos({
    required String dateKey, // MM-DD format
    required int yearsBack,
    required int minPhotosPerYear,
    required int maxPhotosPerYear,
  }) async {
    try {
      final parts = dateKey.split('-');
      final month = int.parse(parts[0]);
      final day = int.parse(parts[1]);
      final currentYear = DateTime.now().year;
      final random = Random();

      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      
      int totalGenerated = 0;
      int photosGenerated = 0;
      int videosGenerated = 0;
      int photosFailed = 0;
      int videosFailed = 0;

      // Generate photos for each year
      for (int yearOffset = 0; yearOffset < yearsBack; yearOffset++) {
        final year = currentYear - yearOffset;
        final photoCount = minPhotosPerYear + random.nextInt(maxPhotosPerYear - minPhotosPerYear + 1);
        
        print('Year $year: Generating $photoCount items');
        
        // Create date for this year (use noon to avoid timezone issues)
        final targetDate = DateTime(year, month, day, 12, 0, 0);
        
        for (int i = 0; i < photoCount; i++) {
          // Generate a unique colored image
          final color = Color.fromRGBO(
            random.nextInt(256),
            random.nextInt(256),
            random.nextInt(256),
            1.0,
          );
          
          // Format date in UK format (DD/MM/YYYY)
          final ukDate = '${day.toString().padLeft(2, '0')}/${month.toString().padLeft(2, '0')}/$year';
          
          // Decide if this should be a video (30% chance)
          final isVideo = random.nextDouble() < 0.3;
          
          if (isVideo) {
            // Copy the template video file and set creation date
            final videoFile = await _copyTemplateVideo(
              directory: tempDir,
              filename: 'test_${year}_${i}_video.mov',
              targetDate: targetDate,
            );
            
            if (videoFile != null) {
              try {
                final asset = await PhotoManager.editor.saveVideo(
                  videoFile,
                  title: 'EzyPics Test Video $year-$i',
                );
                if (asset != null) {
                  totalGenerated++;
                  videosGenerated++;
                  print('Video saved: $year-$i');
                } else {
                  videosFailed++;
                  print('Video save failed: $year-$i (asset is null)');
                }
              } catch (e) {
                videosFailed++;
                print('Error saving video: $e');
              }
              
              try {
                await videoFile.delete();
              } catch (e) {
                // Ignore cleanup errors
              }
            }
          } else {
            // Create photo file
            final imageFile = await _createTestImage(
              color: color,
              width: 800,
              height: 600,
              text: '$ukDate\nTest Photo #${i + 1}',
              directory: tempDir,
              filename: 'test_${year}_$i.jpg',
            );
            
            if (imageFile != null) {
              try {
                // Set EXIF creation date using native_exif
                await _setExifCreationDate(imageFile.path, targetDate);
                
                // Read file bytes (after EXIF modification)
                final bytes = await imageFile.readAsBytes();
                
                // Save to photo library
                final asset = await PhotoManager.editor.saveImage(
                  bytes,
                  title: 'EzyPics Test $year-$i',
                  filename: 'test_${year}_$i.jpg',
                );
                
                if (asset != null) {
                  totalGenerated++;
                  photosGenerated++;
                  print('Photo saved: $year-$i');
                } else {
                  photosFailed++;
                  print('Photo save failed: $year-$i (asset is null)');
                }
              } catch (e) {
                photosFailed++;
                print('Error saving image: $e');
              }
              
              // Clean up temp file
              try {
                await imageFile.delete();
              } catch (e) {
                // Ignore cleanup errors
              }
            }
          }
        }
      }

      print('Generation complete:');
      print('  Total items: $totalGenerated');
      print('  Photos: $photosGenerated (failed: $photosFailed)');
      print('  Videos: $videosGenerated (failed: $videosFailed)');
      print('  Expected range: ${yearsBack * minPhotosPerYear} - ${yearsBack * maxPhotosPerYear} items');

      return totalGenerated > 0;
    } catch (e) {
      print('Error generating test photos: $e');
      return false;
    }
  }

  static Future<File?> _createTestImage({
    required Color color,
    required int width,
    required int height,
    required String text,
    required Directory directory,
    required String filename,
  }) async {
    try {
      // Create a picture recorder
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Draw background
      final paint = Paint()..color = color;
      canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), paint);
      
      // Draw text with larger, clearer font
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 72,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: const Offset(2, 2),
                blurRadius: 4,
                color: Colors.black.withOpacity(0.8),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout(maxWidth: width.toDouble());
      textPainter.paint(
        canvas,
        Offset(
          (width - textPainter.width) / 2,
          (height - textPainter.height) / 2,
        ),
      );
      
      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(width, height);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      
      if (byteData != null) {
        // Convert to JPEG
        final jpegBytes = await _rawRgbaToJpeg(byteData.buffer.asUint8List(), width, height);
        if (jpegBytes != null) {
          final file = File('${directory.path}/$filename');
          await file.writeAsBytes(jpegBytes);
          return file;
        }
      }
      
      return null;
    } catch (e) {
      print('Error creating test image: $e');
      return null;
    }
  }

  static Future<Uint8List?> _rawRgbaToJpeg(Uint8List rgbaBytes, int width, int height) async {
    try {
      // Convert RGBA to image package format
      final image = img.Image(width: width, height: height);
      
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final index = (y * width + x) * 4;
          final r = rgbaBytes[index];
          final g = rgbaBytes[index + 1];
          final b = rgbaBytes[index + 2];
          final a = rgbaBytes[index + 3];
          
          image.setPixelRgba(x, y, r, g, b, a);
        }
      }
      
      // Encode as JPEG
      return Uint8List.fromList(img.encodeJpg(image, quality: 95));
    } catch (e) {
      print('Error converting to JPEG: $e');
      return null;
    }
  }


  static Future<void> _setExifCreationDate(String imagePath, DateTime date) async {
    try {
      // Format date for EXIF: YYYY:MM:DD HH:MM:SS
      final dateString = '${date.year.toString().padLeft(4, '0')}:'
          '${date.month.toString().padLeft(2, '0')}:'
          '${date.day.toString().padLeft(2, '0')} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}:'
          '${date.second.toString().padLeft(2, '0')}';

      final exif = await Exif.fromPath(imagePath);
      
      // Set DateTimeOriginal (main creation date tag)
      await exif.writeAttribute('DateTimeOriginal', dateString);
      
      // Also set DateTimeDigitized (when image was digitized)
      await exif.writeAttribute('DateTimeDigitized', dateString);
      
      // Set DateTime (when file was last modified - usually same as original for photos)
      await exif.writeAttribute('DateTime', dateString);
      
      await exif.close();
    } catch (e) {
      print('Error setting EXIF date: $e');
      // Continue anyway - photo will still be saved with current date
    }
  }

  static Future<File?> _copyTemplateVideo({
    required Directory directory,
    required String filename,
    required DateTime targetDate,
  }) async {
    try {
      // Load the template video from assets
      final videoData = await rootBundle.load('assets/test_video.mov');
      final videoBytes = videoData.buffer.asUint8List();
      
      // Write to temp file
      final videoFile = File('${directory.path}/$filename');
      await videoFile.writeAsBytes(videoBytes);
      
      // Note: Video metadata (creation date) is more complex to modify
      // For now, the video will have the current date when saved
      // To set video creation dates, we'd need ffmpeg or similar tools
      
      return videoFile;
    } catch (e) {
      print('Error copying template video: $e');
      print('Make sure assets/test_video.mov exists and is listed in pubspec.yaml');
      return null;
    }
  }
}

