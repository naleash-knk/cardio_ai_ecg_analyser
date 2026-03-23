import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_proj/dashboard/dashboard.dart';
import 'package:go_proj/models/account_creation_data.dart';
import 'package:go_proj/widgets/theme_toggle_button.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  static const String _tagline = 'Guard your rhythm';

  late AnimationController _introController;
  late AnimationController _loopController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    _scaleAnim = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeOutBack,
    );

    _fadeAnim = CurvedAnimation(
      parent: _introController,
      curve: Curves.easeIn,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.22),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _introController,
        curve: Curves.easeOutCubic,
      ),
    );

    _introController.forward();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) {
      return;
    }

    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/home');
      return;
    }

    AccountCreationData? accountData;
    try {
      final DocumentSnapshot<Map<String, dynamic>> userDoc =
          await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final Map<String, dynamic>? data = userDoc.data();
      if (data != null) {
        accountData = AccountCreationData.fromMap(data);
      }
    } catch (_) {
      // If profile fetch fails, continue with logged-in dashboard state.
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DashBoard(accountData: accountData),
      ),
    );
  }

  @override
  void dispose() {
    _introController.dispose();
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary.withOpacity(0.95),
              scheme.secondary.withOpacity(0.82),
              scheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final double shortSide = size.shortestSide;
              final double titleGap = shortSide < 360 ? 20 : 30;
              final double loadingGap = shortSide < 360 ? 28 : 44;
              return Stack(
                children: [
                  _buildAnimatedBackdrop(size, scheme),
                  _buildPulseLine(size, scheme),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: _scaleAnim,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                              _buildPulseRing(scheme, shortSide),
                              _buildLogoBadge(theme, scheme, shortSide),
                              ],
                            ),
                        ),
                        SizedBox(height: titleGap),
                        FadeTransition(
                          opacity: _fadeAnim,
                          child: SlideTransition(
                            position: _slideAnim,
                            child: Text(
                              _tagline,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onPrimary.withOpacity(0.92),
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: loadingGap),
                        _buildLoadingIndicator(scheme, shortSide),
                        
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 12,
                    right: 16,
                    child: ThemeToggleButton(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackdrop(Size size, ColorScheme scheme) {
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, child) {
        final t = _loopController.value * math.pi * 2;
        final driftA = math.sin(t) * 14;
        final driftB = math.cos(t * 1.3) * 12;
        final driftC = math.sin(t * 0.7) * 10;
        return Stack(
          children: [
            Positioned(
              top: size.height * 0.12 + driftA,
              left: size.width * 0.08 + driftB,
              child: _buildOrb(
                120,
                scheme.onPrimary.withOpacity(0.08),
              ),
            ),
            Positioned(
              bottom: size.height * 0.18 + driftC,
              right: size.width * 0.06 + driftA,
              child: _buildOrb(
                160,
                scheme.secondary.withOpacity(0.14),
              ),
            ),
            Positioned(
              top: size.height * 0.28 + driftB,
              right: size.width * 0.2 + driftC,
              child: _buildOrb(
                70,
                scheme.onPrimary.withOpacity(0.12),
              ),
            ),
            Positioned(
              bottom: size.height * 0.1 + driftB,
              left: size.width * 0.22 + driftC,
              child: _buildOrb(
                90,
                scheme.primary.withOpacity(0.12),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPulseLine(Size size, ColorScheme scheme) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _loopController,
        builder: (context, child) {
          return CustomPaint(
            size: size,
            painter: _PulseLinePainter(
              progress: _loopController.value,
              color: scheme.onPrimary.withOpacity(0.3),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOrb(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color,
            color.withOpacity(0),
          ],
        ),
      ),
    );
  }

  Widget _buildPulseRing(ColorScheme scheme, double shortSide) {
    final double ringSize =
        (shortSide * 0.52).clamp(150.0, 210.0).toDouble();
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, child) {
        final t = _loopController.value * math.pi * 2;
        final scale = 0.9 + (math.sin(t) * 0.08);
        final opacity = 0.25 + (math.cos(t) * 0.08);
        return Opacity(
          opacity: opacity.clamp(0.1, 0.4).toDouble(),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: ringSize,
              height: ringSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    scheme.onPrimary.withOpacity(0.18),
                    scheme.onPrimary.withOpacity(0.02),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogoBadge(ThemeData theme, ColorScheme scheme, double shortSide) {
    final double logoSize =
        (shortSide * 0.3).clamp(80.0, 110.0).toDouble();
    final double logoPadding =
        (shortSide * 0.075).clamp(18.0, 28.0).toDouble();
    return Container(
      padding: EdgeInsets.all(logoPadding),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [
            theme.cardColor.withOpacity(0.95),
            theme.cardColor.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withOpacity(0.45),
            blurRadius: 32,
            spreadRadius: 6,
          ),
          BoxShadow(
            color: scheme.onPrimary.withOpacity(0.18),
            blurRadius: 18,
            spreadRadius: -2,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(
          color: scheme.onPrimary.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Image.asset(
        'assets/icons/logo.png',
        width: logoSize,
        height: logoSize,
      ),
    );
  }

  Widget _buildLoadingIndicator(ColorScheme scheme, double shortSide) {
    final double indicatorWidth =
        (shortSide * 0.64).clamp(180.0, 260.0).toDouble();
    return Column(
      children: [
        Text(
          "Loading health shield...",
          style: TextStyle(
            color: scheme.onPrimary.withOpacity(0.95),
            letterSpacing: 0.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: indicatorWidth,
          height: 10,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              color: scheme.onPrimary.withOpacity(0.18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedBuilder(
                    animation: _loopController,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(
                        _loopController.value,
                      );
                      final barWidth = constraints.maxWidth * 0.35;
                      final travel = constraints.maxWidth - barWidth;
                      return Stack(
                        children: [
                          Positioned(
                            left: travel * t,
                            top: 0,
                            bottom: 0,
                            child: Container(
                              width: barWidth,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    scheme.onPrimary.withOpacity(0.1),
                                    scheme.onPrimary.withOpacity(0.6),
                                    scheme.onPrimary.withOpacity(0.1),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedBuilder(
          animation: _loopController,
          builder: (context, child) {
            final active = (_loopController.value * 3).floor() % 3;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (index) {
                final isActive = index == active;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  width: isActive ? 10 : 8,
                  height: isActive ? 10 : 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.onPrimary.withOpacity(
                      isActive ? 0.9 : 0.35,
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }

}

class _PulseLinePainter extends CustomPainter {
  _PulseLinePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;

    final centerY = size.height * 0.52;
    final amplitude = 24.0;
    final length = size.width * 0.75;
    final startX = (size.width - length) / 2;
    final phase = progress * math.pi * 2;

    final path = Path();
    for (int i = 0; i <= 80; i++) {
      final dx = startX + (length * i / 80);
      final wave =
          math.sin((i / 80 * math.pi * 2) + phase) * amplitude * 0.2;
      double spike = 0;
      if (i > 30 && i < 36) {
        spike = -amplitude * (1 - ((i - 30) / 6));
      } else if (i >= 36 && i < 42) {
        spike = amplitude * (1 - ((i - 36) / 6));
      }
      final dy = centerY + wave + spike;
      if (i == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PulseLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
