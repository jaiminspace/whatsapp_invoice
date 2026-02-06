// lib/features/invoice/presentation/pages/splash_page.dart
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app.dart'; // ✅ keep your existing import (adjust if needed)

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..forward();

    _timer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MyAppHome()),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;

          // Step highlight (Create -> Share -> Print)
          final step = (t < 0.34)
              ? 0
              : (t < 0.67)
              ? 1
              : 2;

          return Stack(
            children: [
              _ColorfulBackground(t: t),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = constraints.maxHeight;

                    // Responsive sizes to avoid overflow on small screens
                    final cardW = math.min(w * 0.86, 420.0);
                    final cardPad = math.max(16.0, w * 0.05);
                    final logoSize = math.min(88.0, w * 0.22);

                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(cardPad),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: cardW),
                          child: _FrostCard(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Logo + glow
                                _LogoWithGlow(
                                  t: t,
                                  logoSize: logoSize,
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  "Snap Invoice",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  "Fast invoices. Anywhere you share.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFEAF2FF),
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Steps row (Create • Share • Print)
                                _StepsRow(
                                  t: t,
                                  activeIndex: step,
                                ),

                                const SizedBox(height: 18),

                                // A nice animated “status line”
                                _StatusLine(t: t),

                                const SizedBox(height: 18),

                                // Progress bar
                                _ProgressPill(value: t),

                                // Extra bottom padding for short screens
                                SizedBox(height: math.max(0, h * 0.01)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ColorfulBackground extends StatelessWidget {
  final double t;
  const _ColorfulBackground({required this.t});

  @override
  Widget build(BuildContext context) {
    // Smooth moving gradient
    final a = (math.sin(t * math.pi * 2) * 0.5 + 0.5);
    final b = (math.sin((t + 0.33) * math.pi * 2) * 0.5 + 0.5);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-1 + a * 0.6, -1 + b * 0.6),
          end: Alignment(1 - a * 0.6, 1 - b * 0.6),
          colors: const [
            Color(0xFF6D5BFF), // purple
            Color(0xFF00D4FF), // cyan
            Color(0xFFFF5CB3), // pink
          ],
        ),
      ),
      child: Stack(
        children: [
          _Blob(
            t: t,
            size: 240,
            align: Alignment(-1.1 + a * 0.7, -0.9 + b * 0.6),
            color: const Color(0x66FFFFFF),
          ),
          _Blob(
            t: t,
            size: 280,
            align: Alignment(1.0 - a * 0.7, -0.8 + b * 0.6),
            color: const Color(0x44FFFFFF),
          ),
          _Blob(
            t: t,
            size: 320,
            align: Alignment(-0.2 + a * 0.4, 1.2 - b * 0.7),
            color: const Color(0x33FFFFFF),
          ),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final double t;
  final double size;
  final Alignment align;
  final Color color;

  const _Blob({
    required this.t,
    required this.size,
    required this.align,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final wobble = math.sin(t * math.pi * 2) * 0.06;
    return Align(
      alignment: align,
      child: Transform.rotate(
        angle: t * math.pi * 2 * 0.15,
        child: Transform.scale(
          scale: 1 + wobble,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

class _FrostCard extends StatelessWidget {
  final Widget child;
  const _FrostCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.22),
            Colors.white.withOpacity(0.10),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            blurRadius: 28,
            color: Colors.black.withOpacity(0.16),
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LogoWithGlow extends StatelessWidget {
  final double t;
  final double logoSize;

  const _LogoWithGlow({required this.t, required this.logoSize});

  @override
  Widget build(BuildContext context) {
    final pulse = 0.92 + (math.sin(t * math.pi * 2) * 0.08);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow
        Container(
          width: logoSize * 1.6,
          height: logoSize * 1.6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withOpacity(0.35),
                Colors.white.withOpacity(0.00),
              ],
            ),
          ),
        ),
        Transform.scale(
          scale: pulse,
          child: Container(
            width: logoSize,
            height: logoSize,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(0.30)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Image.asset(
                'assets/icons/app_icon.png', // ✅ your logo
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) =>
                const Icon(Icons.receipt_long, color: Colors.white, size: 40),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StepsRow extends StatelessWidget {
  final double t;
  final int activeIndex;
  const _StepsRow({required this.t, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepChip(
            label: "Create",
            icon: Icons.edit_note_rounded,
            active: activeIndex == 0,
            t: t,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StepChip(
            label: "Share",
            icon: Icons.share_rounded,
            active: activeIndex == 1,
            t: t,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StepChip(
            label: "Print",
            icon: Icons.print_rounded,
            active: activeIndex == 2,
            t: t,
          ),
        ),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final double t;

  const _StepChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final glow = active ? 0.18 + (math.sin(t * math.pi * 2) * 0.06) : 0.10;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(active ? 0.24 : 0.14),
        border: Border.all(
          color: Colors.white.withOpacity(active ? 0.35 : 0.20),
        ),
        boxShadow: [
          if (active)
            BoxShadow(
              blurRadius: 18,
              color: Colors.white.withOpacity(glow),
              offset: const Offset(0, 10),
            ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final double t;
  const _StatusLine({required this.t});

  @override
  Widget build(BuildContext context) {
    final dots = ((t * 12).floor() % 4);
    final dotStr = '.' * dots;

    final String message;
    if (t < 0.34) {
      message = "Preparing your invoice$dotStr";
    } else if (t < 0.67) {
      message = "Getting it ready to share$dotStr";
    } else {
      message = "Almost done$dotStr";
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            message,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFEAF2FF),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProgressPill extends StatelessWidget {
  final double value;
  const _ProgressPill({required this.value});

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);

    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: v,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFEAF2FF),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
