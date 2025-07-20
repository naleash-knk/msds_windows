import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:msds_windows/main.dart';
import 'dart:convert';
import 'package:msds_windows/services/config.dart' as config;

class AdminSignup extends StatefulWidget {
  const AdminSignup({super.key});
  @override
  State<AdminSignup> createState() => _AdminSignupState();
}

class _AdminSignupState extends State<AdminSignup> {
  final _formKey = GlobalKey<FormState>();
  final _userIDController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  static const String apiKey = config.firebaseApiKey, projectId = config.firebaseProjectId;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _error = null; });
    final userID = _userIDController.text.trim(), email = _emailController.text.trim(), password = _passwordController.text.trim();
    try {
      final signupUrl = 'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey';
      final signupRes = await http.post(Uri.parse(signupUrl), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'email': email, 'password': password, 'returnSecureToken': true}));
      final signupData = jsonDecode(signupRes.body);
      if (signupRes.statusCode != 200) {
        setState(() { _isLoading = false; _error = "Signup failed: ${signupData['error']?['message'] ?? 'Unknown error'}"; });
        return;
      }
      final String uid = signupData['localId'], idToken = signupData['idToken'];
      final firestoreUrl = 'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/users?documentId=$userID';
      final firestoreRes = await http.post(
        Uri.parse(firestoreUrl),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $idToken'},
        body: jsonEncode({
          "fields": {
            "userID": {"stringValue": userID},
            "email": {"stringValue": email},
            "password": {"stringValue": password},
            "uid": {"stringValue": uid},
            "createdAt": {"timestampValue": DateTime.now().toUtc().toIso8601String()},
          }
        }),
      );
      if (firestoreRes.statusCode != 200) {
        setState(() { _isLoading = false; _error = "Failed to save admin info: ${firestoreRes.body}"; });
        return;
      }
      setState(() => _isLoading = false);
      _showMessage("Admin account created!");
      Navigator.pushReplacementNamed(context, '/admin_dash');
    } catch (e) {
      setState(() { _isLoading = false; _error = "Exception: $e"; });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size, isWide = size.width > 600;
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
            child: SingleChildScrollView(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final containerWidth = isWide ? 420.0 : size.width * 0.98;
                  return Container(
                    width: containerWidth,
                    margin: const EdgeInsets.symmetric(vertical: 32),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF64B5F6),
                          Color(0xFFBA68C8),
                          Color(0xFFFFFFFF),
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.topLeft,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back, color: Colors.blueAccent, size: 28),
                                onPressed: () => Navigator.of(context).maybePop(),
                                tooltip: 'Back',
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Icon(Icons.admin_panel_settings, size: 64, color: Colors.blueAccent),
                            const SizedBox(height: 16),
                            const Text(
                              "Create Admin Account",
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF2193b0)),
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _userIDController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.badge),
                                labelText: "User ID",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                              ),
                              validator: (value) => value!.isEmpty ? "Enter user ID" : null,
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.email_outlined),
                                labelText: "Email",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) => value!.contains('@') ? null : "Enter valid email",
                            ),
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.lock_outline),
                                labelText: "Password",
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.9),
                              ),
                              obscureText: true,
                              validator: (value) => value!.length >= 6 ? null : "Password must be at least 6 chars",
                            ),
                            const SizedBox(height: 24),
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                              ),
                            _isLoading
                                ? const CircularProgressIndicator()
                                : SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.app_registration, size: 24),
                                      label: const Text("Sign Up", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        elevation: 8,
                                        shadowColor: Colors.blueAccent.withOpacity(0.3),
                                      ),
                                      onPressed: _signUp,
                                    ),
                                  ),
                            const SizedBox(height: 10),
                            TextButton(
                              onPressed: () => Navigator.pushReplacementNamed(context, '/admin_login'),
                              child: const Text("Already have an account? Login"),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
