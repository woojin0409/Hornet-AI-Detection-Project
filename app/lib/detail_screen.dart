import 'package:flutter/material.dart';
import 'dart:convert';

class DetailScreen extends StatelessWidget {
  final int hiveId;
  final String status;
  final double confidence;
  final String? spectrogramBase64;

  const DetailScreen({
    required this.hiveId,
    required this.status,
    this.confidence = 0.0,
    this.spectrogramBase64,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('벌통 $hiveId 상세')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상태 표시
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: status == '말벌감지' ? Colors.red[50] : Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    status == '말벌감지' ? '⚠️ 말벌 감지됨!' : '✅ 정상',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: status == '말벌감지' ? Colors.red : Colors.green,
                    ),
                  ),
                  if (confidence > 0)
                    Text(
                      '탐지 확률: ${(confidence * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 20),

            // Waveform
            Text('Waveform', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(painter: WaveformPainter()),
            ),
            SizedBox(height: 20),

            // FFT
            Text('FFT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomPaint(painter: FFTPainter()),
            ),
            SizedBox(height: 20),

            // Spectrogram
            Text('Spectrogram', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: spectrogramBase64 != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(
                        base64Decode(spectrogramBase64!),
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(
                        '데이터 없음',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < size.width.toInt(); i++) {
      final y = size.height / 2 +
          30 * (i % 40 < 20 ? (i % 20 - 10) / 10 : (10 - i % 20) / 10);
      if (i == 0) path.moveTo(i.toDouble(), y);
      else path.lineTo(i.toDouble(), y);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FFTPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 3;

    final barWidth = size.width / 20;
    final heights = [20, 40, 60, 80, 100, 90, 70, 50, 30, 20,
                     15, 35, 55, 75, 95, 85, 65, 45, 25, 10];

    for (int i = 0; i < 20; i++) {
      final x = i * barWidth;
      final h = heights[i].toDouble();
      canvas.drawRect(
        Rect.fromLTWH(x + 2, size.height - h, barWidth - 4, h),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}