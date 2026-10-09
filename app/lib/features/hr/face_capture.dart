import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Front-camera capture copied from the attendance mobile app.
/// Registration takes 3 photos, 5 seconds apart. Attendance takes 3 photos in one countdown.
class FaceCapturePage extends StatefulWidget {
  const FaceCapturePage({super.key, required this.title, required this.burst});

  final String title;
  final bool burst;

  static Future<List<Uint8List>?> open(
    BuildContext context, {
    required String title,
    required bool burst,
  }) {
    return Navigator.of(context).push<List<Uint8List>>(
      MaterialPageRoute(builder: (_) => FaceCapturePage(title: title, burst: burst)),
    );
  }

  @override
  State<FaceCapturePage> createState() => _FaceCapturePageState();
}

class _FaceCapturePageState extends State<FaceCapturePage> with SingleTickerProviderStateMixin {
  CameraController? _camera;
  Timer? _timer;
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);
  String _info = 'Starting camera...';
  int _count = 5;
  bool _pause = false;
  bool _shooting = false;
  final List<Uint8List> _taken = [];

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _info = 'No camera was found on this device.');
        return;
      }
      final camera = cameras.cast<CameraDescription?>().firstWhere(
        (item) => item!.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      )!;
      final controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _info = widget.burst
            ? 'Look at the screen and blink naturally'
            : 'Photo 1 of 3 - look straight';
      });
      _countdown();
    } catch (error) {
      if (mounted) setState(() => _info = 'Camera error: $error');
    }
  }

  void _countdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final camera = _camera;
      if (camera == null || !camera.value.isInitialized) return;
      if (widget.burst) {
        if (_shooting) return;
        if (_count == 4 || _count == 2 || _count == 1) {
          _shooting = true;
          try {
            final shot = await camera.takePicture();
            _taken.add(await shot.readAsBytes());
          } catch (_) {}
          _shooting = false;
        }
        if (_count > 1) {
          if (mounted) setState(() => _count--);
          return;
        }
        timer.cancel();
        if (mounted) Navigator.of(context).pop(List<Uint8List>.from(_taken));
        return;
      }
      if (_count > 1) {
        setState(() => _count--);
        return;
      }
      timer.cancel();
      try {
        final shot = await camera.takePicture();
        _taken.add(await shot.readAsBytes());
        if (_taken.length >= 3) {
          if (mounted) Navigator.of(context).pop(List<Uint8List>.from(_taken));
          return;
        }
        if (!mounted) return;
        final saved = _taken.length;
        setState(() {
          _pause = true;
          _info = 'Photo $saved saved.\nGet ready for photo ${saved + 1} of 3...';
        });
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        setState(() {
          _pause = false;
          _count = 5;
          _info = 'Photo ${saved + 1} of 3 - look straight';
        });
        _countdown();
      } catch (error) {
        if (mounted) setState(() => _info = 'Capture error: $error');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scan.dispose();
    _camera?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final ready = camera != null && camera.value.isInitialized;
    return Scaffold(
      backgroundColor: AppColors.navy,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ready
                  ? CameraPreview(
                      camera,
                      child: _ScanOverlay(animation: _scan, flash: _pause),
                    )
                  : const CircularProgressIndicator(color: AppColors.white),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                Text(
                  _info,
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: AppColors.white, fontSize: 18),
                ),
                if (ready && !_pause)
                  Text(
                    '$_count',
                    style: AppType.title.copyWith(color: AppColors.white, fontSize: 56),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Face guide with a moving scan line, drawn over the live camera picture.
class _ScanOverlay extends StatelessWidget {
  const _ScanOverlay({required this.animation, required this.flash});

  final Animation<double> animation;
  final bool flash;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => CustomPaint(
          painter: _ScanPainter(progress: animation.value, flash: flash),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter({required this.progress, required this.flash});

  final double progress;
  final bool flash;

  @override
  void paint(Canvas canvas, Size size) {
    final color = flash ? AppColors.success : AppColors.lime;
    final ovalWidth = size.width * 0.58;
    final ovalHeight = size.height * 0.68;
    final oval = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.48),
      width: ovalWidth,
      height: ovalHeight,
    );

    // Dim everything outside the face area.
    final shade = Path()
      ..addRect(Offset.zero & size)
      ..addOval(oval)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(shade, Paint()..color = Colors.black.withValues(alpha: 0.35));

    // Face outline.
    canvas.drawOval(
      oval,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    // Scan line sweeping top to bottom inside the oval.
    final y = oval.top + oval.height * progress;
    final dy = (y - oval.center.dy) / (oval.height / 2);
    final half = (oval.width / 2) * math.sqrt(math.max(0, 1 - dy * dy));
    if (half > 1) {
      final line = Rect.fromLTRB(oval.center.dx - half, y - 2, oval.center.dx + half, y + 2);
      canvas.drawRect(
        Rect.fromLTRB(line.left, y - 28, line.right, y + 2),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0), color.withValues(alpha: 0.35)],
          ).createShader(Rect.fromLTRB(line.left, y - 28, line.right, y + 2)),
      );
      canvas.drawRect(line, Paint()..color = color);
    }

    // Corner ticks.
    final tick = Paint()
      ..color = color
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 22.0;
    final box = oval.inflate(14);
    for (final corner in [box.topLeft, box.topRight, box.bottomLeft, box.bottomRight]) {
      final sx = corner.dx == box.left ? 1 : -1;
      final sy = corner.dy == box.top ? 1 : -1;
      canvas.drawLine(corner, corner + Offset(len * sx, 0), tick);
      canvas.drawLine(corner, corner + Offset(0, len * sy), tick);
    }
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.progress != progress || old.flash != flash;
}
