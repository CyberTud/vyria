import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rive/rive.dart' hide RadialGradient, LinearGradient;

class AnimatedMascot extends StatefulWidget {
  const AnimatedMascot({super.key, this.size = 160});

  final double size;

  @override
  State<AnimatedMascot> createState() => _AnimatedMascotState();
}

class _AnimatedMascotState extends State<AnimatedMascot> {
  late final Future<bool> _riveAvailable;

  @override
  void initState() {
    super.initState();
    _riveAvailable = _canLoadRive();
  }

  Future<bool> _canLoadRive() async {
    try {
      await rootBundle.load('assets/animations/vyria_mascot.riv');
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _riveAvailable,
      builder: (context, snapshot) {
        final resolved = snapshot.data ?? false;
        final child = resolved
            ? _RiveMascot(size: widget.size)
            : _FallbackMascot(size: widget.size);
        return child
            .animate(delay: 200.ms)
            .fadeIn(duration: 500.ms, curve: Curves.easeOut)
            .slide(begin: const Offset(0, 0.08), curve: Curves.easeOut);
      },
    );
  }
}

class _RiveMascot extends StatelessWidget {
  const _RiveMascot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size),
        child: const _SafeRiveAnimation(
          asset: 'assets/animations/vyria_mascot.riv',
        ),
      ),
    );
  }
}

class _SafeRiveAnimation extends StatelessWidget {
  const _SafeRiveAnimation({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return RiveAnimation.asset(
      asset,
      fit: BoxFit.cover,
      onInit: (_) {},
    );
  }
}

class _FallbackMascot extends StatefulWidget {
  const _FallbackMascot({required this.size});

  final double size;

  @override
  State<_FallbackMascot> createState() => _FallbackMascotState();
}

class _FallbackMascotState extends State<_FallbackMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final wobble = (_controller.value - 0.5) * 0.12;
        return Transform.rotate(
          angle: wobble,
          child: child,
        );
      },
      child: _VyriaGlyph(size: widget.size)
          .animate(onPlay: (controller) => controller.repeat())
          .shimmer(
        duration: 1200.ms,
        colors: const [Colors.white60, Colors.white10],
      ),
    );
  }
}

class _VyriaGlyph extends StatelessWidget {
  const _VyriaGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final baseRadius = BorderRadius.circular(size * 0.52);

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            gradient: const RadialGradient(
              center: Alignment(-0.2, -0.2),
              radius: 0.85,
              colors: [Color(0xFFFFE066), Color(0xFFD97706)],
            ),
            borderRadius: baseRadius,
            boxShadow: const [
              BoxShadow(
                color: Color(0x3321364C),
                blurRadius: 28,
                offset: Offset(0, 18),
              ),
            ],
          ),
        ),
        Positioned(
          top: -size * 0.08,
          child: Container(
            width: size * 0.32,
            height: size * 0.2,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
              ),
              borderRadius: BorderRadius.circular(size * 0.16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x3321A1F1),
                  blurRadius: 10,
                  offset: Offset(0, 6),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: size * 0.18,
          child: Container(
            width: size * 0.76,
            height: size * 0.76,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF4338CA)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(size * 0.46),
            ),
          ),
        ),
        Positioned(
          top: size * 0.32,
          left: size * 0.24,
          child: _VyriaEye(size: size * 0.2),
        ),
        Positioned(
          top: size * 0.32,
          right: size * 0.24,
          child: _VyriaEye(size: size * 0.2),
        ),
        Positioned(
          top: size * 0.48,
          child: Transform.rotate(
            angle: -0.2,
            child: Container(
              width: size * 0.18,
              height: size * 0.22,
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347),
                borderRadius: BorderRadius.circular(size * 0.12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33F59E0B),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          top: size * 0.62,
          child: Container(
            width: size * 0.46,
            height: size * 0.2,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.4),
              border: Border(
                bottom: BorderSide(
                  color: Colors.white.withOpacity(0.85),
                  width: size * 0.045,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VyriaEye extends StatelessWidget {
  const _VyriaEye({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.5),
      ),
      child: Align(
        alignment: const Alignment(0, 0.15),
        child: Container(
          width: size * 0.45,
          height: size * 0.45,
          decoration: BoxDecoration(
            color: const Color(0xFF1E1B4B),
            borderRadius: BorderRadius.circular(size * 0.22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x551E1B4B),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
