import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_proj/home_screen/create_account.dart';
import 'package:go_proj/home_screen/home_screen.dart';
import 'package:go_proj/home_screen/login_screen.dart';
import 'package:go_proj/splash_screen/splash_screen.dart';
import 'package:go_proj/theme_controller.dart';
import 'package:go_proj/theme_datas.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final ThemeController _themeController = ThemeController();

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      controller: _themeController,
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: HealthAppTheme.lightTheme,
            darkTheme: HealthAppTheme.darkTheme,
            themeMode: _themeController.mode,
            builder: (context, child) {
              final mediaQuery = MediaQuery.of(context);
              final clampedScaler = mediaQuery.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.15,
              );
              return MediaQuery(
                data: mediaQuery.copyWith(textScaler: clampedScaler),
                child: child ?? const SizedBox.shrink(),
              );
            },
            initialRoute: "/",
            routes: {
              "/": (context) => const SplashScreen(),
              "/home": (context) => const HomeScreen(),
              "/create_account": (context) => CreateAccount(),
              "/login": (context) => const LoginScreen(),
            },
          );
        },
      ),
    );
  }
}
