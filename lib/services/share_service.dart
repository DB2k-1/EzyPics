import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:photo_manager/photo_manager.dart';
import 'image_branding_service.dart';
import '../models/media_item.dart';

class ShareService {
  static const String iosAppStoreUrl = 'https://apps.apple.com/us/app/ezypics/id6757226178';

  /// Shares media (image with branding, or video without branding)
  /// For iOS, sharePositionOrigin is required - pass the position of the share button
  static Future<void> shareMedia(MediaItem mediaItem, {Rect? sharePositionOrigin}) async {
    try {
      String shareText = '\n\nShared via EzyPics';
      
      // Add iOS App Store URL for iOS only
      // Put URL on separate line with spacing to minimize rich preview prominence
      if (Platform.isIOS) {
        shareText += '\n\n$iosAppStoreUrl';
        // Provide default sharePositionOrigin for iOS if not provided
        // Default to top-right area where share icon typically is
        if (sharePositionOrigin == null) {
          sharePositionOrigin = const Rect.fromLTWH(300, 100, 1, 1);
        }
      }

      if (mediaItem.isVideo) {
        // Share video without branding
        final asset = await AssetEntity.fromId(mediaItem.id);
        if (asset == null) return;
        
        final file = await asset.file;
        if (file == null) return;

        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
          sharePositionOrigin: sharePositionOrigin,
        );
      } else {
        // Share branded image
        final asset = await AssetEntity.fromId(mediaItem.id);
        if (asset == null) return;
        
        final file = await asset.file;
        if (file == null) return;

        // Brand the image
        print('Starting image branding...');
        final brandedFile = await ImageBrandingService.brandImage(file);
        if (brandedFile == null) {
          // If branding fails, share original
          print('Branding failed, sharing original image');
          await Share.shareXFiles(
            [XFile(file.path)],
            text: shareText,
            sharePositionOrigin: sharePositionOrigin,
          );
          return;
        }
        
        print('Branding successful, sharing branded image: ${brandedFile.path}');

        // Share branded image
        await Share.shareXFiles(
          [XFile(brandedFile.path)],
          text: shareText,
          sharePositionOrigin: sharePositionOrigin,
        );

        // Clean up temp file after a delay
        Future.delayed(const Duration(seconds: 5), () {
          try {
            brandedFile.deleteSync();
          } catch (e) {
            // Ignore cleanup errors
          }
        });
      }
    } catch (e) {
      print('Error sharing media: $e');
    }
  }
}
