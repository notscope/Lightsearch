# Lightsearch

Lightsearch is a spotlight replacement for macOS. It can search applications and files, evaluates calculations, opens System Settings destinations, keeps clipboard history, and includes a color picker.

## Features

- Application search
- File and folder search
- Calculator expressions, dates, time zones, and unit conversions
- Clipboard history for text, links, images, files, and colors
- Clipboard filtering, pinning, pausing, and deletion
- System Settings search
- Screen color picker

##  Build and run

Requirements:

- macOS 26 or later
- Xcode 26 (or an Xcode version that includes the macOS 26 SDK)


Build command:

```sh
xcodebuild -project Lightsearch.xcodeproj \
  -scheme Lightsearch \
  -configuration Debug \
  build
```