// lib/screens/splash_screen.dart
//
// Écran de démarrage animé (8 secondes) : le logo (découpé en cercle, donc
// sans le fond blanc de l'image) apparaît tout petit, zoome, dézoome, zoome
// à nouveau... en boucle jusqu'à la fin du minuteur. Le message de bienvenue
// et la barre bleue apparaissent après le premier zoom, puis l'application
// s'ouvre en fondu.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../navigation/app_navigator.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  // ── Réglages faciles à modifier ──
  static const Color _background = Colors.black;
  static const String _logoAsset = 'assets/logo.png';
  static const String _welcomeText =
      'Bienvenue dans l\'espace de l\'Association des Jeunes Étudiants de Mahasoabe';
  static const Color _accent = Color(0xFF0163D2);
  // Durée totale de l'animation (5 s, 7 s, 8 s... à votre convenance).
  static const int _totalMs = 8000;
  static const Duration _animationDuration = Duration(milliseconds: _totalMs);
  static const Duration _holdAfterAnimation = Duration(milliseconds: 300);

  // Chorégraphie du logo :
  //  1) départ tout petit -> premier zoom (_firstZoomMs)
  //  2) _cycles fois : dézoom (_halfCycleMs) puis re-zoom (_halfCycleMs)
  //  3) le temps restant : le logo reste à sa taille normale.
  static const double _startScale = 0.15; // taille de départ (15 %)
  static const double _minScale = 0.55; // taille au plus petit du dézoom
  static const int _firstZoomMs = 1200;
  static const int _halfCycleMs = 1000;
  static const int _cycles = 3;

  /// Le logo est un carré à fond blanc dont le cercle touche les bords :
  /// on le découpe en cercle et on l'agrandit très légèrement (3 %) pour
  /// supprimer le liseré blanc qui pourrait rester sur le bord.
  static const double _logoCropZoom = 1.03;

  late final AnimationController _controller;
  late final Animation<double> _logoScale; // zoom / dézoom / zoom...
  late final Animation<double> _logoOpacity;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _lineWidth;

  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _animationDuration,
      // 🔥 CORRIGÉ : sans ceci, si le téléphone a les animations désactivées
      // (« Supprimer les animations », échelle d'animation à 0, économiseur
      // de batterie...), Flutter réduit TOUTE animation à 5 % de sa durée :
      // 8 s deviennent 0,4 s et l'écran ne fait qu'un clignement.
      // `preserve` impose la durée réelle de 8 s.
      animationBehavior: AnimationBehavior.preserve,
    );

    // Zoom / dézoom répétés. Les poids sont en millisecondes : chaque étape
    // dure donc exactement le temps indiqué dans les réglages ci-dessus.
    final steps = <TweenSequenceItem<double>>[
      // Premier zoom : de très petit à la taille normale, avec un léger rebond.
      TweenSequenceItem(
        tween: Tween<double>(begin: _startScale, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: _firstZoomMs.toDouble(),
      ),
    ];
    for (var i = 0; i < _cycles; i++) {
      steps.add(TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: _minScale)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _halfCycleMs.toDouble(),
      ));
      steps.add(TweenSequenceItem(
        tween: Tween<double>(begin: _minScale, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _halfCycleMs.toDouble(),
      ));
    }
    final usedMs = _firstZoomMs + _cycles * 2 * _halfCycleMs;
    if (usedMs < _totalMs) {
      steps.add(TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: (_totalMs - usedMs).toDouble(),
      ));
    }
    _logoScale = TweenSequence<double>(steps).animate(_controller);

    // Fondu d'apparition rapide au tout début (≈ 0,4 s).
    _logoOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.05, curve: Curves.easeIn),
    );

    _textOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.15, 0.25, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.6),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 0.25, curve: Curves.easeOutCubic),
      ),
    );
    _lineWidth = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.34, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Démarrage unique : on a besoin du contexte pour précharger l'image.
    if (_started) return;
    _started = true;
    _prepareAndRun();
  }

  Future<void> _prepareAndRun() async {
    // 🔥 CORRIGÉ : l'animation ne démarre qu'une fois le logo décodé en
    // mémoire. Avant, le décodage de l'image se faisait pendant l'animation :
    // les premières images étaient perdues et le zoom paraissait inexistant.
    try {
      await precacheImage(const AssetImage(_logoAsset), context)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Image absente ou lente : l'animation se joue quand même.
    }
    if (!mounted) return;

    // Courte pause pour que l'écran noir soit bien affiché avant le zoom.
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    await _controller.forward();
    await Future.delayed(_holdAfterAnimation);
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const AppNavigator(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
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
    final width = MediaQuery.of(context).size.width;
    final logoSize = (width * 0.45).clamp(120.0, 220.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _background,
      ),
      child: Scaffold(
        backgroundColor: _background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacity.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: child,
                    ),
                  );
                },
                child: SizedBox(
                  width: logoSize,
                  height: logoSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halo discret derrière le logo (suit sa forme ronde).
                      Container(
                        width: logoSize * 0.85,
                        height: logoSize * 0.85,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: _accent.withOpacity(0.35),
                              blurRadius: 50,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      // Logo découpé en cercle : le fond blanc des coins
                      // n'est plus visible.
                      ClipOval(
                        child: SizedBox(
                          width: logoSize,
                          height: logoSize,
                          child: Transform.scale(
                            scale: _logoCropZoom,
                            child: Image.asset(
                              _logoAsset,
                              width: logoSize,
                              height: logoSize,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.business,
                                      color: _accent, size: logoSize * 0.6),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SlideTransition(
                position: _textSlide,
                child: FadeTransition(
                  opacity: _textOpacity,
                  // Phrase longue : centrée, sur plusieurs lignes si besoin,
                  // avec une marge de chaque côté pour ne pas toucher les bords.
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _welcomeText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: width < 360 ? 17 : 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              AnimatedBuilder(
                animation: _lineWidth,
                builder: (context, _) => Container(
                  width: 56 * _lineWidth.value,
                  height: 3,
                  decoration: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
