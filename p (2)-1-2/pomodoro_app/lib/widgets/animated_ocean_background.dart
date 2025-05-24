import 'dart:math' as math;
import 'package:flutter/material.dart';

class AnimatedOceanBackground extends StatefulWidget {
  final Widget child;
  final int coralCount; // Tamamlanan pomodoro sayısına göre mercan sayısı
  final int fishCount; // Tamamlanan pomodoro sayısına göre balık sayısı

  const AnimatedOceanBackground({
    super.key,
    required this.child,
    this.coralCount = 5,
    this.fishCount = 3,
  });

  @override
  State<AnimatedOceanBackground> createState() =>
      _AnimatedOceanBackgroundState();
}

class _AnimatedOceanBackgroundState extends State<AnimatedOceanBackground>
    with TickerProviderStateMixin {
  late List<AnimationController> _coralControllers;
  late List<AnimationController> _fishControllers;
  late List<AnimationController> _causticsControllers;
  late List<Animation<double>> _coralAnimations;
  late List<Animation<double>> _fishAnimations;
  late List<Animation<double>> _causticsAnimations;
  late List<CoralData> _corals;
  late List<Offset> _fishPositions;
  late List<CausticsData> _caustics;

  final List<Color> _coralPalette = [
    const Color(0xFF1B4B6C), // Koyu deniz mavisi
    const Color(0xFF2D6C8C), // Derin mavi
    const Color(0xFF45505D), // Koyu gri mavi
    const Color(0xFF8B4513), // Kahverengi mercan
    const Color(0xFF7B3F00), // Koyu kahve
    const Color(0xFF614051), // Bordo
    const Color(0xFF4A6670), // Gri yeşil
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    final random = math.Random();

    // Mercan verileri ve animasyonları
    _corals = [];
    _coralControllers = [];
    _coralAnimations = [];

    // Mercan sayısını artır ve düzenli yerleştir
    final totalCorals = widget.coralCount * 3;
    final rowCount = 3; // Kaç sıra mercan olacak
    final coralsPerRow = (totalCorals / rowCount).ceil();

    for (int row = 0; row < rowCount; row++) {
      for (int col = 0; col < coralsPerRow; col++) {
        if (_corals.length >= totalCorals) break;

        // Mercanları alt kısımda düzenli dağıt
        final type = CoralType.values[random.nextInt(CoralType.values.length)];
        final position = Offset(
          0.1 +
              (col * 0.8 / coralsPerRow) +
              (random.nextDouble() * 0.05), // x: düzenli aralıklarla
          0.75 +
              (row * 0.08) +
              (random.nextDouble() * 0.02), // y: sıralı yerleşim
        );

        // Mercan boyutunu türüne göre ayarla
        double size;
        switch (type) {
          case CoralType.brainCoral:
            size = 60 + random.nextDouble() * 20;
            break;
          case CoralType.tubeCoral:
            size = 45 + random.nextDouble() * 15;
            break;
          case CoralType.fanCoral:
            size = 50 + random.nextDouble() * 20;
            break;
          default:
            size = 40 + random.nextDouble() * 15;
        }

        final color = _coralPalette[random.nextInt(_coralPalette.length)];
        final rotation = type == CoralType.fanCoral
            ? -math.pi / 2
            : random.nextDouble() * math.pi * 0.5 - math.pi * 0.25;

        _corals.add(CoralData(
          type: type,
          position: position,
          size: size,
          color: color,
          rotation: rotation,
        ));

        final controller = AnimationController(
          duration: Duration(seconds: 3 + random.nextInt(2)),
          vsync: this,
        )..repeat(reverse: true);

        _coralControllers.add(controller);
        _coralAnimations.add(
          Tween<double>(begin: 0.98, end: 1.02).animate(
            CurvedAnimation(parent: controller, curve: Curves.easeInOut),
          ),
        );
      }
    }

    // Caustics (su altı ışık) efektleri
    _caustics = [];
    _causticsControllers = [];
    _causticsAnimations = [];

    for (int i = 0; i < 10; i++) {
      final position = Offset(
        random.nextDouble(),
        random.nextDouble(),
      );
      final size = random.nextDouble() * 100 + 50;

      _caustics.add(CausticsData(
        position: position,
        size: size,
      ));

      final controller = AnimationController(
        duration: Duration(seconds: 3 + random.nextInt(4)),
        vsync: this,
      )..repeat();

      _causticsControllers.add(controller);
      _causticsAnimations.add(
        Tween<double>(begin: 0.3, end: 0.7).animate(
          CurvedAnimation(parent: controller, curve: Curves.easeInOut),
        ),
      );
    }

    // Balık animasyonları
    _fishControllers = List.generate(
      widget.fishCount,
      (index) => AnimationController(
        duration:
            Duration(seconds: 20 + random.nextInt(15)), // Daha yavaş yüzme
        vsync: this,
      )..repeat(),
    );

    _fishAnimations = _fishControllers.map((controller) {
      return Tween<double>(begin: -0.2, end: 1.2).animate(
        CurvedAnimation(
          parent: controller,
          // Daha doğal yüzme hareketi için özel eğri
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    // Balıkları farklı derinliklere yerleştir
    _fishPositions = List.generate(
      widget.fishCount,
      (index) {
        final depth = random.nextDouble() * 0.5 + 0.1; // y: 0.1 ile 0.6 arası
        return Offset(0, depth);
      },
    );
  }

  @override
  void dispose() {
    for (var controller in [
      ..._coralControllers,
      ..._fishControllers,
      ..._causticsControllers
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Derinlik gradyanı
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1B4B6C).withOpacity(0.6), // Koyu deniz mavisi
                const Color(0xFF0A2A3F)
                    .withOpacity(0.8), // Derin okyanus mavisi
              ],
            ),
          ),
        ),

        // Kumlu zemin
        CustomPaint(
          painter: SandPainter(),
          size: Size.infinite,
        ),

        // Su yüzeyi dalgaları
        CustomPaint(
          painter: WaterSurfacePainter(),
          size: Size.infinite,
        ),

        // Caustics efektleri
        ...List.generate(_caustics.length, (index) {
          return AnimatedBuilder(
            animation: _causticsAnimations[index],
            builder: (context, child) {
              return Positioned(
                left: _caustics[index].position.dx *
                    MediaQuery.of(context).size.width,
                top: _caustics[index].position.dy *
                    MediaQuery.of(context).size.height,
                child: Opacity(
                  opacity: _causticsAnimations[index].value,
                  child: CustomPaint(
                    painter: CausticsPainter(),
                    size: Size(_caustics[index].size, _caustics[index].size),
                  ),
                ),
              );
            },
          );
        }),

        // Mercanlar
        ...List.generate(_corals.length, (index) {
          return Positioned(
            left:
                _corals[index].position.dx * MediaQuery.of(context).size.width,
            bottom:
                _corals[index].position.dy * MediaQuery.of(context).size.height,
            child: ScaleTransition(
              scale: _coralAnimations[index],
              child: Transform.rotate(
                angle: _corals[index].rotation,
                child: CustomPaint(
                  painter: CoralPainter(
                    type: _corals[index].type,
                    color: _corals[index].color,
                  ),
                  size: Size(_corals[index].size, _corals[index].size),
                ),
              ),
            ),
          );
        }),

        // Balıklar
        ...List.generate(widget.fishCount, (index) {
          return AnimatedBuilder(
            animation: _fishAnimations[index],
            builder: (context, child) {
              return Positioned(
                left: _fishAnimations[index].value *
                    MediaQuery.of(context).size.width,
                top: _fishPositions[index].dy *
                    MediaQuery.of(context).size.height,
                child: Transform.scale(
                  scale: 0.7,
                  child: CustomPaint(
                    painter: FishPainter(color: const Color(0xFF64C8FF)),
                    size: const Size(40, 25),
                  ),
                ),
              );
            },
          );
        }),

        widget.child,
      ],
    );
  }
}

enum CoralType {
  branchingCoral,
  brainCoral,
  tubeCoral,
  fanCoral,
  spongeCoral,
}

class CoralData {
  final CoralType type;
  final Offset position;
  final double size;
  final Color color;
  final double rotation;

  CoralData({
    required this.type,
    required this.position,
    required this.size,
    required this.color,
    required this.rotation,
  });
}

class CausticsData {
  final Offset position;
  final double size;

  CausticsData({
    required this.position,
    required this.size,
  });
}

class WaterSurfacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.3),
          Colors.white.withOpacity(0.1),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.moveTo(0, size.height * 0.2);

    for (var i = 0; i < size.width; i += 20) {
      path.quadraticBezierTo(
        i + 10,
        size.height * 0.18,
        i + 20,
        size.height * 0.2,
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SandPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF8B7355).withOpacity(0.6), // Kum rengi
          const Color(0xFFAA8B66).withOpacity(0.8), // Açık kum rengi
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    path.moveTo(0, size.height * 0.7);

    for (var i = 0; i < size.width; i += 30) {
      path.quadraticBezierTo(
        i + 15,
        size.height * 0.75 + math.sin(i * 0.1) * 10,
        i + 30,
        size.height * 0.7,
      );
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class CausticsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    for (var i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4);
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CoralPainter extends CustomPainter {
  final CoralType type;
  final Color color;

  CoralPainter({
    required this.type,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    switch (type) {
      case CoralType.branchingCoral:
        _drawBranchingCoral(canvas, size);
        break;
      case CoralType.brainCoral:
        _drawBrainCoral(canvas, size);
        break;
      case CoralType.tubeCoral:
        _drawTubeCoral(canvas, size);
        break;
      case CoralType.fanCoral:
        _drawFanCoral(canvas, size);
        break;
      case CoralType.spongeCoral:
        _drawSpongeCoral(canvas, size);
        break;
    }
  }

  void _drawBranchingCoral(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3; // Daha kalın çizgiler

    void drawBranch(Offset start, double angle, double length, int depth) {
      if (depth > 5) return; // Daha fazla dal

      final end = Offset(
        start.dx + math.cos(angle) * length,
        start.dy + math.sin(angle) * length,
      );

      canvas.drawLine(start, end, paint);

      final branchLength = length * 0.75; // Daha uzun dallar
      final spreadAngle =
          0.4 + (math.Random().nextDouble() * 0.2); // Rastgele açılar
      drawBranch(end, angle - spreadAngle, branchLength, depth + 1);
      drawBranch(end, angle + spreadAngle, branchLength, depth + 1);

      // Ekstra dallar
      if (depth < 3 && math.Random().nextBool()) {
        drawBranch(end, angle, branchLength * 0.8, depth + 1);
      }
    }

    drawBranch(
      Offset(size.width / 2, size.height),
      -math.pi / 2,
      size.height * 0.5, // Daha uzun başlangıç
      0,
    );
  }

  void _drawBrainCoral(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill; // Fill style for more solid appearance

    final path = Path();
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Ana şekil
    path.addOval(Rect.fromCircle(center: center, radius: radius));

    // Kıvrımlar
    for (var i = 0; i < 30; i++) {
      // Daha fazla kıvrım
      final angle = (i / 30) * math.pi * 2;
      final x = center.dx + math.cos(angle) * radius;
      final y = center.dy + math.sin(angle) * radius;

      for (var j = 0; j < 8; j++) {
        // Daha derin kıvrımlar
        final innerRadius = radius * (0.9 - j * 0.1);
        final x2 = center.dx + math.cos(angle) * innerRadius;
        final y2 = center.dy + math.sin(angle) * innerRadius;

        path.moveTo(x, y);
        path.quadraticBezierTo(
          x2 + math.cos(angle + math.pi / 3) * 15,
          y2 + math.sin(angle + math.pi / 3) * 15,
          x2,
          y2,
        );
      }
    }

    canvas.drawPath(path, paint);

    // Gölgeler için üst katman
    final shadowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(path, shadowPaint);
  }

  void _drawTubeCoral(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    final tubeCount = 12; // Daha fazla tüp

    for (var i = 0; i < tubeCount; i++) {
      final x = size.width * (0.1 + random.nextDouble() * 0.8);
      final height = size.height * (0.4 + random.nextDouble() * 0.5);
      final width =
          size.width * (0.1 + random.nextDouble() * 0.1); // Değişken genişlik

      final path = Path();

      // Tüp gövdesi
      path.moveTo(x - width / 2, size.height);
      path.lineTo(x - width / 2, size.height - height);
      path.quadraticBezierTo(
        x,
        size.height - height - width / 2,
        x + width / 2,
        size.height - height,
      );
      path.lineTo(x + width / 2, size.height);
      path.close();

      // Tüp ağzı
      final mouthPath = Path();
      mouthPath.addOval(Rect.fromCenter(
        center: Offset(x, size.height - height),
        width: width,
        height: width * 0.4,
      ));

      canvas.drawPath(path, paint);
      canvas.drawPath(mouthPath, paint..style = PaintingStyle.fill);
    }
  }

  void _drawFanCoral(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    final center = Offset(size.width / 2, size.height);
    final radius = size.width * 0.4;

    for (var i = 0; i < 12; i++) {
      final startAngle = -math.pi * 0.7;
      final endAngle = -math.pi * 0.3;
      final angle = startAngle + (endAngle - startAngle) * (i / 11);

      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );

      // Yelpaze detayları
      for (var j = 1; j < 4; j++) {
        final subRadius = radius * (0.7 - j * 0.15);
        path.moveTo(
          center.dx + math.cos(angle) * subRadius,
          center.dy + math.sin(angle) * subRadius,
        );
        path.lineTo(
          center.dx + math.cos(angle + 0.1) * subRadius,
          center.dy + math.sin(angle + 0.1) * subRadius,
        );
      }
    }

    canvas.drawPath(path, paint);
  }

  void _drawSpongeCoral(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    final path = Path();

    // Ana gövde
    path.addOval(Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.8,
      height: size.height * 0.8,
    ));

    // Gözenekler
    for (var i = 0; i < 20; i++) {
      final x = size.width * (0.2 + random.nextDouble() * 0.6);
      final y = size.height * (0.2 + random.nextDouble() * 0.6);
      final radius = size.width * (0.05 + random.nextDouble() * 0.05);

      path.addOval(Rect.fromCircle(
        center: Offset(x, y),
        radius: radius,
      ));
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class FishPainter extends CustomPainter {
  final Color color;

  FishPainter({this.color = const Color(0xFF64C8FF)});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();

    // Simple decorative fish body
    path.moveTo(size.width * 0.2, size.height / 2);
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.1,
      size.width * 0.8,
      size.height * 0.1,
    );
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.2,
      size.width,
      size.height / 2,
    );
    path.quadraticBezierTo(
      size.width * 0.9,
      size.height * 0.8,
      size.width * 0.8,
      size.height * 0.9,
    );
    path.quadraticBezierTo(
      size.width * 0.4,
      size.height * 0.9,
      size.width * 0.2,
      size.height / 2,
    );

    // Simple tail
    path.moveTo(0, size.height * 0.3);
    path.quadraticBezierTo(
      size.width * 0.1,
      size.height * 0.4,
      0,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.1,
      size.height * 0.6,
      0,
      size.height * 0.7,
    );

    // Small fins
    // Top fin
    path.moveTo(size.width * 0.5, size.height * 0.15);
    path.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.05,
      size.width * 0.7,
      size.height * 0.15,
    );

    // Bottom fin
    path.moveTo(size.width * 0.5, size.height * 0.85);
    path.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.95,
      size.width * 0.7,
      size.height * 0.85,
    );

    // Draw the fish body
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
