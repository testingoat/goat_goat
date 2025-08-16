import 'package:flutter/material.dart';

/// Analytics Chart Widget for displaying data visualizations
/// Zero-risk implementation for Phase 3 analytics features
class AnalyticsChart extends StatelessWidget {
  final String title;
  final List<ChartData> data;
  final ChartType type;
  final Color primaryColor;
  final double height;

  const AnalyticsChart({
    Key? key,
    required this.title,
    required this.data,
    this.type = ChartType.line,
    this.primaryColor = Colors.blue,
    this.height = 200,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: height,
              child: _buildChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    switch (type) {
      case ChartType.line:
        return _buildLineChart();
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.pie:
        return _buildPieChart();
    }
  }

  Widget _buildLineChart() {
    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);
    final minValue = data.map((e) => e.value).reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    return CustomPaint(
      size: Size.infinite,
      painter: LineChartPainter(
        data: data,
        color: primaryColor,
        maxValue: maxValue,
        minValue: minValue,
        range: range,
      ),
    );
  }

  Widget _buildBarChart() {
    final maxValue = data.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: data.asMap().entries.map((entry) {
        final index = entry.key;
        final item = entry.value;
        final height = (item.value / maxValue) * this.height * 0.8;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.8),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: const TextStyle(fontSize: 10),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPieChart() {
    final total = data.fold<double>(0, (sum, item) => sum + item.value);
    
    return Center(
      child: SizedBox(
        width: height * 0.8,
        height: height * 0.8,
        child: CustomPaint(
          painter: PieChartPainter(
            data: data,
            total: total,
            colors: _generateColors(),
          ),
        ),
      ),
    );
  }

  List<Color> _generateColors() {
    return data.asMap().entries.map((entry) {
      final index = entry.key;
      final hue = (index * 360 / data.length) % 360;
      return HSVColor.fromAHSV(1.0, hue, 0.7, 0.8).toColor();
    }).toList();
  }
}

class ChartData {
  final String label;
  final double value;
  final DateTime? timestamp;

  ChartData({
    required this.label,
    required this.value,
    this.timestamp,
  });
}

enum ChartType { line, bar, pie }

class LineChartPainter extends CustomPainter {
  final List<ChartData> data;
  final Color color;
  final double maxValue;
  final double minValue;
  final double range;

  LineChartPainter({
    required this.data,
    required this.color,
    required this.maxValue,
    required this.minValue,
    required this.range,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    
    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i].value - minValue) / range) * size.height;
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Draw points
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final y = size.height - ((data[i].value - minValue) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class PieChartPainter extends CustomPainter {
  final List<ChartData> data;
  final double total;
  final List<Color> colors;

  PieChartPainter({
    required this.data,
    required this.total,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    double startAngle = -90 * (3.14159 / 180); // Start from top

    for (int i = 0; i < data.length; i++) {
      final sweepAngle = (data[i].value / total) * 2 * 3.14159;
      
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
