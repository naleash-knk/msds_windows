import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:msds_windows/main.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';

const String firebaseBucket = 'msds-cornerstone.firebasestorage.app';


class CustomerDashboard extends StatefulWidget {
  final String userName;
  

   CustomerDashboard({
    super.key,
  required this.userName
  });

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  final TextEditingController _searchController = TextEditingController();
  bool istypeing = false;
  List<Map<String, dynamic>> fileData = [];
  List<Map<String, dynamic>> filteredFileData = [];
  List<String> searchSuggestions = [];
  String selectedSuggestion = '';

  bool isLoading = false;
  bool isSearching = false;
  String status = '';
  String? openingFilePath, downloadingFilePath;
  String selectedExtension = '';
  String selectedFolder = 'ALL';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    
    Future.delayed(const Duration(milliseconds: 400), _showWelcomeDialog);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String getFolderName(String path) {
    final parts = p.split(path);
    return parts.length > 1 ? parts[parts.length - 2] : '';
  }

  List<String> getFileExtensions(List<Map<String, dynamic>> files) {
    final exts = <String>{};
    for (var file in files) {
      final ext = p.extension(file['name']);
      if (ext.isNotEmpty) exts.add(ext);
    }
    return exts.toList();
  }

  List<String> getFolderNames(List<Map<String, dynamic>> files) {
    final folders = <String>{};
    for (var file in files) {
      final folder = getFolderName(file['path']);
      if (folder.isNotEmpty) folders.add(folder);
    }
    return folders.toList();
  }

  List<Map<String, dynamic>> sortFilesAndFolders(List<Map<String, dynamic>> files) {
    files.sort((a, b) {
      final aPath = a['path'] as String;
      final bPath = b['path'] as String;
      bool aIsRoot = p.dirname(aPath) == 'uploads';
      bool bIsRoot = p.dirname(bPath) == 'uploads';
      if (aIsRoot && !bIsRoot) return -1;
      if (!aIsRoot && bIsRoot) return 1;
      if (!aIsRoot && !bIsRoot) {
        final aFolder = p.split(aPath).length > 2 ? p.split(aPath)[1].toLowerCase() : '';
        final bFolder = p.split(bPath).length > 2 ? p.split(bPath)[1].toLowerCase() : '';
        final folderCompare = aFolder.compareTo(bFolder);
        if (folderCompare != 0) return folderCompare;
      }
      return a['name'].toLowerCase().compareTo(b['name'].toLowerCase());
    });
    return files;
  }

  Future<void> fetchFiles() async {
    setState(() => isLoading = true);
    try {
      final url = 'https://firebasestorage.googleapis.com/v0/b/$firebaseBucket/o?prefix=uploads/';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<Map<String, dynamic>> files = [];
        if (data['items'] != null) {
          for (final item in data['items']) {
            final fileName = item['name'].split('/').last;
            if (fileName.isEmpty) continue;
            files.add({
              'name': fileName,
              'path': item['name'],
              'isFolder': false,
              'url': "https://firebasestorage.googleapis.com/v0/b/$firebaseBucket/o/${Uri.encodeComponent(item['name'])}?alt=media",
            });
          }
        }
        setState(() {
          fileData = sortFilesAndFolders(files);
          filteredFileData = sortFilesAndFolders(files);
        });
      } else {
        setState(() => status = "❌ Error fetching files");
      }
    } catch (e) {
      setState(() => status = "❌ Error fetching files: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchSearchSuggestions(String query) async {
    setState(() {
      isSearching = true;
      searchSuggestions = [];
    });
    try {
      final url = 'https://firebasestorage.googleapis.com/v0/b/$firebaseBucket/o?prefix=uploads/';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final Set<String> suggestions = {};
        final List<Map<String, dynamic>> files = [];
        if (data['items'] != null) {
          for (final item in data['items']) {
            final fileName = item['name'].split('/').last;
            if (fileName.isEmpty) continue;
            if (fileName.toLowerCase().contains(query.toLowerCase())) {
              suggestions.add(fileName);
              files.add({
                'name': fileName,
                'path': item['name'],
                'isFolder': false,
                'url': "https://firebasestorage.googleapis.com/v0/b/$firebaseBucket/o/${Uri.encodeComponent(item['name'])}?alt=media",
              });
            }
          }
        }
        setState(() {
          searchSuggestions = suggestions.toList();
          if (selectedSuggestion.isNotEmpty) {
            filteredFileData = sortFilesAndFolders(
              files.where((f) => f['name'] == selectedSuggestion).toList(),
            );
          } else {
            filteredFileData = sortFilesAndFolders(files);
          }
        });
      }
    } catch (_) {
      // ignore errors for suggestions
    } finally {
      setState(() => isSearching = false);
    }
  }

  void _onSearchChanged([String? value]) {
    final query = (value ?? _searchController.text).trim().toLowerCase();
    setState(() {
      searchSuggestions = [];
      List<Map<String, dynamic>> files = List<Map<String, dynamic>>.from(fileData);

      if (selectedExtension.isNotEmpty) {
        files = files.where((f) => p.extension(f['name']) == selectedExtension).toList();
      }
      if (selectedFolder != 'ALL') {
        files = files.where((f) {
          final folder = getFolderName(f['path']);
          return selectedFolder == '' ? folder == '' : folder == selectedFolder;
        }).toList();
      }
      if (query.isNotEmpty) {
        files = files.where((f) => f['name'].toLowerCase().contains(query)).toList();
      }
      filteredFileData = sortFilesAndFolders(files);
    });

    if ((value ?? _searchController.text).trim().isNotEmpty) {
      _fetchSearchSuggestions((value ?? _searchController.text).trim());
    }
  }

  void _onSuggestionTap(String suggestion) {
    setState(() {
      selectedSuggestion = suggestion;
      _searchController.text = suggestion;
      searchSuggestions = [];
    });
    _fetchSearchSuggestions(suggestion);
  }

  Future<void> _viewFile(String url, String fileName, String filePath) async {
    setState(() => openingFilePath = filePath);
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        await OpenFile.open(file.path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Failed to open file")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Error opening file: $e")));
    } finally {
      setState(() => openingFilePath = null);
    }
  }

  Future<void> _downloadFile(String url, String fileName, String filePath) async {
    setState(() => downloadingFilePath = filePath);
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        var status = await Permission.storage.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Storage permission denied")));
          setState(() => downloadingFilePath = null);
          return;
        }
      }
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        Directory? directory;
        if (Platform.isAndroid) {
          directory = await getExternalStorageDirectory();
        } else if (Platform.isIOS) {
          directory = await getApplicationDocumentsDirectory();
        } else {
          directory = await getDownloadsDirectory();
        }
        if (directory == null) throw Exception("Cannot access storage directory");
        final file = File('${directory.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Downloaded to ${file.path}")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Download failed")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("❌ Download error: $e")));
    } finally {
      setState(() => downloadingFilePath = null);
    }
  }

  Future<void> _confirmLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Logout"),
        content: const Text("Are you sure you want to logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Logout")),
        ],
      ),
    );
    if (shouldLogout == true) {
      Navigator.pushReplacementNamed(context, '/customer_login');
    }
  }

  void _showWelcomeDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 340, 
            minWidth: 0,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade200, Colors.purple.shade100, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: Colors.white,
                child: Icon(Icons.celebration, color: Colors.purple, size: 48),
              ),
              const SizedBox(height: 18),
              ShaderMask(
                shaderCallback: (Rect bounds) {
                  return LinearGradient(
                    colors: [Colors.blueAccent, Colors.purple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds);
                },
                child: const Text(
                  "Welcome,",
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white, 
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "${widget.userName}!",
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Colors.redAccent,
                  letterSpacing: 1.1,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(1, 2),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              const Text(
                "Glad to see you on your dashboard.\nExplore, download, and enjoy your files!",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.amber, size: 22),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      "Let's Go",
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {

    return AnimatedBrandingOverlay(
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('User Dashboard',),
            titleTextStyle: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 23
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, size: 28,color: Colors.black,),
                tooltip: "Logout",
                onPressed: _confirmLogout,
              ),
            ],
          ),
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
                  final isWide = constraints.maxWidth > 700;
                  return Container(
                    width: isWide ? 700 : constraints.maxWidth * 0.98,
                    margin: const EdgeInsets.symmetric(vertical: 32),
                    // OUTER CONTAINER: Gradient border
                    padding: const EdgeInsets.all(12), // Increased thickness of the border
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
                          color: Colors.transparent, // No solid border, handled by outer gradient
                          width: 2,
                        ),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  onTap: (){
                                    istypeing = false;
                                  },
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    labelText: 'Search Using Codes and Files...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: isSearching
                                        ? const Padding(
                                            padding: EdgeInsets.all(10),
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.blue,
                                              ),
                                            ),
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.95),
                                  ),
                                  onChanged: _onSearchChanged,
                                ),
                              ),
                              if (searchSuggestions.isNotEmpty)
                                Positioned(
                                  top: 48,
                                  left: 0,
                                  right: 0,
                                  child: Material(
                                    elevation: 2,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: 220,
                                      constraints: const BoxConstraints(maxHeight: 200),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: searchSuggestions.length,
                                        itemBuilder: (context, idx) {
                                          final suggestion = searchSuggestions[idx];
                                          final query = _searchController.text.trim();
                                          if (query.isEmpty) {
                                            return InkWell(
                                              onTap: () => _onSuggestionTap(suggestion),
                                              child: Container(
                                                color: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                child: Text(
                                                  suggestion,
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          final matchIndex = suggestion.toLowerCase().indexOf(query.toLowerCase());
                                          if (matchIndex == -1) {
                                            return InkWell(
                                              onTap: () => _onSuggestionTap(suggestion),
                                              child: Container(
                                                color: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                child: Text(
                                                  suggestion,
                                                  style: const TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                          final before = suggestion.substring(0, matchIndex);
                                          final match = suggestion.substring(matchIndex, matchIndex + query.length);
                                          final after = suggestion.substring(matchIndex + query.length);
                                          return InkWell(
                                            onTap: () => _onSuggestionTap(suggestion),
                                            child: Container(
                                              color: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              child: RichText(
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: before,
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: match,
                                                      style: const TextStyle(
                                                        color: Colors.blue,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: after,
                                                      style: const TextStyle(
                                                        color: Colors.black,
                                                        fontWeight: FontWeight.w600,
                                                      ),
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
                            ],
                          ),
                          const SizedBox(height: 20),
                          if (status.isNotEmpty)
                            Text(
                              status,
                              style: TextStyle(
                                color: status.startsWith("✅")
                                    ? Colors.green
                                    : status.startsWith("❌")
                                        ? Colors.red
                                        : Colors.black,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: isLoading
                                ? const Center(child: CircularProgressIndicator())
                                : filteredFileData.isEmpty
                                    ? const Center(child: Text("No files found"))
                                    : ListView.separated(
                                        itemCount: filteredFileData.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey),
                                        itemBuilder: (_, i) {
                                          final file = filteredFileData[i];
                                          final folderName = getFolderName(file['path']);
                                          return ListTile(
                                            title: Text(
                                              folderName.isNotEmpty
                                                  ? "$folderName / ${file['name']}"
                                                  : file['name'],
                                              style: const TextStyle(fontWeight: FontWeight.w600),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            tileColor: Colors.white.withOpacity(0.95),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                downloadingFilePath == file['path']
                                                    ? const SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : IconButton(
                                                        icon: const Icon(Icons.download),
                                                        tooltip: "Download",
                                                        onPressed: () => _downloadFile(file['url'], file['name'], file['path']),
                                                      ),
                                                const SizedBox(width: 8),
                                                openingFilePath == file['path']
                                                    ? const SizedBox(
                                                        width: 24,
                                                        height: 24,
                                                        child: CircularProgressIndicator(strokeWidth: 2),
                                                      )
                                                    : IconButton(
                                                        icon: const Icon(Icons.open_in_new),
                                                        tooltip: "View",
                                                        onPressed: () => _viewFile(file['url'], file['name'], file['path']),
                                                      ),
                                              ],
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
      ),
    );
  }
}
