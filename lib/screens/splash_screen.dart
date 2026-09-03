import 'package:flutter/material.dart';
import '../theme.dart';

/// Splash "dynamique" affiché au lancement de l'app (dans Flutter, une fois
/// le moteur démarré). Il complète — sans le remplacer — le splash natif
/// statique généré par Android/iOS au tout premier instant (celui-là ne
/// peut pas être animé, c'est une contrainte du système d'exploitation).
class SplashScreen extends StatefulWidget {
  final Widget next;
  const SplashScreen({super.key, required this.next});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<double> _lineProgress;
  late final Animation<double> _ringRotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000));

    _logoOpacity = CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.35, curve: Curves.easeOut));
    _logoScale = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack)),
    );
    _ringRotation = Tween<double>(begin: -0.35, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _textOpacity = CurvedAnimation(parent: _controller, curve: const Interval(0.4, 0.7, curve: Curves.easeOut));
    _lineProgress = CurvedAnimation(parent: _controller, curve: const Interval(0.55, 0.95, curve: Curves.easeOutCubic));

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 350), _goNext);
      }
    });
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, animation, __) => FadeTransition(opacity: animation, child: widget.next),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.forest,
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Halo décoratif en fond, façon feu de camp discret.
              Positioned(
                bottom: -120,
                left: -60,
                child: Opacity(
                  opacity: 0.25 * _logoOpacity.value,
                  child: Container(
                    width: 320,
                    height: 320,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.ember),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.rotate(
                      angle: _ringRotation.value,
                      child: Opacity(
                        opacity: _logoOpacity.value,
                        child: Transform.scale(
                          scale: _logoScale.value,
                          child: Container(
                            width: 118,
                            height: 118,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.forestDark,
                              border: Border.all(color: AppColors.khaki, width: 3),
                              boxShadow: AppShadows.soft,
                            ),
                            child: const Center(
                              child: CustomPaint(
                                size: Size(52, 52),
                                painter: _TrefoilPainter(color: AppColors.parchment),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: _textOpacity.value,
                      child: const Text(
                        'APPEL SCOUT',
                        style: TextStyle(
                          color: AppColors.parchment,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 3,
                        width: 150,
                        child: Stack(
                          children: [
                            Container(color: Colors.white.withValues(alpha: 0.12)),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _lineProgress.value.clamp(0.0, 1.0),
                                child: Container(color: AppColors.ember),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Opacity(
                      opacity: _textOpacity.value,
                      child: const Text(
                        'Présence et vie de troupe',
                        style: TextStyle(color: AppColors.khakiLight, fontSize: 12.5, letterSpacing: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Petit emblème dessiné à la main (trois pointes façon fleur de lys
/// stylisée), pour éviter de dépendre d'un asset image externe.
class _TrefoilPainter extends CustomPainter {
  final Color color;
  const _TrefoilPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final w = size.width;
    final h = size.height;

    final center = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w * 0.68, h * 0.55)
      ..lineTo(w * 0.5, h * 0.42)
      ..lineTo(w * 0.32, h * 0.55)
      ..close();
    canvas.drawPath(center, paint);

    canvas.drawOval(Rect.fromCircle(center: Offset(w * 0.16, h * 0.6), radius: w * 0.16), paint);
    canvas.drawOval(Rect.fromCircle(center: Offset(w * 0.84, h * 0.6), radius: w * 0.16), paint);

    final base = Rect.fromLTWH(w * 0.42, h * 0.62, w * 0.16, h * 0.38);
    canvas.drawRect(base, paint);
  }

  @override
  bool shouldRepaint(covariant _TrefoilPainter oldDelegate) => oldDelegate.color != color;
}
