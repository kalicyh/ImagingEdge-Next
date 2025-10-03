# ImagingNext

一款现代化的 Flutter 桌面应用，用于从索尼相机下载照片，灵感来源于原始的 [ImagingEdge4Linux](https://github.com/schorschii/ImagingEdge4Linux) 项目。该应用提供友好的图形界面，可通过 WiFi 与索尼相机连接并下载照片，无需官方手机应用。

## 功能特性

### 🎯 核心功能
- **相机连接**：通过 WiFi 连接索尼相机
- **图片浏览**：浏览并预览相机中的缩略图
- **批量下载**：支持一键选择全部、仅新照片或自定义选择并下载
- **进度监控**：实时显示下载速度

### 🧩 多平台支持
- 基于 Flutter 构建，可同时覆盖 macOS、Windows、Linux 桌面端以及 Android 移动端。
- 已在 macOS 与 Android 平台完成功能测试，其他平台复用相同实现但尚缺少充分验证。
- iOS 设备需要 `NEHotspotConfiguration` 权限才能在应用内配置 WiFi，因此暂时改为使用系统自带相机扫码接入。

## 应用截图

<div align="center">
  <table>
    <tr>
      <td align="center">
        <img src=".github/screenshots/CleanShot 2025-10-03 at 03.12.34@2x.png" width="400" alt="主页面"/>
        <br/>
        <b>主页面</b>
      </td>
      <td align="center">
        <img src=".github/screenshots/CleanShot 2025-10-03 at 03.11.56@2x.png" width="400" alt="二维码扫描"/>
        <br/>
        <b>二维码扫描</b>
      </td>
    </tr>
    <tr>
      <td align="center">
        <img src=".github/screenshots/CleanShot 2025-10-03 at 03.13.15@2x.png" width="400" alt="图片浏览器"/>
        <br/>
        <b>图片浏览器</b>
      </td>
      <td align="center">
        <img src=".github/screenshots/CleanShot 2025-10-03 at 03.11.27@2x.png" width="400" alt="设置"/>
        <br/>
        <b>设置</b>
      </td>
    </tr>
  </table>
</div>

## 使用指南

1. **准备相机**：
   - 在索尼相机上启用“发送到智能手机”模式

2. **在应用中连接**：
   - 启动 ImagingNext
   - 点击“扫码二维码”按钮，扫描相机屏幕上的二维码以连接，或者手动连接相机的 WiFi 网络
  - iOS 版本未申请 `NEHotspotConfiguration` 权限，请使用系统相机扫描二维码加入相机 WiFi

3. **浏览照片**：
   - 进入图片浏览页面
   - 查看可用照片的缩略图
   - 选择需要下载的照片

4. **开始下载**：
   - 照片会保存到指定的输出目录

### 图片质量
应用会以最佳可用质量下载照片：
1. **Large (LRG)**：原始 JPEG（优先）
2. **Medium (SM)**：若无法获取原图则下载较小 JPEG
3. **Thumbnail (TN)**：再不行则使用最小缩略图

**注意**：暂不支持 RAW 文件，仅可下载压缩 JPEG。

## 开发说明

### 从源码构建

1. **构建**：
   ```bash
   flutter pub get
   flutter gen-l10n
   flutter run
   ```

### 打包（macOS）

在 macOS 上运行 `scripts/release_macos.sh`，脚本会在 `dist/macos` 目录生成发布版 `.app` 与 `.dmg`。默认会依次执行 `flutter build macos --release`、`flutter build apk --release` 与 `flutter build appbundle --release`，若这些产物已经最新，可添加 `--skip-build` 跳过编译。需要提前通过 `npm install --global create-dmg` 安装 [`create-dmg`](https://github.com/create-dmg/create-dmg) 工具。脚本还会将生成的 Android 发布包（APK / AAB）自动拷贝到 `dist/android` 目录，便于统一分发。

## 限制

- **RAW 支持**：受限于相机，仅支持 JPEG 下载
- **相机依赖**：只支持“发送到智能手机”模式
- **网络要求**：设备需在同一 WiFi 网络
- **iOS 热点配置**：直接在应用内配置 WiFi 需额外的 `NEHotspotConfiguration` 权限，目前通过系统相机扫码替代实现。

## 致谢

基于原始的 [sony-pm-alt](https://github.com/falk0069/sony-pm-alt) 和 [ImagingEdge4Linux](https://github.com/schorschii/ImagingEdge4Linux) 项目，使用 Flutter 重新实现，以提供更好的用户体验与跨平台能力。

## 许可协议

本项目以 [MIT License](LICENSE) 开源发布。
