import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/theme_controller.dart';
import '../theme/neomorphic_theme.dart';
import '../widgets/neomorphic_container.dart';
import '../widgets/tap_scale.dart';

enum _Phase { idle, latency, download, upload, done, error }

enum _Unit { mbps, mbPerSec }

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> {
  _Phase _phase = _Phase.idle;
  _Unit _unit = _Unit.mbps;

  int? _latencyMs;
  double _downloadMbps = 0;
  double _uploadMbps = 0;
  double _liveMbps = 0;
  double _overallProgress = 0;
  String? _error;
  String? _isp;

  Timer? _uploadAnimTimer;

  static const double _scaleMax = 150;

  static const _downloadUrls = [
    'https://speed.cloudflare.com/__down?bytes=25000000',
    'https://proof.ovh.net/files/10Mb.dat',
  ];

  static const _uploadUrls = [
    'https://speed.cloudflare.com/__up',
    'https://httpbin.org/post',
  ];

  @override
  void initState() {
    super.initState();
    _fetchIsp();
  }

  @override
  void dispose() {
    _uploadAnimTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchIsp() async {
    try {
      final client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 6);
      final request = await client.getUrl(Uri.parse('https://ipapi.co/json/'));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);
      final data = jsonDecode(body) as Map<String, dynamic>;
      final org = data['org'] as String?;
      if (mounted && org != null && org.isNotEmpty) {
        setState(() => _isp = org);
      }
    } catch (_) {}
  }

  double _clampNeedle(double mbps) => (mbps / _scaleMax).clamp(0, 1).toDouble();

  Future<void> _runTest() async {
    _uploadAnimTimer?.cancel();
    setState(() {
      _phase = _Phase.latency;
      _latencyMs = null;
      _downloadMbps = 0;
      _uploadMbps = 0;
      _liveMbps = 0;
      _overallProgress = 0.02;
      _error = null;
    });

    final latency = await _measureLatency();
    if (!mounted) return;
    setState(() {
      _latencyMs = latency;
      _overallProgress = 0.08;
      _phase = _Phase.download;
    });

    double? download;
    for (final url in _downloadUrls) {
      try {
        download = await _measureDownload(url);
        break;
      } catch (_) {
        continue;
      }
    }

    if (download == null) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.error;
        _error = 'Could not reach any test server. Check your connection.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _downloadMbps = download!;
        _liveMbps = download;
        _overallProgress = 0.6;
        _phase = _Phase.upload;
      });
    }

    _animateUploadNeedle(targetGuess: download * 0.4);

    double? upload;
    for (final url in _uploadUrls) {
      try {
        upload = await _measureUpload(url);
        break;
      } catch (_) {
        continue;
      }
    }
    _uploadAnimTimer?.cancel();

    if (!mounted) return;
    setState(() {
      _uploadMbps = upload ?? 0;
      _liveMbps = _downloadMbps;
      _overallProgress = 1;
      _phase = _Phase.done;
    });
  }

  void _animateUploadNeedle({required double targetGuess}) {
    final start = DateTime.now();
    final guess = targetGuess <= 0 ? 8.0 : targetGuess;
    _uploadAnimTimer = Timer.periodic(const Duration(milliseconds: 120), (t) {
      if (!mounted || _phase != _Phase.upload) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(start).inMilliseconds / 1000.0;
      final fraction = 1 - math.exp(-elapsed / 1.6);
      setState(() {
        _liveMbps = guess * fraction;
        _overallProgress = 0.6 + (0.38 * fraction.clamp(0, 1).toDouble());
      });
    });
  }

  Future<int?> _measureLatency() async {
    const hosts = ['1.1.1.1', '8.8.8.8'];
    for (final host in hosts) {
      final samples = <int>[];
      for (var i = 0; i < 3; i++) {
        try {
          final stopwatch = Stopwatch()..start();
          final socket = await Socket.connect(
            host,
            443,
            timeout: const Duration(seconds: 3),
          );
          stopwatch.stop();
          socket.destroy();
          samples.add(stopwatch.elapsedMilliseconds);
        } catch (_) {
          continue;
        }
      }
      if (samples.isNotEmpty) {
        samples.sort();
        return samples.first;
      }
    }
    return null;
  }

  Future<double> _measureDownload(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();

      final total = response.contentLength > 0 ? response.contentLength : null;
      var received = 0;
      var sinceSample = 0;
      final stopwatch = Stopwatch()..start();
      var lastSampleMs = 0;

      await for (final chunk in response) {
        received += chunk.length;
        sinceSample += chunk.length;
        final nowMs = stopwatch.elapsedMilliseconds;
        if (nowMs - lastSampleMs > 150 && mounted) {
          final deltaSec = (nowMs - lastSampleMs) / 1000.0;
          if (deltaSec > 0) {
            final instMbps = ((sinceSample * 8) / deltaSec) / 1000000;
            final progressFrac = total != null
                ? (received / total).clamp(0, 1)
                : (nowMs / 8000).clamp(0, 1);
            setState(() {
              _liveMbps = instMbps.clamp(0, _scaleMax * 1.2).toDouble();
              _overallProgress = 0.08 + (0.52 * progressFrac.toDouble());
            });
          }
          sinceSample = 0;
          lastSampleMs = nowMs;
        }
        if (stopwatch.elapsed > const Duration(seconds: 12)) break;
      }
      stopwatch.stop();

      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      if (seconds <= 0 || received == 0) {
        throw Exception('No data received');
      }
      final bits = received * 8;
      return (bits / seconds) / 1000000;
    } finally {
      client.close(force: true);
    }
  }

  Future<double> _measureUpload(String url) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final payload = Uint8List(4 * 1000 * 1000);
      final request = await client.postUrl(Uri.parse(url));
      request.headers.set('Content-Type', 'application/octet-stream');
      request.contentLength = payload.length;

      final stopwatch = Stopwatch()..start();
      request.add(payload);
      final response = await request.close();
      await response.drain();
      stopwatch.stop();

      final seconds = stopwatch.elapsedMilliseconds / 1000.0;
      if (seconds <= 0) {
        throw Exception('Upload timing failed');
      }
      final bits = payload.length * 8;
      return (bits / seconds) / 1000000;
    } finally {
      client.close(force: true);
    }
  }

  void _toggleUnit() {
    setState(() {
      _unit = _unit == _Unit.mbps ? _Unit.mbPerSec : _Unit.mbps;
    });
  }

  String _format(double mbps) {
    if (_unit == _Unit.mbPerSec) {
      return (mbps / 8).toStringAsFixed(1);
    }
    return mbps.toStringAsFixed(1);
  }

  String get _unitLabel => _unit == _Unit.mbps ? 'Mbps' : 'MB/s';

  String get _statusText {
    switch (_phase) {
      case _Phase.latency:
        return 'Checking latency';
      case _Phase.download:
        return 'Testing the download speed';
      case _Phase.upload:
        return 'Testing the upload speed';
      case _Phase.error:
        return _error ?? 'Something went wrong';
      default:
        return ' ';
    }
  }

  bool get _isTesting =>
      _phase == _Phase.latency ||
      _phase == _Phase.download ||
      _phase == _Phase.upload;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final colors = ThemeController.instance.colors;
        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.arrow_back_rounded,
                          color: colors.textPrimary,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Speed Test',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _toggleUnit,
                        icon: Icon(
                          Icons.swap_vert_rounded,
                          color: colors.textFaint,
                        ),
                        tooltip: 'Switch unit',
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _StatRow(
                    latencyMs: _latencyMs,
                    downloadLabel: _downloadMbps > 0
                        ? _format(_downloadMbps)
                        : null,
                    uploadLabel: _uploadMbps > 0 ? _format(_uploadMbps) : null,
                    unitLabel: _unitLabel,
                    colors: colors,
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SpeedometerGauge(
                            needleFraction: _clampNeedle(_liveMbps),
                            overallProgress: _overallProgress,
                            valueLabel: _format(_liveMbps),
                            unitLabel: _unitLabel,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            _isp ?? ' ',
                            style: TextStyle(
                              color: colors.textFaint,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _statusText,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _phase == _Phase.error
                                  ? const Color(0xFFE85D75)
                                  : colors.textFaint,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 22),
                          TapScale(
                            onTap: _isTesting ? null : _runTest,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [colors.videoStart, colors.videoEnd],
                                ),
                                boxShadow: _isTesting
                                    ? []
                                    : [
                                        BoxShadow(
                                          color: colors.shadowDark,
                                          offset: const Offset(5, 5),
                                          blurRadius: 12,
                                        ),
                                        BoxShadow(
                                          color: colors.shadowLight,
                                          offset: const Offset(-5, -5),
                                          blurRadius: 12,
                                        ),
                                      ],
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _isTesting
                                    ? 'Testing...'
                                    : (_phase == _Phase.done
                                          ? 'Test Again'
                                          : 'Start Test'),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatRow extends StatelessWidget {
  final int? latencyMs;
  final String? downloadLabel;
  final String? uploadLabel;
  final String unitLabel;
  final NeoColors colors;

  const _StatRow({
    required this.latencyMs,
    required this.downloadLabel,
    required this.uploadLabel,
    required this.unitLabel,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatItem(
            icon: Icons.swap_vert_rounded,
            iconColor: colors.textFaint,
            label: 'Network\nlatency',
            value: latencyMs != null ? '$latencyMs' : '--',
            unit: 'ms',
            colors: colors,
          ),
        ),
        _StatDivider(colors: colors),
        Expanded(
          child: _StatItem(
            icon: Icons.arrow_downward_rounded,
            iconColor: const Color(0xFF4ADE80),
            label: 'Download\nspeed',
            value: downloadLabel ?? '--',
            unit: unitLabel,
            colors: colors,
          ),
        ),
        _StatDivider(colors: colors),
        Expanded(
          child: _StatItem(
            icon: Icons.arrow_upward_rounded,
            iconColor: const Color(0xFFE85D75),
            label: 'Upload\nspeed',
            value: uploadLabel ?? '--',
            unit: unitLabel,
            colors: colors,
          ),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  final NeoColors colors;
  const _StatDivider({required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 36,
      color: colors.shadowDark.withValues(alpha: 0.4),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String unit;
  final NeoColors colors;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.unit,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: iconColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colors.textFaint,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: TextStyle(
                color: colors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SpeedometerGauge extends StatelessWidget {
  final double needleFraction;
  final double overallProgress;
  final String valueLabel;
  final String unitLabel;

  const _SpeedometerGauge({
    required this.needleFraction,
    required this.overallProgress,
    required this.valueLabel,
    required this.unitLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ThemeController.instance.colors;
    return NeomorphicContainer(
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(999),
      intensity: 8,
      child: SizedBox(
        width: 240,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size(240, 240),
              painter: _GaugePainter(
                needleFraction: needleFraction,
                overallProgress: overallProgress,
                trackColor: colors.shadowDark.withValues(alpha: 0.35),
                tickColor: colors.textFaint.withValues(alpha: 0.5),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valueLabel,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  unitLabel,
                  style: TextStyle(
                    color: colors.textFaint,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double needleFraction;
  final double overallProgress;
  final Color trackColor;
  final Color tickColor;

  static const double _startAngle = 0.75 * math.pi;
  static const double _sweepAngle = 1.5 * math.pi;
  static const Color _accent = Color(0xFF34D8B8);

  _GaugePainter({
    required this.needleFraction,
    required this.overallProgress,
    required this.trackColor,
    required this.tickColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    _drawOuterProgressRing(canvas, center, radius);
    _drawTicks(canvas, center, radius);
    _drawFillArc(canvas, center, radius);
    _drawNeedle(canvas, center, radius);
  }

  void _drawOuterProgressRing(Canvas canvas, Offset center, double radius) {
    final ringRadius = radius - 4;
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(center, ringRadius, trackPaint);

    if (overallProgress <= 0) return;
    final angle =
        (-0.5 * math.pi) + (overallProgress.clamp(0, 1) * 2 * math.pi);
    final dot = Offset(
      center.dx + ringRadius * math.cos(angle),
      center.dy + ringRadius * math.sin(angle),
    );
    canvas.drawCircle(dot, 5, Paint()..color = _accent);
    canvas.drawCircle(
      dot,
      8,
      Paint()
        ..color = _accent.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    const tickCount = 32;
    final outer = radius - 16;
    final innerMinor = outer - 8;
    final innerMajor = outer - 14;
    for (var i = 0; i <= tickCount; i++) {
      final t = i / tickCount;
      final angle = _startAngle + (_sweepAngle * t);
      final isMajor = i % 4 == 0;
      final from = Offset(
        center.dx + (isMajor ? innerMajor : innerMinor) * math.cos(angle),
        center.dy + (isMajor ? innerMajor : innerMinor) * math.sin(angle),
      );
      final to = Offset(
        center.dx + outer * math.cos(angle),
        center.dy + outer * math.sin(angle),
      );
      final active = t <= needleFraction.clamp(0, 1);
      final paint = Paint()
        ..color = active ? _accent : tickColor
        ..strokeWidth = isMajor ? 2.2 : 1.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(from, to, paint);
    }
  }

  void _drawFillArc(Canvas canvas, Offset center, double radius) {
    final arcRadius = radius - 30;
    final rect = Rect.fromCircle(center: center, radius: arcRadius);
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, track);

    if (needleFraction <= 0) return;
    final fillPaint = Paint()
      ..color = _accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      rect,
      _startAngle,
      _sweepAngle * needleFraction.clamp(0, 1).toDouble(),
      false,
      fillPaint,
    );
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    final angle = _startAngle + (_sweepAngle * needleFraction.clamp(0, 1));
    final tip = Offset(
      center.dx + (radius - 44) * math.cos(angle),
      center.dy + (radius - 44) * math.sin(angle),
    );
    final baseAngle1 = angle + (math.pi / 2);
    final baseAngle2 = angle - (math.pi / 2);
    const baseWidth = 6.0;
    final base1 = Offset(
      center.dx + baseWidth * math.cos(baseAngle1),
      center.dy + baseWidth * math.sin(baseAngle1),
    );
    final base2 = Offset(
      center.dx + baseWidth * math.cos(baseAngle2),
      center.dy + baseWidth * math.sin(baseAngle2),
    );

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(base1.dx, base1.dy)
      ..lineTo(base2.dx, base2.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = _accent);
    canvas.drawCircle(center, 7, Paint()..color = _accent);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) =>
      oldDelegate.needleFraction != needleFraction ||
      oldDelegate.overallProgress != overallProgress;
}
