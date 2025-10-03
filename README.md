# ImagingEdge Next

[中文文档](README.zh.md)

A modern Flutter desktop application for downloading images from Sony cameras, based on the original [ImagingEdge4Linux](https://github.com/schorschii/ImagingEdge4Linux) project. This app provides a user-friendly graphical interface for connecting to Sony cameras via WiFi and downloading images without requiring the official mobile application.

## Features

### 🎯 Core Functionality
- **Camera Connection**: Connect to Sony cameras over WiFi.
- **Image Browsing**: Browse and preview thumbnails stored on the camera.
- **Batch Download**: Download all, only new, or custom selections in one go.
- **Progress Monitoring**: Track download speed, progress, and ETA in real time.

### 🧩 Platform Support
- Built with Flutter to target macOS, Windows, Linux desktops, and Android mobile devices from a single codebase.
- Functional testing completed on macOS and Android builds; additional platforms share the same implementation but are less exercised.
- iOS requires the `NEHotspotConfiguration` entitlement for in-app WiFi provisioning, so ImagingEdge Next defers to the system Camera app for joining the camera network.

## Screenshots

<div align="center">
  <table>
    <tr>
      <td align="center">
        <img src=".github/screenshots/CleanShot 2025-10-03 at 03.12.34@2x.png" width="400" alt="Main Interface"/>
        <br/>
        <b>Main Interface</b>
      </td>
      <td align="center">
        <img src=".github/screenshots/CleanShot 2025-10-03 at 03.11.56@2x.png" width="400" alt="QR Code Scanner"/>
        <br/>
        <b>QR Code Scanner</b>
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src=".github/screenshots/CleanShot 2025-10-03 at 03.13.15@2x.png" width="400" alt="Image Browser"/>
        <br/>
        <b>Image Browser</b>
      </td>
      <td align="center">
        <img src=".github/screenshots/CleanShot 2025-10-03 at 03.11.27@2x.png" width="400" alt="Settings"/>
        <br/>
        <b>Settings</b>
      </td>
    </tr>
  </table>
</div>

## How to Use

1. **Prepare the Camera**:
   - Enable the "Send to Smartphone" mode on your Sony camera.

2. **Connect in the App**:
   - Launch ImagingEdge Next.
   - Tap "Scan QR Code" and scan the QR code displayed on the camera screen, or manually join the camera's WiFi network.
  - On iOS devices, the app does not request the `NEHotspotConfiguration` entitlement; use the built-in Camera app to scan the QR code and join the WiFi network directly.

3. **Browse Images**:
   - Open the images screen.
   - Review the available thumbnails.
   - Select the photos you want to download.

4. **Start Downloading**:
   - The images are saved to the output directory you configured.

### Image Quality
Images are downloaded in the best available quality:
1. **Large (LRG)**: Preferred original JPEG.
2. **Medium (SM)**: Smaller JPEG if the large file is unavailable.
3. **Thumbnail (TN)**: Fallback to the smallest thumbnail.

**Note**: RAW files are not supported—only compressed JPEG downloads are available.

## Development

### Building from Source

1. **Build**:
   ```bash
   flutter pub get
   flutter gen-l10n
   flutter run
   ```

### Packaging (macOS)

Run `scripts/release_macos.sh` to build a release `.app` bundle and `.dmg` image in `dist/macos`. By default the script runs `flutter build macos --release`, `flutter build apk --release`, and `flutter build appbundle --release`; pass `--skip-build` if those artifacts are already up to date. Requires macOS with the [`create-dmg`](https://github.com/create-dmg/create-dmg) utility installed via `npm install --global create-dmg`. Android release outputs (APK and/or AAB) are copied into `dist/android` for convenience.

## Limitations

- **RAW Support**: Limited to JPEG downloads due to camera constraints.
- **Camera Dependency**: Only works with cameras that provide "Send to Smartphone" mode.
- **Network Requirements**: Devices must share the same WiFi network.
- **iOS Hotspot Provisioning**: Direct WiFi configuration would require the `NEHotspotConfiguration` entitlement, so pairing relies on Apple's Camera app instead of ImagingEdge Next.

## Credits

Based on the original [sony-pm-alt](https://github.com/falk0069/sony-pm-alt) and [ImagingEdge4Linux](https://github.com/schorschii/ImagingEdge4Linux) project, reimplemented in Flutter for improved user experience and cross-platform compatibility.

## License

This project is open source and available under the [MIT License](LICENSE).
