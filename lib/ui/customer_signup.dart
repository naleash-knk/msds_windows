import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:msds_windows/main.dart';
import 'dart:convert';

import '../services/config.dart';

class CustomerSignup extends StatefulWidget {
  const CustomerSignup({super.key});

  @override
  State<CustomerSignup> createState() => _CustomerSignupState();
}

class _CustomerSignupState extends State<CustomerSignup> {
  final TextEditingController _usernameController = TextEditingController();
  String _message = "";
  bool _loading = false;

  final String apiKey = firebaseApiKey;
  final String projectId = firebaseProjectId;

  Future<void> _signup() async {
    setState(() {
      _loading = true;
      _message = "";
    });

    final username = _usernameController.text.trim();

    if (username.isEmpty) {
      setState(() {
        _loading = false;
        _message = "Please enter a username.";
      });
      return;
    }

    try {
      final firestoreUrl =
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/customers/$username';
      final docResp = await http.get(Uri.parse(firestoreUrl));

      if (docResp.statusCode == 200) {
        setState(() {
          _loading = false;
          _message = "Username already exists. Try another.";
        });
        return;
      }

      final signupUrl =
          'https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey';
      final signupResp = await http.post(
        Uri.parse(signupUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'returnSecureToken': true}),
      );

      final signupData = jsonDecode(signupResp.body);
      if (signupResp.statusCode != 200) {
        setState(() {
          _loading = false;
          _message = "Signup failed: ${signupData['error']?['message'] ?? 'Unknown error'}";
        });
        return;
      }

      final String uid = signupData['localId'];
      final String idToken = signupData['idToken'];

      final createDocUrl =
          'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/customers?documentId=$username';
      final createDocResp = await http.post(
        Uri.parse(createDocUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          "fields": {
            "username": {"stringValue": username},
            "uid": {"stringValue": uid},
            "created_at": {"timestampValue": DateTime.now().toUtc().toIso8601String()},
          }
        }),
      );

      if (createDocResp.statusCode == 200) {
        setState(() {
          _message = "Signup successful!";
          _usernameController.clear();
        });
      } else {
        setState(() {
          _message = "Failed to save profile: ${createDocResp.body}";
        });
      }
    } catch (e) {
      setState(() {
        _message = "Error: ${e.toString()}";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

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
                          const Icon(Icons.person_add_alt_1, size: 64, color: Colors.blueAccent),
                          const SizedBox(height: 16),
                          const Text(
                            "Create User Account",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Color(0xFF2193b0),
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person),
                              labelText: "Username",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_message.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                _message,
                                style: TextStyle(
                                  color: _message.contains("successful")
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          _loading
                              ? const CircularProgressIndicator()
                              : SizedBox(
                                  width: double.infinity,
                                  height: 50,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.app_registration, size: 24),
                                    label: const Text(
                                      "Sign Up",
                                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blueAccent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      elevation: 8,
                                      shadowColor: Colors.blueAccent.withOpacity(0.3),
                                    ),
                                    onPressed: _signup,
                                  ),
                                ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: () => Navigator.pushReplacementNamed(context, '/customer_login'),
                            child: const Text("Already have an account? Login"),
                          ),
                        ],
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
