import 'package:flutter/material.dart';
import 'package:msds_windows/navigator_screen.dart';
import 'package:msds_windows/ui/admin_login.dart';
import 'package:msds_windows/ui/admin_signup.dart';
import 'package:msds_windows/ui/customer_login.dart';
import 'package:msds_windows/ui/customer_signup.dart';
import 'package:msds_windows/ui/manage_users.dart';
import 'package:msds_windows/ui/splash_screen.dart';
import 'package:flutter/animation.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSDS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: Colors.blue,
        colorScheme: ColorScheme(
          primary: Colors.blue,
          secondary: Colors.red,
          surface: Colors.white,
          background: Colors.white,
          error: Colors.red,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black,
          onBackground: Colors.black,
          onError: Colors.white,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.black),
          bodyMedium: TextStyle(color: Colors.black),
          bodySmall: TextStyle(color: Colors.black),
          titleLarge: TextStyle(color: Colors.black),
          titleMedium: TextStyle(color: Colors.black),
          titleSmall: TextStyle(color: Colors.black),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.blue),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),

        // Auth Navigation Selector
        '/select_role': (context) => const NavigatorScreen(),

        // Customer Routes
        '/customer_login': (context) => const CustomerLogin(),
        '/customer_signup': (context) => const CustomerSignup(),

        // Admin Routes
        '/admin_login': (context) => const AdminLogin(),
        '/admin_signup': (context) => const AdminSignup(),

        '/manage_users':(context) => const ManageCustomers()
      },
    );
  }
}


class AnimatedBrandingOverlay extends StatelessWidget {
  final Widget child;
  const AnimatedBrandingOverlay({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        // Bottom right branding stack
        Positioned(
          bottom: 32,
          right: 32,
          child: _StackedBrandingLogos(),
        ),
      ],
    );
  }
}

class _StackedBrandingLogos extends StatefulWidget {
  const _StackedBrandingLogos({super.key});

  @override
  State<_StackedBrandingLogos> createState() => _StackedBrandingLogosState();
}

class _StackedBrandingLogosState extends State<_StackedBrandingLogos>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;
  late Animation<double> _asianScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _asianScale = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // logo.png with unique blue gradient background and animation
        ScaleTransition(
          scale: _logoScale,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2196F3), Color(0xFF64B5F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.shade100.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Image.asset(
              'assets/images/logo.png',
              height: 48,
              width: 48,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // asian.png to the right, with its own animation and subtle background
        ScaleTransition(
          scale: _asianScale,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.shade100.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(10),
            child: Image.asset(
              'assets/images/asian.png',
              height: 48,
              width: 48,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ],
    );
  }
}


