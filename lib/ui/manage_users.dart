import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:msds_windows/main.dart';
import 'dart:convert';
import 'package:msds_windows/services/config.dart';

const String projectId = firebaseProjectId;

class ManageCustomers extends StatefulWidget {
  const ManageCustomers({super.key});

  @override
  State<ManageCustomers> createState() => _ManageCustomersState();
}

class _ManageCustomersState extends State<ManageCustomers> {
  bool _isLoading = false;
  String? _error;
  List<String> _customers = [];
  List<String> _filteredCustomers = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCustomers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _filteredCustomers = query.isEmpty
          ? _customers
          : _customers.where((c) => c.toLowerCase().contains(query)).toList();
    });
  }

  Future<void> _fetchCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/customers',
    );
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final docs = data['documents'] as List<dynamic>? ?? [];
      final customers = docs
          .map((doc) => doc['name'].toString().split('/').last)
          .toList();
      setState(() {
        _customers = customers;
        _filteredCustomers = customers;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = "Failed to load customers";
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCustomer(String username) async {
    final url = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/customers/$username',
    );
    final response = await http.delete(url);
    if (response.statusCode == 200 || response.statusCode == 204) {
      setState(() {
        _customers.remove(username);
        _filteredCustomers.remove(username);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deleted $username")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to delete $username")),
      );
    }
  }

  Future<void> _renameCustomer(String oldUsername, String newUsername) async {
    final getUrl = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/customers/$oldUsername',
    );
    final getResponse = await http.get(getUrl);
    if (getResponse.statusCode != 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to fetch $oldUsername")),
      );
      return;
    }
    final data = json.decode(getResponse.body);

    final createUrl = Uri.parse(
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents/customers?documentId=$newUsername',
    );
    final createResponse = await http.post(
      createUrl,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'fields': data['fields']}),
    );
    if (createResponse.statusCode == 200) {
      await _deleteCustomer(oldUsername);
      setState(() {
        _customers.add(newUsername);
        _onSearchChanged();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Renamed $oldUsername to $newUsername")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to rename $oldUsername")),
      );
    }
  }

  void _showRenameDialog(String oldUsername) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename User"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "New Username"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final newUsername = controller.text.trim();
              if (newUsername.isNotEmpty && newUsername != oldUsername) {
                Navigator.pop(context);
                await _renameCustomer(oldUsername, newUsername);
                _fetchCustomers();
              }
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
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
                        const Icon(Icons.manage_accounts, size: 64, color: Colors.blueAccent),
                        const SizedBox(height: 16),
                        const Text(
                          "Manage Users",
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Color(0xFF2193b0),
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.search),
                            hintText: "Search users...",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                            : Expanded(
                                child: _filteredCustomers.isEmpty
                                    ? const Center(child: Text("No Users found."))
                                    : ListView.builder(
                                        itemCount: _filteredCustomers.length,
                                        itemBuilder: (context, index) {
                                          final username = _filteredCustomers[index];
                                          return Card(
                                            margin: const EdgeInsets.symmetric(vertical: 6),
                                            child: ListTile(
                                              leading: const Icon(Icons.person_outline, color: Colors.blueAccent),
                                              title: Text(username),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.orange),
                                                    tooltip: "Rename",
                                                    onPressed: () => _showRenameDialog(username),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.delete, color: Colors.red),
                                                    tooltip: "Delete",
                                                    onPressed: () async {
                                                      final confirm = await showDialog<bool>(
                                                        context: context,
                                                        builder: (context) => AlertDialog(
                                                          title: const Text("Delete Customer"),
                                                          content: Text("Are you sure you want to delete $username?"),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () => Navigator.pop(context, false),
                                                              child: const Text("Cancel"),
                                                            ),
                                                            ElevatedButton(
                                                              onPressed: () => Navigator.pop(context, true),
                                                              child: const Text("Delete"),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                      if (confirm == true) {
                                                        await _deleteCustomer(username);
                                                        _fetchCustomers();
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
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