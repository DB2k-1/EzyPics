# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This App Does

EzyPics is a Flutter app (iOS + Android) that helps users reclaim device storage by reviewing and deleting unwanted photos and videos. The core UX: pick a calendar date → swipe through every photo/video taken on that day across all years → confirm deletions.

## Commands

```bash
# Run on connected device/simulator
flutter run

# Analyze (lint)
flutter analyze

# Run tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Install dependencies
flutter pub get

# Build
flutter build ios
flutter build apk
flutter build appbundle

# Regenerate launcher icons after changing assets/app_icon.png
flutter pub run flutter_launcher_icons
```

## Architecture

### Navigation / Screen Flow

All routes use instant zero-duration transitions (no slide animation). The route map in `lib/main.dart`:

```
/ (InitialScreen)
  → checks photo permission
  → /home  (has permission)
  → PermissionScreen  (no permission)

/home (HomeScreen)
  → shows deletion stats
  → "Review Media" button → /carousel (or /settings if no media today)
  → "Date Selector" → /settings

/carousel (CarouselScreen)
  → scans all media, groups by MM-DD date key
  → shows year cards for selected date
  → inline swipe review mode (no separate route)
  → /deletion-confirmation  (items marked for delete)
  → /home  (nothing to delete)

/swipe (SwipeScreen)
  → receives dateKey + List<MediaItem> as route args
  → card swipe: left=delete, right=keep
  → /deletion-confirmation or /home

/deletion-confirmation (DeletionConfirmationScreen)
  → receives mediaToDelete + thumbnail caches as route args
  → user deselects items they changed their mind about
  → calls PhotoManager.editor.deleteWithIds()
  → records stats via StatsService → /home

/settings (SettingsScreen)
  → calendar picker (table_calendar)
  → dates with media are highlighted
  → selecting a date navigates to /swipe with that date's media
```

### Key Design Decision: `dateKey` is MM-DD Only

`MediaItem.dateKey` returns `"MM-DD"` with no year. This is intentional — the app groups the same calendar day across all years together (e.g., "all photos taken on May 8th, across 2019–2024"). The `year` is stored separately on `MediaItem` and displayed in the UI per-item.

### Data Flow

`PhotoService.scanMediaByDate()` is the single source of truth. It fetches all assets from the device's first album in 200-item batches with 10-second timeouts and groups them into `Map<String, List<MediaItem>>` keyed by `MM-DD`. This is called fresh on each screen that needs media — there is no global state or caching of the media map between screens.

### Cache Management (Critical for iOS "Documents & Data")

`lib/utils/cache_cleanup.dart` — `CacheCleanup` clears all writable disk directories that `photo_manager` and `video_player` write to. This is what keeps iOS "Documents & Data" from ballooning.

When cleanup runs:
- **On background** (`AppLifecycleState.paused/detached`) — `CacheCleanupAppWrapper` in `main.dart`
- **Before showing media** — `HomeScreen` awaits `clearAllDiskCaches()` before navigating
- **Periodically during review** — `Timer.periodic(2 minutes)` in `CarouselScreen` and `SwipeScreen`
- **On dispose** of media screens — explicit call in `dispose()`

Flutter's in-memory image cache is capped at startup: 60 images / 25 MB (set in `main()`).

### In-Memory Thumbnail Caches

Both `CarouselScreen` and `SwipeScreen` maintain their own LRU thumbnail caches:
- `_imageThumbnailCache` / `_videoThumbnailCache`: `Map<String, Uint8List>` (max 40 entries each)
- `_imageThumbnailOrder` / `_videoThumbnailOrder`: insertion-order lists for LRU eviction
- Thumbnails are generated at 480×480px (aspect-ratio-preserving for images)
- These caches are passed to `DeletionConfirmationScreen` via route arguments to avoid re-fetching

### Services

| Service | Purpose |
|---|---|
| `PhotoService` | Wraps `photo_manager`: scan, permission, delete, file size, iCloud filter |
| `StatsService` | Persists deletion counts and storage bytes via `SharedPreferences` |
| `CacheCleanup` | Disk cache clearing (see above) |
| `ShareService` | Wraps `share_plus` for sharing stats |
| `ImageBrandingService` | Adds branding overlay to images before sharing |
| `VideoSettingsService` | Video playback settings persistence |
| `TestPhotoGenerator` | Dev-only: generates test media (hidden behind tap counter in SettingsScreen) |

### Performance

See `PERFORMANCE_GUIDE.md` for full details. Key patterns:
- `PerformanceLogger` (`lib/utils/performance_logger.dart`) logs operations exceeding thresholds (500ms for thumbnails, 5s for scans)
- To enable the Flutter performance overlay: set `showPerformanceOverlay: true` in `main.dart`
- Thumbnail batch preloading processes 5 images at a time with `Future.wait`
- Small 10ms delays between 200-item batches in `scanMediaByDate` keep the UI responsive
- All `AssetEntity.fromId()` and thumbnail calls have explicit timeouts

### Platform Notes

- Portrait-only (locked in `main()` via `SystemChrome.setPreferredOrientations`)
- Android: uses `0.55` height multiplier for swipe cards (vs `0.6` on iOS) to account for navigation bar
- iOS share sheet requires `sharePositionOrigin` rect — `HomeScreen` uses `RenderBox` to get the share button's position
- iCloud-only assets are filtered out before deletion via `PhotoService.filterToLocallyAvailable()`
