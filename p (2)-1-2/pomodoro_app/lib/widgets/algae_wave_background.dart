import 'dart:math' as math;
import 'package:flutter/material.dart';

class AlgaeWaveBackground extends StatefulWidget {
  final Widget child;
  final int fishCount;

  const AlgaeWaveBackground({
    super.key,
    required this.child,
    this.fishCount = 5,
  });

  @override
  State<AlgaeWaveBackground> createState() => _AlgaeWaveBackgroundState();
}

class _AlgaeWaveBackgroundState extends State<AlgaeWaveBackground>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _algaeController;
  late List<AnimationController> _fishControllers;
  late List<Offset> _fishPositions;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    final random = math.Random();

    // Wave animation
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Algae swaying animation
    _algaeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Fish animations
    _fishControllers = List.generate(
      widget.fishCount,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(seconds: 15 + random.nextInt(10)),
      )..repeat(),
    );

    // Fish positions at different depths
    _fishPositions = List.generate(
      widget.fishCount,
      (index) {
        final depth = 0.2 + random.nextDouble() * 0.5; // y: 0.2 to 0.7
        return Offset(random.nextDouble(), depth);
      },
    );
  }

  @override
  void dispose() {
    _waveController.dispose();
    _algaeController.dispose();
    for (var controller in _fishControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Ocean gradient background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1B4B6C), // Dark ocean blue
                Color(0xFF0A2A3F), // Deep ocean blue
              ],
            ),
          ),
        ),

        // Animated waves and algae
        AnimatedBuilder(
          animation: Listenable.merge([_waveController, _algaeController]),
          builder: (context, child) {
            return CustomPaint(
              painter: AlgaeWavePainter(
                waveProgress: _waveController.value,
                algaeProgress: _algaeController.value,
              ),
              size: Size.infinite,
            );
          },
        ),

        // Swimming fish
        ...List.generate(widget.fishCount, (index) {
          return AnimatedBuilder(
            animation: _fishControllers[index],
            builder: (context, child) {
              final screenWidth = MediaQuery.of(context).size.width;
              final screenHeight = MediaQuery.of(context).size.height;

              final progress = _fishControllers[index].value;
              final xPos = progress * (screenWidth + 100) - 50;
              final yPos = _fishPositions[index].dy * screenHeight;

              return Positioned(
                left: xPos,
                top: yPos,
                child: Transform.scale(
                  scaleX: -1,
                  child: CustomPaint(
                    painter: FishPainter(),
                    size: const Size(40, 25),
                  ),
                ),
              );
            },
          );
        }),

        // Content
        widget.child,
      ],
    );
  }
}

class AlgaeWavePainter extends CustomPainter {
  final double waveProgress;
  final double algaeProgress;

  AlgaeWavePainter({
    required this.waveProgress,
    required this.algaeProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Paint for algae
    final algaePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF2E8B57), // Sea green
          const Color(0xFF3CB371), // Medium sea green
        ],
      ).createShader(
          Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3));

    // Draw multiple algae clusters
    for (var i = 0; i < 8; i++) {
      final xOffset = size.width * (i / 8);
      _drawAlgaeCluster(canvas, size, xOffset, algaePaint);
    }
  }

  void _drawAlgaeCluster(
      Canvas canvas, Size size, double xOffset, Paint paint) {
    final baseY = size.height;
    final random = math.Random(xOffset.toInt());

    for (var i = 0; i < 5; i++) {
      final path = Path();
      final startX = xOffset + random.nextDouble() * 60 - 30;
      final height = 50 + random.nextDouble() * 100;

      path.moveTo(startX, baseY);

      // Create wavy algae strand
      for (var y = 0; y < height; y += 10) {
        final waveOffset =
            math.sin((y / height) * math.pi * 2 + waveProgress * math.pi * 2) *
                (10 + algaeProgress * 5);

        path.quadraticBezierTo(
          startX + waveOffset,
          baseY - y - 5,
          startX,
          baseY - y - 10,
        );
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant AlgaeWavePainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress ||
        oldDelegate.algaeProgress != algaeProgress;
  }
}

class FishPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;

    final path = Path();

    // Fish body
    path.moveTo(0, size.height / 2);
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.2,
      size.width * 0.8,
      size.height * 0.2,
    );
    path.quadraticBezierTo(
      size.width,
      size.height / 2,
      size.width * 0.8,
      size.height * 0.8,
    );
    path.quadraticBezierTo(
      size.width * 0.3,
      size.height * 0.8,
      0,
      size.height / 2,
    );

    // Tail
    path.moveTo(size.width * 0.8, size.height * 0.2);
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height / 2,
      size.width * 0.8,
      size.height * 0.8,
    );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
