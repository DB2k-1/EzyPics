// App Store screenshots: build with --dart-define=SCREENSHOT_MODE=home, review
// or calendar to hide the debug banner, skip the notification prompt and open
// that screen directly. SCREENSHOT_DATE=MM-DD picks the day reviewed
// (default: today).
const String screenshotView = String.fromEnvironment('SCREENSHOT_MODE');
const String screenshotDate = String.fromEnvironment('SCREENSHOT_DATE');
const bool screenshotMode = screenshotView != '';
