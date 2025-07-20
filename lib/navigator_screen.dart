import 'package:flutter/material.dart';
import 'package:msds_windows/main.dart';

class NavigatorScreen extends StatelessWidget {
  const NavigatorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return AnimatedBrandingOverlay(
      child: Scaffold(
        extendBodyBehindAppBar: true,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.white,
                Colors.blue,
                Colors.red,
                Colors.black,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, 0.33, 0.66, 1.0],
            ),
          ),
          child: Center(
            child: Container(
              width: isWide ? 420 : size.width * 0.98,
              margin: const EdgeInsets.symmetric(vertical: 32),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF64B5F6), // blue
                    Color(0xFFBA68C8), // purple
                    Color(0xFFFFFFFF), // white
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  stops: [0.0, 0.5, 1.0],
                ),
                borderRadius: BorderRadius.circular(36),
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_circle, size: 64, color: Colors.blueAccent),
                    const SizedBox(height: 16),
                    const Text(
                      "Choose Your Role",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFF2193b0),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _roleButton(
                      icon: Icons.admin_panel_settings,
                      label: "Admin",
                      color: Colors.redAccent,
                      route: '/admin_login',
                      context: context,
                    ),
                    const SizedBox(height: 20),
                    _roleButton(
                      icon: Icons.person,
                      label: "User",
                      color: Colors.blueAccent,
                      route: '/customer_login',
                      context: context,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _roleButton({
    required IconData icon,
    required String label,
    required Color color,
    required String route,
    required BuildContext context,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        icon: Icon(icon, size: 28),
        label: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          elevation: 6,
          shadowColor: color.withOpacity(0.3),
        ),
        onPressed: () => Navigator.pushNamed(context, route),
      ),
    );
  }
}
