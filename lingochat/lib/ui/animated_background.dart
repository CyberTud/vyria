import 'dart:math' as math;

import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
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
        final progress = _controller.value;
        final wave = progress * 2 * math.pi;
        final offsetOne = Alignment(
          math.cos(wave) * 0.7,
          math.sin(wave * 0.8) * 0.7,
        );
        final offsetTwo = Alignment(
          math.cos(wave + math.pi / 3) * 0.9,
          math.sin(wave + math.pi / 4) * 0.9,
        );

        final baseGradient = LinearGradient(
          begin: offsetOne,
          end: offsetTwo,
          colors: const [
            Color(0xFFFFE066),
            Color(0xFFFFB347),
          ],
        );

        final glowColorOne = const Color(0xFFFFF1A6).withOpacity(0.4);
        final glowColorTwo = const Color(0xFFFFD166).withOpacity(0.35);

        return Container(
          decoration: BoxDecoration(
            gradient: baseGradient,
          ),
          child: Stack(
            children: [
              _AnimatedGlow(
                alignment: offsetTwo,
                color: glowColorOne,
                size: MediaQuery.of(context).size.width * 0.9,
                controllerValue: progress,
              ),
              _AnimatedGlow(
                alignment: offsetOne * -1,
                color: glowColorTwo,
                size: MediaQuery.of(context).size.width * 0.7,
                controllerValue: (progress + 0.35) % 1.0,
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.85),
                      Colors.white.withOpacity(0.9),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AnimatedGlow extends StatelessWidget {
  const _AnimatedGlow({
    required this.alignment,
    required this.color,
    required this.size,
    required this.controllerValue,
  });

  final Alignment alignment;
  final Color color;
  final double size;
  final double controllerValue;

  @override
  Widget build(BuildContext context) {
    final animatedAlignment = Alignment(
      alignment.x + (controllerValue - 0.5) * 0.6,
      alignment.y + math.sin(controllerValue * 2 * math.pi) * 0.3,
    );

    return Align(
      alignment: animatedAlignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, Colors.transparent],
          ),
        ),
      ),
    );
  }
}
