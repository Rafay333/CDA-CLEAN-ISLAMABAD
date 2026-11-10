import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';

/// Front-camera capture for face HR.
/// Registration: 3 HD photos a few seconds apart — hold steady, face fills the frame,
/// brighter light (no extra poses).
/// Attendance burst: one **5 second** countdown; 3 frames are taken automatically at
/// roughly the start, middle and end (server analyses natural movement + anti-spoof).
class FaceCapturePage extends StatefulWidget {
  const FaceCapturePage({super.key, required this.title, required this.burst});

  final String title;
  final bool burst;

  /// Length of the single attendance countdown; frames at ~0 s, ~2.5 s and ~5 s.
  static const attendanceCountdownSeconds = 5;

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
  int _count = 3;
  bool _pause = false;
  bool _running = false;
  final List<Uint8List> _taken = [];

  /// Registration: same clear look three times. No pose changes — brighter light,
  /// face filling the frame, phone held steady (server checks quality + same person).
  static const _registrationSteps = [
    'Photo 1 of 3 — Hold steady, face fills the frame',
    'Photo 2 of 3 — Brighter light, look straight at the camera',
    'Photo 3 of 3 — Keep still, face clearly visible',
  ];

  static String _stepInfo(int photoIndex) =>
      _registrationSteps[photoIndex.clamp(0, _registrationSteps.length - 1)];

  /// Attendance burst (API phone UX): one 5 s countdown, no instructions to the worker.
  static const _burstInfo = 'Hold still, taking attendance…';

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<CameraController> _open(CameraDescription camera) async {
    // Registration: 1080p is enough for dlib and uploads in seconds, not 4K.
    // Attendance stays at 720p so the queue is not waiting on a huge upload.
    final presets = widget.burst
        ? const [ResolutionPreset.high, ResolutionPreset.medium]
        : const [ResolutionPreset.veryHigh, ResolutionPreset.high, ResolutionPreset.medium];
    for (var i = 0; i < presets.length; i++) {
      final controller = CameraController(
        camera,
        presets[i],
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      try {
        await controller.initialize();
        try {
          await controller.setFocusMode(FocusMode.auto);
          await controller.setFlashMode(FlashMode.off);
        } catch (_) {}
        if (!widget.burst) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        }
        return controller;
      } catch (_) {
        await controller.dispose();
        if (i == presets.length - 1) rethrow;
      }
    }
    throw StateError('Camera could not be started.');
  }

  Future<void> _start() async {
    try {
      await Future<void>.delayed(const Duration(milliseconds: 150));
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _info = 'No camera was found on this device.');
        return;
      }
      final camera = cameras.cast<CameraDescription?>().firstWhere(
        (item) => item!.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      )!;
      final controller = await _open(camera);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _camera = controller;
        _info = widget.burst ? _burstInfo : _stepInfo(0);
        _count = widget.burst ? FaceCapturePage.attendanceCountdownSeconds : 3;
      });
      if (widget.burst) {
        await _runAttendanceBurst();
      } else {
        _countdownRegistration();
      }
    } catch (error) {
      if (mounted) setState(() => _info = 'Camera error: $error');
    }
  }

  /// Attendance: one 5 s countdown, 3 frames taken automatically at ~0 / 2.5 / 5 s.
  Future<void> _runAttendanceBurst() async {
    if (_running) return;
    _running = true;
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      _running = false;
      return;
    }

    const total = Duration(seconds: FaceCapturePage.attendanceCountdownSeconds);
    const shotTimes = [Duration.zero, Duration(milliseconds: 2500), total];

    setState(() {
      _pause = false;
      _count = FaceCapturePage.attendanceCountdownSeconds;
      _info = _burstInfo;
    });

    final started = DateTime.now();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final left = total - DateTime.now().difference(started);
      final seconds = (left.inMilliseconds / 1000).ceil().clamp(1, total.inSeconds);
      if (seconds != _count) setState(() => _count = seconds);
      if (left <= Duration.zero) timer.cancel();
    });

    for (var i = 0; i < shotTimes.length; i++) {
      final wait = shotTimes[i] - DateTime.now().difference(started);
      if (wait > Duration.zero) await Future<void>.delayed(wait);
      if (!mounted) return;
      try {
        final shot = await camera.takePicture();
        _taken.add(await shot.readAsBytes());
        if (!mounted) return;
        setState(() => _info = '$_burstInfo ${_taken.length}/3');
      } catch (error) {
        _timer?.cancel();
        if (mounted) setState(() => _info = 'Capture error: $error');
        _running = false;
        return;
      }
    }

    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _pause = true;
      _info = 'Attendance frames captured';
    });
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _running = false;
    if (mounted) Navigator.of(context).pop(List<Uint8List>.from(_taken));
  }

  void _countdownRegistration() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final camera = _camera;
      if (camera == null || !camera.value.isInitialized) return;
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
          _info = 'Photo $saved saved.\nNext: ${_stepInfo(saved)}';
        });
        await Future<void>.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        setState(() {
          _pause = false;
          _count = 3;
          _info = _stepInfo(saved);
        });
        _countdownRegistration();
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
