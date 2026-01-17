# Performance Optimization Guide

## Overview
This app has been optimized to reduce Android hangs and improve responsiveness. Performance logging has been added to help identify bottlenecks.

## Performance Improvements Made

### 1. **Batched State Updates**
- Thumbnail loading now batches `setState` calls to reduce rebuilds
- Updates are collected and applied every 100ms instead of immediately

### 2. **Reduced Thumbnail Sizes**
- Preview thumbnails: 300x300 (unchanged)
- Review thumbnails: Reduced from 800x800 to 600x600
- This reduces memory usage and loading time

### 3. **Timeouts on All Async Operations**
- All `AssetEntity.fromId()` calls have 5-second timeouts
- All thumbnail loading has 5-second timeouts
- Prevents indefinite hangs

### 4. **Smaller Batch Sizes**
- Preloading now processes 3 items at a time (down from 5)
- Small delays (50ms) between batches to prevent blocking

### 5. **Performance Logging**
- All slow operations are logged automatically
- Operations exceeding thresholds are marked with ⚠️

## How to Use Performance Logging

### View Logs in Android Studio/VS Code
1. Open the Debug Console
2. Filter by "Performance" tag
3. Look for:
   - `⚠️ SLOW OPERATION` - Operations that exceeded thresholds
   - `✓ operation: Xms` - Normal operations with timing

### Enable Performance Overlay
In `lib/main.dart`, set:
```dart
showPerformanceOverlay: true,
```

This shows:
- FPS counter
- Frame rendering time
- GPU usage

Press 'P' key while app is running to toggle overlay.

### Performance Thresholds
- **Scan Library**: 5 seconds
- **Thumbnail Loading**: 500ms per thumbnail
- **Preload Operations**: 5 seconds total
- **Item Preloading**: 1 second per item

## Identifying Bottlenecks

### Common Issues and Solutions

1. **"SLOW OPERATION: scan_library"**
   - Too many photos/videos
   - Solution: Already optimized with batching

2. **"SLOW OPERATION: load_image_thumb"**
   - Large images or slow storage
   - Solution: Already using smaller thumbnails (600px)

3. **Multiple setState calls**
   - Solution: Already batched every 100ms

4. **ANR (Application Not Responding)**
   - Check logs for operations > 5 seconds
   - These should have timeouts, but may indicate device issues

## Debugging Tips

1. **Check Logs First**
   - Look for patterns in slow operations
   - Identify which operations are consistently slow

2. **Use Performance Overlay**
   - Watch FPS during transitions
   - Should stay above 30 FPS (ideally 60)

3. **Monitor Memory**
   - Use Android Studio Profiler
   - Watch for memory leaks during navigation

4. **Test on Real Device**
   - Emulators may not reflect real performance
   - Test on lower-end devices if possible

## Additional Optimizations (If Needed)

If performance is still poor:

1. **Further Reduce Thumbnail Sizes**
   - Change 600 to 400 in `carousel_screen.dart` and `swipe_card.dart`

2. **Increase Batch Delays**
   - Change 50ms to 100ms between batches

3. **Reduce Batch Sizes**
   - Change from 3 to 2 items per batch

4. **Use Isolates for Heavy Operations**
   - Move thumbnail generation to background isolates
   - More complex but can help with very large libraries

## Logging Example

```
[Performance] ✓ scan_library: 2341ms
[Performance] ⚠️ SLOW OPERATION: load_image_thumb_abc123 took 623ms (threshold: 500ms)
[Performance] ✓ preload_image_thumbnails: 3456ms
```

Operations marked with ⚠️ should be investigated if they occur frequently.
