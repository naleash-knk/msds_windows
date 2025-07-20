import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:msds_windows/main.dart';
import 'package:msds_windows/services/config.dart';
import 'package:msds_windows/ui/customer_dashboard.dart';

const String projectId = firebaseProjectId;

class CustomerLogin extends StatefulWidget {
  const CustomerLogin({super.key});

  @override
  State<CustomerLogin> createState() => _CustomerLoginState();
}

class _CustomerLoginState extends State<CustomerLogin> {
  String username = "";
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<bool> _checkUserExists(String username) async {
    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/customers/$username',
    );
    final response = await http.get(url);
    return response.statusCode == 200;
  }

  void _showMessage(String message) {
    setState(() => _error = message);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    username = _usernameController.text.trim();
    final exists = await _checkUserExists(username);

    setState(() => _isLoading = false);

    if (exists) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context){
          return CustomerDashboard(userName:username);
        })
      );
    } else {
      _showMessage("User not found");
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
                        const Icon(Icons.person, size: 64, color: Colors.blueAccent),
                        const SizedBox(height: 16),
                        const Text(
                          "User Login",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFF2193b0),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Form(
                          key: _formKey,
                          child: TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.person_outline),
                              labelText: "Username",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.9),
                            ),
                            validator: (value) =>
                                value != null && value.trim().isNotEmpty ? null : "Enter your username",
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                            ),
                          ),
                        _isLoading
                            ? const CircularProgressIndicator()
                            : SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.login, size: 24),
                                  label: const Text(
                                    "Login",
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
                                  onPressed: _login,
                                ),
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
