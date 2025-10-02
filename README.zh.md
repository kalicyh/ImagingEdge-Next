# ImagingEdge Next

一款现代化的 Flutter 桌面应用，用于从索尼相机下载照片，灵感来源于原始的 [ImagingEdge4Linux](https://github.com/schorschii/ImagingEdge4Linux) 项目。该应用提供友好的图形界面，可通过 WiFi 与索尼相机连接并下载照片，无需官方手机应用。

## 功能特性

### 🎯 核心功能
- **相机连接**：通过 WiFi 连接索尼相机
- **图片浏览**：浏览并预览相机中的缩略图
- **批量下载**：支持一键选择全部、仅新照片或自定义选择并下载
- **进度监控**：实时显示下载速度

## 使用指南

1. **准备相机**：
   - 在索尼相机上启用“发送到智能手机”模式

2. **在应用中连接**：
   - 启动 ImagingEdge Next
   - 点击“扫码二维码”按钮，扫描相机屏幕上的二维码以连接，或者手动连接相机的 WiFi 网络

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

## 限制

- **RAW 支持**：受限于相机，仅支持 JPEG 下载
- **相机依赖**：只支持“发送到智能手机”模式
- **网络要求**：设备需在同一 WiFi 网络

## 致谢

基于原始的 [sony-pm-alt](https://github.com/falk0069/sony-pm-alt) 和 [ImagingEdge4Linux](https://github.com/schorschii/ImagingEdge4Linux) 项目，使用 Flutter 重新实现，以提供更好的用户体验与跨平台能力。

## 许可协议

本项目以 [MIT License](LICENSE) 开源发布。
