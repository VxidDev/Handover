// lib/widgets/image_viewer.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  final List<String> images;
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Swipeable images
            PageView.builder(
              controller: _controller,
              onPageChanged: (i) {
                setState(() => _currentIndex = i);
                HapticFeedback.selectionClick();
              },
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Center(
                    child: Hero(
                      tag: 'image-$index',
                      child: Image.network(
                        widget.images[index],
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: Colors.white38,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Close button (top-left)
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: Semantics(
                button: true,
                label: 'Close image viewer',
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 22),
                  ),
                ),
              ),
            ),

            // Counter (top-right)
            if (widget.images.length > 1)
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // Dot indicators (bottom)
            if (widget.images.length > 1)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 32,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(widget.images.length, (i) {
                    final isActive = i == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: isActive ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
