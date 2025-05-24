import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ReefBackground extends StatefulWidget {
  final int coralCount;
  final int fishCount;
  final int plantCount;
  final String userId;

  const ReefBackground({
    super.key,
    required this.coralCount,
    required this.fishCount,
    required this.plantCount,
    required this.userId,
  });

  @override
  State<ReefBackground> createState() => _ReefBackgroundState();
}

class _ReefBackgroundState extends State<ReefBackground>
    with TickerProviderStateMixin {
  AnimationController? _waveController;
  AnimationController? _lightController;
  AnimationController? _bubbleController;
  late List<AnimationController> _fishControllers;
  late List<AnimationController> _plantControllers;
  late List<FishData> _fishData;
  late List<PlantData> _plants;
  late List<BubbleData> _bubbles;

  Map<FishType, ui.Image?> _fishImages = {};
  ui.Image? _smallRockImage;
  ui.Image? _seaStarImage;
  Map<SeaweedType, ui.Image?> _seaweedImages = {};
  ui.Image? _anemoneImage;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _initializeAnimations();
  }

  Future<void> _loadImages() async {
    try {
      await Future.wait([
        _loadImage(const AssetImage('assets/icons/clown-fish.png'))
            .then((image) {
          _fishImages[FishType.clownfish] = image;
        }),
        _loadImage(const AssetImage('assets/icons/angelfish.png'))
            .then((image) {
          _fishImages[FishType.angelfish] = image;
        }),
        _loadImage(const AssetImage('assets/icons/tang.png')).then((image) {
          _fishImages[FishType.tang] = image;
        }),
        _loadImage(const AssetImage('assets/icons/small_rock.png'))
            .then((image) {
          _smallRockImage = image;
        }),
        _loadImage(const AssetImage('assets/icons/sea_star.png')).then((image) {
          _seaStarImage = image;
        }),
        _loadImage(const AssetImage('assets/icons/seaweed_green.png'))
            .then((image) {
          _seaweedImages[SeaweedType.red] = image;
        }),
        _loadImage(const AssetImage('assets/icons/seaweed_green.png'))
            .then((image) {
          _seaweedImages[SeaweedType.green] = image;
        }),
        _loadImage(const AssetImage('assets/icons/seaweed.png')).then((image) {
          _seaweedImages[SeaweedType.yellow] = image;
        }),
        _loadImage(const AssetImage('assets/icons/coral.png')).then((image) {
          _anemoneImage = image;
        }),
      ]).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception('Asset yükleme zaman aşımına uğradı.');
      });

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Asset yükleme hatası: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Asset yüklenemedi: $e';
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage ?? 'Bilinmeyen bir hata oluştu.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
    }
  }

  Future<ui.Image?> _loadImage(ImageProvider provider) async {
    final completer = Completer<ui.Image>();
    final imageStream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener imageStreamListener;
    imageStreamListener = ImageStreamListener(
      (ImageInfo info, bool synchronousCall) {
        completer.complete(info.image);
      },
      onError: (exception, stackTrace) {
        completer.completeError(exception, stackTrace);
      },
    );
    imageStream.addListener(imageStreamListener);
    final image = await completer.future;
    imageStream.removeListener(imageStreamListener);
    return image;
  }

  void _initializeAnimations() {
    final random = math.Random(widget.userId.hashCode);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _lightController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _fishControllers = List.generate(
      widget.fishCount,
      (_) => AnimationController(
        vsync: this,
        duration: Duration(seconds: 10 + random.nextInt(10)),
      )..repeat(reverse: true),
    );

    _fishData = List.generate(widget.fishCount, (index) {
      return FishData(
        type: FishType.values[random.nextInt(FishType.values.length)],
        initialX: random.nextDouble(),
        depth: 0.2 + random.nextDouble() * 0.5,
        speed: 0.5 + random.nextDouble(),
        scale: 0.6 + random.nextDouble() * 0.4,
        x: random.nextDouble(),
      );
    });

    _plantControllers = List.generate(
      widget.plantCount,
      (_) => AnimationController(
        vsync: this,
        duration: Duration(seconds: 3 + random.nextInt(3)),
      )..repeat(reverse: true),
    );

    _plants = List.generate(widget.plantCount, (_) {
      return PlantData(
        type: PlantType.values[random.nextInt(PlantType.values.length)],
        seaweedType:
            SeaweedType.values[random.nextInt(SeaweedType.values.length)],
        x: random.nextDouble(),
      );
    });

    _bubbles = List.generate(20, (_) {
      return BubbleData(
        x: random.nextDouble(),
        y: 1.0,
        size: 5 + random.nextDouble() * 10,
        speed: 0.5 + random.nextDouble(),
      );
    });
  }

  @override
  void dispose() {
    _waveController?.dispose();
    _lightController?.dispose();
    _bubbleController?.dispose();
    for (var controller in _fishControllers) {
      controller.dispose();
    }
    for (var controller in _plantControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading ||
        _waveController == null ||
        _lightController == null ||
        _bubbleController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AnimatedBuilder(
      animation: Listenable.merge([
        _waveController!,
        _lightController!,
        _bubbleController!,
        ..._fishControllers,
        ..._plantControllers,
      ]),
      builder: (context, _) {
        return CustomPaint(
          painter: ReefPainter(
            waveOffset: _waveController!.value,
            lightOpacity: _lightController!.value,
            bubbleProgress: _bubbleController!.value,
            corals: List.generate(widget.coralCount, (index) {
              return CoralData(
                x: (index + 1) / (widget.coralCount + 1),
                type: CoralType.values[index % CoralType.values.length],
              );
            }),
            fish: _fishData.asMap().entries.map((entry) {
              final index = entry.key;
              final fish = entry.value;
              return FishData(
                type: fish.type,
                initialX: fish.initialX,
                depth: fish.depth,
                speed: fish.speed,
                scale: fish.scale,
                x: fish.initialX +
                    math.sin(_fishControllers[index].value * math.pi * 2) * 0.3,
              );
            }).toList(),
            plants: _plants,
            bubbles: _bubbles.map((bubble) {
              final y = bubble.y - bubble.speed * _bubbleController!.value;
              return BubbleData(
                x: bubble.x,
                y: y < 0 ? 1.0 : y,
                size: bubble.size,
                speed: bubble.speed,
              );
            }).toList(),
            fishImages: _fishImages,
            smallRockImage: _smallRockImage,
            seaStarImage: _seaStarImage,
            seaweedImages: _seaweedImages,
            anemoneImage: _anemoneImage,
          ),
          size: Size.infinite,
          willChange: true,
        );
      },
    );
  }
}

enum CoralType { branching, mushroom, soft }

enum FishType { clownfish, angelfish, tang }

enum PlantType { seaweed, anemone }

enum SeaweedType { red, green, yellow }

class CoralData {
  final double x;
  final CoralType type;

  CoralData({required this.x, required this.type});
}

class FishData {
  final FishType type;
  final double x;
  final double initialX;
  final double depth;
  final double speed;
  final double scale;

  FishData({
    required this.type,
    this.x = 0.0,
    required this.initialX,
    required this.depth,
    required this.speed,
    required this.scale,
  });
}

class PlantData {
  final PlantType type;
  final SeaweedType seaweedType;
  final double x;

  PlantData({required this.type, required this.seaweedType, required this.x});
}

class BubbleData {
  final double x;
  final double y;
  final double size;
  final double speed;

  BubbleData(
      {required this.x,
      required this.y,
      required this.size,
      required this.speed});
}

class ReefPainter extends CustomPainter {
  final double waveOffset;
  final double lightOpacity;
  final double bubbleProgress;
  final List<CoralData> corals;
  final List<FishData> fish;
  final List<PlantData> plants;
  final List<BubbleData> bubbles;
  final Map<FishType, ui.Image?> fishImages;
  final ui.Image? smallRockImage;
  final ui.Image? seaStarImage;
  final Map<SeaweedType, ui.Image?> seaweedImages;
  final ui.Image? anemoneImage;

  ReefPainter({
    required this.waveOffset,
    required this.lightOpacity,
    required this.bubbleProgress,
    required this.corals,
    required this.fish,
    required this.plants,
    required this.bubbles,
    required this.fishImages,
    this.smallRockImage,
    this.seaStarImage,
    required this.seaweedImages,
    this.anemoneImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _paintSeabed(canvas, size);
    for (var coral in corals) {
      _paintCoral(canvas, size, coral);
    }
    for (var plant in plants) {
      _paintPlant(canvas, size, plant);
    }
    for (var fish in fish) {
      _paintFish(canvas, size, fish);
    }
    for (var bubble in bubbles) {
      _paintBubble(canvas, size, bubble);
    }
    _paintLightBeams(canvas, size);
    _paintWaterSurface(canvas, size);
  }

  void _paintSeabed(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFFD4A373).withOpacity(0.6),
          const Color(0xFF8B5523),
        ],
      ).createShader(
          Rect.fromLTWH(0, size.height * 0.7, size.width, size.height * 0.3));

    final path = Path();
    path.moveTo(0, size.height * 0.7);
    for (var i = 0.0; i <= size.width; i += 20) {
      path.quadraticBezierTo(
        i + 10,
        size.height * 0.7 + math.sin(i * 0.05 + waveOffset) * 10,
        i + 20,
        size.height * 0.7,
      );
    }
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    final rockPaint = Paint()..color = const Color(0xFF6D8299).withOpacity(0.8);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.8),
      30,
      rockPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8, size.height * 0.85),
      20,
      rockPaint,
    );

    if (smallRockImage != null) {
      final smallRockPaint = Paint();
      for (var i = 0; i < 5; i++) {
        final dstRect = Rect.fromCenter(
          center: Offset(size.width * (0.1 + i * 0.2), size.height * 0.75),
          width: 30,
          height: 30,
        );
        canvas.drawImageRect(
          smallRockImage!,
          Rect.fromLTWH(0, 0, smallRockImage!.width.toDouble(),
              smallRockImage!.height.toDouble()),
          dstRect,
          smallRockPaint,
        );
      }
    } else {
      final smallRockPaint = Paint()
        ..color = const Color(0xFF6D8299).withOpacity(0.6);
      for (var i = 0; i < 5; i++) {
        canvas.drawCircle(
          Offset(size.width * (0.1 + i * 0.2), size.height * 0.75),
          5,
          smallRockPaint,
        );
      }
    }

    if (seaStarImage != null) {
      final seaStarPaint = Paint();
      for (var i = 0; i < 3; i++) {
        final dstRect = Rect.fromCenter(
          center: Offset(size.width * (0.15 + i * 0.3), size.height * 0.78),
          width: 30,
          height: 30,
        );
        canvas.drawImageRect(
          seaStarImage!,
          Rect.fromLTWH(0, 0, seaStarImage!.width.toDouble(),
              seaStarImage!.height.toDouble()),
          dstRect,
          seaStarPaint,
        );
      }
    } else {
      final seaStarPaint = Paint()..color = const Color(0xFFFFD166);
      for (var i = 0; i < 3; i++) {
        final center =
            Offset(size.width * (0.15 + i * 0.3), size.height * 0.78);
        final path = Path();
        for (var j = 0; j < 5; j++) {
          final angle = (j / 5) * math.pi * 2;
          final outer = 10.0;
          final inner = 4.0;
          path.moveTo(center.dx, center.dy);
          path.lineTo(
            center.dx + math.cos(angle) * outer,
            center.dy + math.sin(angle) * outer,
          );
          path.lineTo(
            center.dx + math.cos(angle + math.pi / 5) * inner,
            center.dy + math.sin(angle + math.pi / 5) * inner,
          );
          path.close();
        }
        canvas.drawPath(path, seaStarPaint);
      }
    }
  }

  void _paintCoral(Canvas canvas, Size size, CoralData coral) {
    // Placeholder mercan çizimlerini tamamen kaldırdık
    // Eğer mercanlar için de asset kullanmak istersen, buraya asset çizim kodu eklenebilir
  }

  void _paintFish(Canvas canvas, Size size, FishData fish) {
    final x = size.width * fish.x;
    final y = size.height * fish.depth;

    final fishImage = fishImages[fish.type];
    if (fishImage == null) {
      return;
    }

    final paint = Paint();
    final dstRect = Rect.fromCenter(
      center: Offset(x, y),
      width: 60 * fish.scale,
      height: 60 * fish.scale,
    );

    canvas.drawImageRect(
      fishImage,
      Rect.fromLTWH(
          0, 0, fishImage.width.toDouble(), fishImage.height.toDouble()),
      dstRect,
      paint,
    );
  }

  void _paintPlant(Canvas canvas, Size size, PlantData plant) {
    final x = size.width * plant.x;
    final baseY = size.height * 0.8;

    switch (plant.type) {
      case PlantType.seaweed:
        final seaweedImage = seaweedImages[plant.seaweedType];
        if (seaweedImage == null) {
          return;
        }

        final paint = Paint();
        final dstRect = Rect.fromCenter(
          center: Offset(x, baseY - 50),
          width: 60,
          height: 100,
        );
        canvas.drawImageRect(
          seaweedImage,
          Rect.fromLTWH(0, 0, seaweedImage.width.toDouble(),
              seaweedImage.height.toDouble()),
          dstRect,
          paint,
        );
        break;
      case PlantType.anemone:
        if (anemoneImage == null) {
          return;
        }

        final paint = Paint();
        final dstRect = Rect.fromCenter(
          center: Offset(x, baseY - 30),
          width: 60,
          height: 60,
        );
        canvas.drawImageRect(
          anemoneImage!,
          Rect.fromLTWH(0, 0, anemoneImage!.width.toDouble(),
              anemoneImage!.height.toDouble()),
          dstRect,
          paint,
        );
        break;
    }
  }

  void _paintBubble(Canvas canvas, Size size, BubbleData bubble) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width * bubble.x, size.height * bubble.y),
      bubble.size / 2,
      paint,
    );
  }

  void _paintLightBeams(Canvas canvas, Size size) {
    final beamCount = 7;
    final beamWidth = 8.0;
    for (var i = 0; i < beamCount; i++) {
      final x = size.width * (i / (beamCount - 1)) +
          20 * math.sin(lightOpacity * 2 * math.pi + i);
      final rect =
          Rect.fromLTWH(x - beamWidth / 2, 0, beamWidth, size.height * 0.65);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.32 * lightOpacity),
            Colors.transparent,
          ],
        ).createShader(rect);
      canvas.drawRect(rect, paint);
    }
  }

  void _paintWaterSurface(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 100));

    final path = Path();
    path.moveTo(0, 0);
    for (var i = 0.0; i <= size.width; i += 20) {
      path.quadraticBezierTo(
        i + 10,
        50 + math.sin(i * 0.05 + waveOffset) * 10,
        i + 20,
        50,
      );
    }
    path.lineTo(size.width, 100);
    path.lineTo(0, 100);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
