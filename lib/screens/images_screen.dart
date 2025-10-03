import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:imagingedge_next/l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../utils/utils.dart';
import '../widgets/fluid_dock.dart';

class ImagesScreen extends ConsumerStatefulWidget {
  const ImagesScreen({super.key});

  @override
  ConsumerState<ImagesScreen> createState() => _ImagesScreenState();
}

class _ImagesScreenState extends ConsumerState<ImagesScreen> {
  @override
  void initState() {
    super.initState();
    // Auto-browse images when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(imagesProvider.notifier).browseImages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final imagesState = ref.watch(imagesProvider);
    final downloadState = ref.watch(downloadProvider);
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(l10n.imagesTitle),
        // backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: imagesState.isLoading
                ? null
                : () {
                    ref.read(imagesProvider.notifier).refreshImages();
                  },
            icon: imagesState.isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selection toolbar
          if (imagesState.hasSelection)
            _buildSelectionToolbar(context, imagesState, downloadState, l10n),
          
          // Main content
          Expanded(
            child: _buildContent(context, imagesState, l10n),
          ),
          
          // Download progress
          if (downloadState.isDownloading)
            _buildDownloadProgress(context, downloadState, l10n),
        ],
      ),
    floatingActionButton: imagesState.hasImages && !downloadState.isDownloading
          ? FloatingActionButton.extended(
              onPressed: () async {
                if (imagesState.hasSelection) {
                  await _startDownload();
                } else {
                  _showSelectionDialog(context);
                }
              },
              icon: const Icon(Icons.download),
              label: Text(
                imagesState.hasSelection
                    ? l10n.imagesDownloadWithCount(imagesState.selectedCount)
                    : l10n.imagesDownload,
              ),
            )
          : null,
      bottomNavigationBar: const FluidDock(currentRoute: '/images'),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ImagesState state,
    AppLocalizations l10n,
  ) {
    if (state.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.imagesLoading),
          ],
        ),
      );
    }

    if (state.errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.imagesLoadFailed,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage!,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(imagesProvider.notifier).refreshImages();
              },
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      );
    }
    
    if (!state.hasImages) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.imagesNoImages,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.imagesNoImagesHint,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 120),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: state.images.length,
      itemBuilder: (context, index) {
        final image = state.images[index];
        return _buildImageTile(context, image, state.selectedImages.contains(image));
      },
    );
  }

  Widget _buildImageTile(BuildContext context, ImageModel image, bool isSelected) {
    return Card(
      elevation: isSelected ? 8 : 2,
      child: InkWell(
        onTap: () {
          ref.read(imagesProvider.notifier).toggleImageSelection(image);
        },
        child: Stack(
          children: [
            // Image
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: image.thumbnailUrl != null
                    ? CachedNetworkImage(
                        imageUrl: image.thumbnailUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
              ),
            ),
            
            // Downloaded overlay
            if (image.isDownloaded)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.35),
                            Colors.white.withValues(alpha: 0.15),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // Selection overlay
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
          color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: 0.25),
                  ),
                ),
              ),
            
            // Selection checkbox
            Positioned(
              top: 4,
              right: 4,
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.black.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
            
            if (image.isDownloaded)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(48),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 36,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            
            // File info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      image.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (image.size != null)
                      Text(
                        FileManager.formatFileSize(image.size!),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 8,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionToolbar(
    BuildContext context,
    ImagesState imagesState,
    DownloadState downloadState,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Text(
            l10n.imagesSelectedCount(imagesState.selectedCount),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: downloadState.isDownloading ? null : () {
              ref.read(imagesProvider.notifier).selectAllImages();
            },
            child: Text(l10n.imagesSelectAll),
          ),
          TextButton(
            onPressed: downloadState.isDownloading ? null : () {
              ref.read(imagesProvider.notifier).selectUndownloadedImages();
            },
            child: Text(l10n.imagesSelectNew),
          ),
          TextButton(
            onPressed: downloadState.isDownloading ? null : () {
              ref.read(imagesProvider.notifier).clearSelection();
            },
            child: Text(l10n.imagesClearSelection),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadProgress(
    BuildContext context,
    DownloadState state,
    AppLocalizations l10n,
  ) {
    final progress = state.progress;

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.imagesDownloading(progress.currentFileName),
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.imagesFilesProgress(
                        progress.currentFileIndex,
                        progress.totalFiles,
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  ref.read(downloadProvider.notifier).cancelDownload();
                },
                child: Text(l10n.imagesCancelDownload),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.overallProgress,
            backgroundColor: Colors.grey[300],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress.overallProgress * 100).toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (progress.downloadSpeed != null)
                Text(
                  '${FileManager.formatFileSize(progress.downloadSpeed!.round())}/s',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSelectionDialog(BuildContext context) {
    final imagesState = ref.read(imagesProvider);
    final l10n = AppLocalizations.of(context)!;

    if (!imagesState.hasImages) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.downloadDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.downloadDialogPrompt),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.select_all),
              title: Text(l10n.downloadDialogAll),
              subtitle: Text(
                l10n.imagesCount(imagesState.images.length),
              ),
              onTap: () async {
                Navigator.pop(context);
                ref.read(imagesProvider.notifier).selectAllImages();
                await _startDownload();
              },
            ),
            ListTile(
              leading: const Icon(Icons.new_releases),
              title: Text(l10n.downloadDialogNew),
              subtitle: Text(
                l10n.imagesCount(
                  imagesState.images
                      .where((img) => !img.isDownloaded)
                      .length,
                ),
              ),
              onTap: () async {
                Navigator.pop(context);
                ref.read(imagesProvider.notifier).selectUndownloadedImages();
                await _startDownload();
              },
            ),
            if (imagesState.hasSelection)
              ListTile(
                leading: const Icon(Icons.download),
                title: Text(l10n.downloadDialogSelected),
                subtitle: Text(
                  l10n.imagesCount(imagesState.selectedCount),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  await _startDownload();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.commonCancel),
          ),
        ],
      ),
    );
  }

  Future<void> _startDownload() async {
    final imagesState = ref.read(imagesProvider);
    final selectedImages = imagesState.selectedImages;
    if (selectedImages.isEmpty) {
      return;
    }

    await ref.read(downloadProvider.notifier).startDownload(selectedImages);

    if (!mounted) return;

    final downloadState = ref.read(downloadProvider);
    if (downloadState.progress.status == DownloadStatus.completed) {
      ref.read(imagesProvider.notifier).clearSelection();
    }
  }
}
