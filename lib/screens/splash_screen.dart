import 'package:flutter/material.dart';

import '../theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    required this.initialize,
    required this.nextBuilder,
  });

  final Future<String?> Function() initialize;
  final Widget Function(BuildContext context, String? troopName) nextBuilder;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _troopName;
  Object? _initializationError;
  bool _ready = false;
  bool _initializing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (_initializing) return;
    setState(() {
      _initializing = true;
      _initializationError = null;
    });

    try {
      final troopName = await widget.initialize();
      if (!mounted) return;
      setState(() {
        _troopName = troopName;
        _ready = true;
        _initializing = false;
      });
    } catch (error, stackTrace) {
      debugPrint('App initialization failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _initializationError = error;
        _initializing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final transitionDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
      body: AnimatedSwitcher(
        duration: transitionDuration,
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: _ready
            ? KeyedSubtree(
                key: const ValueKey('app-ready'),
                child: widget.nextBuilder(context, _troopName),
              )
            : KeyedSubtree(
                key: const ValueKey('app-starting'),
                child: _splashContent(context, isDark),
              ),
      ),
    );
  }

  Widget _splashContent(BuildContext context, bool isDark) {
    final titleColor = isDark ? AppColors.darkText : AppColors.primaryDeep;

    return Stack(
      key: const ValueKey('splash-content'),
      fit: StackFit.expand,
      children: [
        Center(
          child: Semantics(
            label: 'Appel Scout',
            image: true,
            child: Image.asset(
              'assets/splash_logo.png',
              width: 256,
              height: 256,
              fit: BoxFit.contain,
              excludeFromSemantics: true,
            ),
          ),
        ),
        Center(
          child: Transform.translate(
            offset: const Offset(0, 160),
            child: Text(
              'Appel Scout',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: titleColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
        if (_initializationError != null)
          Align(
            alignment: const Alignment(0, 0.72),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Impossible de préparer les données locales.',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: titleColor),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _initializing ? null : _initialize,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
