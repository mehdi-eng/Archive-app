import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraCapturePage extends StatefulWidget {
  final CameraDescription camera;

  const CameraCapturePage({super.key, required this.camera});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage> {
  late CameraController _controller;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
      //imageFormatGroup: ImageFormatGroup.yuv420,
      imageFormatGroup: ImageFormatGroup.bgra8888 // higher quality color format

    );

    _controller.initialize().then((_) {
      if (mounted) {
        setState(() => _isReady = true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose().then((_) {
      debugPrint('CameraController disposed');
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      body: Stack(
        children: [
          // Camera preview fills the whole screen
          Positioned.fill(
            child: CameraPreview(_controller),
          ),

          // Floating button at the bottom center
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Center(
              child: FloatingActionButton(
                onPressed: () async {
                  try {
                    if (!_controller.value.isInitialized) return;
                    final image = await _controller.takePicture();
                    if (mounted) {
                      Navigator.pop(context, image); // returns XFile
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Camera error: $e')),
                      );
                    }
                    Navigator.pop(context, null);
                  }
                },
                child: const Icon(Icons.camera),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
