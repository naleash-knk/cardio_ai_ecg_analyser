import 'package:flutter/material.dart';
import 'package:go_proj/widgets/theme_toggle_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  static const String _appName = 'Cardio AI';
  static const String _tagline = 'Guard your rhythm';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.primary.withOpacity(0.1),
              scheme.secondary.withOpacity(0.12),
              scheme.surface,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;
              final double basePadding = width < 360 ? 16 : (width > 700 ? 32 : 24);
              final double logoSize = width < 360 ? 34 : 40;
              final double bottomPadding = constraints.maxHeight < 700 ? 20 : 32;

              return Stack(
                children: [
                  _buildBackdrop(scheme, constraints.biggest),
                  Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            basePadding,
                            basePadding,
                            basePadding,
                            basePadding,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 560),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: LinearGradient(
                                          colors: [
                                            theme.cardColor.withOpacity(0.9),
                                            theme.cardColor.withOpacity(0.6),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: scheme.primary.withOpacity(0.2),
                                          width: 1,
                                        ),
                                      ),
                                      child: Image.asset(
                                        'assets/icons/logo.png',
                                        width: logoSize,
                                        height: logoSize,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _appName,
                                            style:
                                                theme.textTheme.headlineMedium?.copyWith(
                                              letterSpacing: 1.8,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _tagline,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: scheme.onSurface.withOpacity(0.7),
                                              letterSpacing: 0.6,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  'Welcome back.',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Cardio AI keeps your rhythm simple and steady with clean, focused tracking.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: scheme.onSurface.withOpacity(0.7),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          basePadding,
                          0,
                          basePadding,
                          bottomPadding,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/create_account');
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: const Text('Create Account'),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/login');
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    side: BorderSide(
                                      color: scheme.primary,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Text(
                                    'Login',
                                    style: TextStyle(
                                      color: scheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

  Widget _buildBackdrop(ColorScheme scheme, Size size) {
    final double shortSide = size.shortestSide;
    final double orbA = shortSide * 0.55;
    final double orbB = shortSide * 0.68;
    return Stack(
      children: [
        Positioned(
          top: -40,
          right: -30,
          child: Container(
            width: orbA.clamp(140.0, 240.0).toDouble(),
            height: orbA.clamp(140.0, 240.0).toDouble(),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  scheme.primary.withOpacity(0.22),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: Container(
            width: orbB.clamp(160.0, 290.0).toDouble(),
            height: orbB.clamp(160.0, 290.0).toDouble(),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  scheme.secondary.withOpacity(0.2),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

}
