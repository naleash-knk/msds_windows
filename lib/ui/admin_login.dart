import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:msds_windows/main.dart';
import 'package:msds_windows/ui/admin_dash.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final _userIDController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false, _obscurePassword = true;
  String? _error;

  void _togglePasswordVisibility() => setState(() => _obscurePassword = !_obscurePassword);

  Future<void> _login() async {
    final userID = _userIDController.text.trim(), password = _passwordController.text.trim();
    if (userID.isEmpty || password.isEmpty) {
      setState(() => _error = "Please fill in all fields.");
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      const projectId = 'msds-cornerstone', apiKey = 'AIzaSyDrsHeQdP10NmP_0OTJ9zBHBwLXitTtTyg';
      final url = Uri.parse('https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery?key=$apiKey');
      final body = {
        "structuredQuery": {
          "from": [{"collectionId": "users"}],
          "where": {
            "compositeFilter": {
              "op": "AND",
              "filters": [
                {"fieldFilter": {"field": {"fieldPath": "userID"}, "op": "EQUAL", "value": {"stringValue": userID}}},
                {"fieldFilter": {"field": {"fieldPath": "password"}, "op": "EQUAL", "value": {"stringValue": password}}}
              ]
            }
          },
          "limit": 1
        }
      };
      final response = await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        final doc = data.firstWhere((e) => e.containsKey('document'), orElse: () => null);
        if (doc != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('admin_uid', userID);
          await prefs.setString('admin_role', 'admin');
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context){
            return AdminDashboard(username: userID,);
          }));
        } else {
          setState(() => _error = "Invalid username or password");
        }
      } else {
        setState(() => _error = "Error: ${response.statusCode}");
      }
    } catch (e) {
      setState(() => _error = "Exception: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<String?> _checkUserExists(String userID) async {
    const projectId = 'msds-cornerstone', apiKey = 'AIzaSyDrsHeQdP10NmP_0OTJ9zBHBwLXitTtTyg';
    final url = Uri.parse('https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents:runQuery?key=$apiKey');
    final body = {
      "structuredQuery": {
        "from": [{"collectionId": "users"}],
        "where": {
          "fieldFilter": {
            "field": {"fieldPath": "userID"},
            "op": "EQUAL",
            "value": {"stringValue": userID}
          }
        },
        "limit": 1
      }
    };
    final response = await http.post(url, headers: {"Content-Type": "application/json"}, body: jsonEncode(body));
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      final doc = data.firstWhere((e) => e.containsKey('document'), orElse: () => null);
      return doc != null ? doc['document']['name'] as String : null;
    }
    return null;
  }

  Future<void> _changePassword() async {
    final userID = _userIDController.text.trim();
    if (userID.isEmpty) {
      setState(() => _error = "Please enter your User ID first.");
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final exists = await _checkUserExists(userID);
      if (exists != null && exists.isNotEmpty) {
        String? newPassword = await showDialog<String>(
          context: context,
          builder: (context) {
            final _newPassController = TextEditingController();
            return AlertDialog(
              title: const Text("Forget Password"),
              content: TextField(
                controller: _newPassController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "New Password"),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                ElevatedButton(onPressed: () => Navigator.pop(context, _newPassController.text.trim()), child: const Text("Change")),
              ],
            );
          },
        );
        if (newPassword != null && newPassword.isNotEmpty) {
          final docName = exists;
          final updateUrl = Uri.parse('https://firestore.googleapis.com/v1/$docName?key=AIzaSyDrsHeQdP10NmP_0OTJ9zBHBwLXitTtTyg&updateMask.fieldPaths=password');
          final updateBody = {"fields": {"password": {"stringValue": newPassword}}};
          final updateResp = await http.patch(updateUrl, headers: {"Content-Type": "application/json"}, body: jsonEncode(updateBody));
          setState(() => _error = updateResp.statusCode == 200 ? "Password changed successfully!" : "Failed to update password.");
        }
      } else {
        setState(() => _error = "User ID does not exist.");
      }
    } catch (e) {
      setState(() => _error = "Exception: $e");
    } finally {
      setState(() => _loading = false);
    }
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
                        const Icon(Icons.admin_panel_settings, size: 64, color: Colors.blueAccent),
                        const SizedBox(height: 16),
                        const Text(
                          "Welcome Admin",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Color(0xFF2193b0)),
                        ),
                        const SizedBox(height: 32),
                        TextField(
                          controller: _userIDController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.person_outline),
                            labelText: "User ID",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.lock_outline),
                            labelText: "Password",
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: _togglePasswordVisibility,
                              tooltip: _obscurePassword ? 'Show Password' : 'Hide Password',
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(_error!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                          ),
                        _loading
                            ? const CircularProgressIndicator()
                            : Column(
                                children: [
                                  SizedBox(
                                    width: double.infinity,
                                    height: 50,
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.login, size: 24),
                                      label: const Text("Login", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blueAccent,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                        elevation: 8,
                                        shadowColor: Colors.blueAccent.withOpacity(0.3),
                                      ),
                                      onPressed: _login,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    icon: const Icon(Icons.password, color: Colors.blueAccent),
                                    label: const Text("Forget Password", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                    onPressed: _changePassword,
                                  ),
                                ],
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
    );
  }
}
