import 'package:flutter/material.dart';
import 'dart:math';

class SplashScreen extends StatefulWidget {
  final Widget nextScreen;
  const SplashScreen({Key? key, required this.nextScreen}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const cream = Color(0xFFF8F6F0);
  static const gold = Color(0xFFE8A820);
  static const darkBrown = Color(0xFF1C1207);

  late AnimationController _hexController;
  late AnimationController _combController;
  late AnimationController _pingController;
  late AnimationController _textController;

  late Animation<double> _hexFade;
  late Animation<double> _combFade;
  late Animation<double> _pingAnim;
  late Animation<double> _textFade;

  @override
  void initState() {
    super.initState();

    _hexController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );
    _hexFade = CurvedAnimation(parent: _hexController, curve: Curves.easeIn);

    _combController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    );
    _combFade = CurvedAnimation(parent: _combController, curve: Curves.easeOut);

    _pingController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 900),
    );
    _pingAnim = CurvedAnimation(parent: _pingController, curve: Curves.easeOut);

    _textController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 600),
    );
    _textFade = CurvedAnimation(parent: _textController, curve: Curves.easeIn);

    _startSequence();
  }

  Future<void> _startSequence() async {
    await _hexController.forward();
    await Future.delayed(Duration(milliseconds: 150));
    await _combController.forward();
    await Future.delayed(Duration(milliseconds: 100));
    await _pingController.forward();
    await _pingController.reverse();
    await Future.delayed(Duration(milliseconds: 150));
    await _pingController.forward();
    await _textController.forward();
    await Future.delayed(Duration(milliseconds: 900));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => widget.nextScreen,
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: Duration(milliseconds: 400),
        ),
      );
    }
  }

  @override
  void dispose() {
    _hexController.dispose();
    _combController.dispose();
    _pingController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: cream,
      body: Stack(
        children: [
          // 벌집 + 핑 캔버스
          AnimatedBuilder(
            animation: Listenable.merge([_hexFade, _combFade, _pingAnim]),
            builder: (context, _) {
              return CustomPaint(
                painter: SplashPainter(
                  hexFade: _hexFade.value,
                  combFade: _combFade.value,
                  pingAnim: _pingAnim.value,
                  screenSize: size,
                ),
                size: size,
              );
            },
          ),
          // DETECTED 텍스트 (핑 셀 옆)
          AnimatedBuilder(
            animation: _combFade,
            builder: (context, _) {
              // 핑 셀 위치 계산 (SplashPainter와 동일)
              final cx = size.width / 2;
              final cy = size.height * 0.40;
              const r = 44.0;
              final w = r * sqrt(3);
              const vGap = r * 1.5;
              final pingCell = Offset(cx + w / 2, cy - vGap);

              return Positioned(
                left: pingCell.dx + r + 8,
                top: pingCell.dy - 20,
                child: Opacity(
                  opacity: _combFade.value,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DETECTED',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: Color(0xFFC62828).withOpacity(0.8),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '93% confidence',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 9,
                          letterSpacing: 0.5,
                          color: Color(0xFFC62828).withOpacity(0.5),
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          // HIVEMIND 텍스트
          Positioned(
            bottom: size.height * 0.15,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _textFade,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'HIVEMIND',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 24,
                      letterSpacing: 7,
                      color: darkBrown,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  SizedBox(height: 10),
                  Center(
                    child: Container(width: 80, height: 0.8, color: gold),
                  ),
                  SizedBox(height: 10),
                  Text(
                    'HIVE MONITORING',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 10,
                      letterSpacing: 3,
                      color: Color(0xFFA08040),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SplashPainter extends CustomPainter {
  final double hexFade;
  final double combFade;
  final double pingAnim;
  final Size screenSize;

  static const gold = Color(0xFFE8A820);
  static const darkBrown = Color(0xFF1C1207);
  static const kRed = Color(0xFFC62828);

  SplashPainter({
    required this.hexFade,
    required this.combFade,
    required this.pingAnim,
    required this.screenSize,
  });

  void _drawHex(Canvas canvas, Offset center, double r, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60 - 90) * pi / 180;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);
      if (i == 0)
        path.moveTo(x, y);
      else
        path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.40;
    final center = Offset(cx, cy);

    // SVG 컨셉과 동일한 크기
    const r = 44.0;
    final w = r * sqrt(3);
    const vGap = r * 1.5;

    // ── 벌집 셀 위치 (SVG 컨셉과 동일한 배열) ──
    final cells = [
      // row 1
      Offset(-w, -vGap * 2),
      Offset(0, -vGap * 2),
      Offset(w, -vGap * 2),
      // row 2
      Offset(-w / 2, -vGap),
      Offset(w / 2, -vGap),   // ← 핑 찍힐 셀 (우상단)
      // row 3 좌우
      Offset(-w, 0),
      Offset(w, 0),
      // row 4
      Offset(-w / 2, vGap),   // ← 골드 작은 핑 셀 (좌하단)
      Offset(w / 2, vGap),
      // row 5
      Offset(-w, vGap * 2),
      Offset(0, vGap * 2),
      Offset(w, vGap * 2),
    ];

    // 핑 셀 / 골드 핑 셀
    final pingOffset = Offset(w / 2, -vGap);
    final goldPingOffset = Offset(-w / 2, vGap);
    final pingCell = center + pingOffset;
    final goldPingCell = center + goldPingOffset;

    // ── 배경 벌집 셀 ──
    for (final offset in cells) {
      final cellCenter = center + offset;
      final isPingCell = offset == pingOffset;
      final isGoldPingCell = offset == goldPingOffset;

      if (isPingCell || isGoldPingCell) continue; // 별도 처리

      // 위쪽 셀은 좀 더 흐리게
      final baseOpacity = offset.dy < 0 ? 0.13 : 0.10;
      _drawHex(
        canvas,
        cellCenter,
        r - 2,
        Paint()
          ..color = gold.withOpacity(baseOpacity * combFade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // ── 빨간 핑 셀 (우상단) ──
    _drawHex(
      canvas,
      pingCell,
      r - 2,
      Paint()
        ..color = kRed.withOpacity(0.07 * combFade)
        ..style = PaintingStyle.fill,
    );
    _drawHex(
      canvas,
      pingCell,
      r - 2,
      Paint()
        ..color = kRed.withOpacity(0.55 * combFade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ── 골드 작은 핑 셀 (좌하단) ──
    _drawHex(
      canvas,
      goldPingCell,
      r - 2,
      Paint()
        ..color = gold.withOpacity(0.05 * combFade)
        ..style = PaintingStyle.fill,
    );
    _drawHex(
      canvas,
      goldPingCell,
      r - 2,
      Paint()
        ..color = gold.withOpacity(0.25 * combFade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );

    // ── 빨간 핑 애니메이션 ──
    if (pingAnim > 0) {
      final fadeOut = 1.0 - pingAnim * 0.8;

      // 중심 점
      canvas.drawCircle(
        pingCell,
        4.5,
        Paint()..color = kRed.withOpacity(0.9),
      );
      // 링 3개
      for (final ring in [
        (14.0, 0.55),
        (26.0, 0.3),
        (38.0, 0.15),
      ]) {
        canvas.drawCircle(
          pingCell,
          ring.$1 * pingAnim,
          Paint()
            ..color = kRed.withOpacity(ring.$2 * fadeOut)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
      }
    }

    // ── 골드 작은 핑 점 ──
    if (combFade > 0) {
      canvas.drawCircle(
        goldPingCell,
        3,
        Paint()..color = gold.withOpacity(0.5 * combFade),
      );
      canvas.drawCircle(
        goldPingCell,
        8,
        Paint()
          ..color = gold.withOpacity(0.2 * combFade)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.6,
      );
    }

    // ── 중앙 메인 헥사곤 ──
    _drawHex(
      canvas,
      center,
      r - 2,
      Paint()
        ..color = darkBrown.withOpacity(hexFade)
        ..style = PaintingStyle.fill,
    );
    _drawHex(
      canvas,
      center,
      r - 2,
      Paint()
        ..color = gold.withOpacity(hexFade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // 내부 작은 헥사곤
    _drawHex(
      canvas,
      center,
      r - 14,
      Paint()
        ..color = gold.withOpacity(0.45 * hexFade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
  }

  @override
  bool shouldRepaint(SplashPainter old) =>
      old.hexFade != hexFade ||
      old.combFade != combFade ||
      old.pingAnim != pingAnim;
}