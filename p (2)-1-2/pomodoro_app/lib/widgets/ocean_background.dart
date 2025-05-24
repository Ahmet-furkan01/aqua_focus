import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'animated_ocean_background.dart';

class OceanBackground extends StatefulWidget {
  final Widget child;
  const OceanBackground({super.key, required this.child});

  @override
  State<OceanBackground> createState() => _OceanBackgroundState();
}

class _OceanBackgroundState extends State<OceanBackground>
    with TickerProviderStateMixin {
  late AnimationController _fishController;
  late AnimationController _bubblesController;

  @override
  void initState() {
    super.initState();
    _setupAnimationControllers();
  }

  void _setupAnimationControllers() {
    _fishController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _bubblesController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _fishController.dispose();
    _bubblesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.28, 0.55, 1.0],
              colors: [
                Color(0xFF06555E), // Koyu deniz mavisi
                Color(0xFF298690), // Orta ton deniz mavisi
                Color(0xFF5ECEDB), // Açık deniz mavisi
              ],
            ),
          ),
        ),
        // Swimming fish
        ...List.generate(15, (index) => _buildSwimmingFish(index)),
        // Bubbles
        ...List.generate(10, (index) => _buildBubble(index)),
        // Child widget
        widget.child,
      ],
    );
  }

  Widget _buildSwimmingFish(int index) {
    return AnimatedBuilder(
      animation: _fishController,
      builder: (context, child) {
        final random = math.Random(index);
        final size = random.nextDouble() * 15 + 10;
        final delay = random.nextDouble();
        final startY = random.nextDouble() * MediaQuery.of(context).size.height;

        final progress = (_fishController.value + delay) % 1.0;
        final xPos = MediaQuery.of(context).size.width * progress;
        final yOffset = math.sin(progress * math.pi * 2) * 20;

        return Positioned(
          left: xPos - size,
          top: startY + yOffset,
          child: Transform.scale(
            scaleX: -1,
            child: CustomPaint(
              painter: FishPainter(color: Colors.white.withOpacity(0.2)),
              size: Size(size, size * 0.6),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBubble(int index) {
    return AnimatedBuilder(
      animation: _bubblesController,
      builder: (context, child) {
        final random = math.Random(index);
        final size = random.nextDouble() * 8 + 4;
        final startX = random.nextDouble() * MediaQuery.of(context).size.width;
        final startY = MediaQuery.of(context).size.height + size;
        final speed = random.nextDouble() * 1000 + 500;
        final delay = random.nextDouble();

        final progress = (_bubblesController.value + delay) % 1.0;
        final yPos = startY - (progress * speed);
        final xOffset = math.sin(progress * math.pi * 4) * 10;

        return Positioned(
          left: startX + xOffset,
          top: yPos,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.1),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
