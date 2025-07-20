import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:msds_windows/main.dart';
import 'package:msds_windows/services/config.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

const String firebaseBucket = 'msds-cornerstone.firebasestorage.app';

class AdminDashboard extends StatefulWidget {
  String username;
  AdminDashboard({super.key, required this.username});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> uploadedFileData = [];
  List<Map<String, dynamic>> filteredFileData = [];
  bool isLoading = false, isUploading = false, isSearching = false;
  String uploadStatus = '', searchStatus = '';
  String? deletingFilePath, renamingFilePath, openingFilePath, downloadingFilePath;
  Set<String> selectedFilePaths = {};
  String selectedExtension = '', selectedFolder = 'ALL';
  List<String> searchSuggestions = [];
  String selectedSuggestion = '';
  @override
  void initState() {
    super.initState();
    fetchFiles();
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
    if (parts.length > 1) return parts[parts.length - 2];
    return '';
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
      final aPath = a['path'] as String, bPath = b['path'] as String;
      bool aIsRoot = p.dirname(aPath) == 'uploads', bIsRoot = p.dirname(bPath) == 'uploads';
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
  Future<void> _searchFilesOnFirebase(String query) async {
    setState(() {
      isSearching = true;
      searchStatus = "Searching in cloud...";
    });
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
            if (fileName.toLowerCase().contains(query.toLowerCase())) {
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
          filteredFileData = sortFilesAndFolders(files);
          searchStatus = "Found ${filteredFileData.length} file(s)";
        });
      } else {
        setState(() => searchStatus = "❌ Error searching files: ${response.body}");
      }
    } catch (e) {
      setState(() => searchStatus = "❌ Error searching files: $e");
    } finally {
      setState(() => isSearching = false);
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
    } catch (_) {} finally {
      setState(() => isSearching = false);
    }
  }
  void _onSearchChanged([String? value]) {
    final query = (value ?? _searchController.text).trim().toLowerCase();
    setState(() {
      searchSuggestions = [];
      List<Map<String, dynamic>> files = List<Map<String, dynamic>>.from(uploadedFileData);
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
          uploadedFileData = sortFilesAndFolders(files);
          filteredFileData = sortFilesAndFolders(files);
        });
      } else {
        setState(() => uploadStatus = "❌ Error fetching files: ${response.body}");
      }
    } catch (e) {
      setState(() => uploadStatus = "❌ Error fetching files: $e");
    } finally {
      setState(() => isLoading = false);
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Failed to open file")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error opening file: $e")),
      );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("❌ Storage permission denied")),
          );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("✅ Downloaded to ${file.path}")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Download failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Download error: $e")),
      );
    } finally {
      setState(() => downloadingFilePath = null);
    }
  }
  Future<void> _deleteFile(Map<String, dynamic> file) async {
    setState(() => deletingFilePath = file['path']);
    final fullPath = file['path'];
    final response = await http.delete(Uri.parse('$backendUrl/delete-file?filePath=$fullPath'));
    if (response.statusCode == 200) {
      await fetchFiles();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Deleted ${file['name']}")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Delete failed")));
    }
    setState(() => deletingFilePath = null);
  }
  Future<void> _renameFile(Map<String, dynamic> file) async {
    final controller = TextEditingController();
    setState(() => renamingFilePath = file['path']);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename File"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter new filename"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text("Rename")),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      final response = await http.post(
        Uri.parse('$backendUrl/rename-file'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"oldPath": file['path'], "newPath": 'uploads/$newName'}),
      );
      if (response.statusCode == 200) {
        await fetchFiles();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Renamed to $newName")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Rename failed")));
      }
    }
    setState(() => renamingFilePath = null);
  }
  Future<void> _deleteSelectedFiles() async {
    if (selectedFilePaths.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final response = await http.post(
        Uri.parse('$backendUrl/delete-multiple-files'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'filePaths': selectedFilePaths.toList()}),
      );
      if (response.statusCode == 200) {
        await fetchFiles();
        setState(() {
          selectedFilePaths.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Selected files deleted")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Delete failed")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }
  void _showCreatePopup() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create New"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.admin_panel_settings),
              title: const Text("Create New Admin"),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/admin_signup');
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text("Create New User"),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/customer_signup');
              },
            ),
          ],
        ),
      ),
    );
  }
  void logout() {
    Navigator.pushReplacementNamed(context, "/select_role");
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
      logout();
    }
  }
  Future<void> _confirmDeleteFile(Map<String, dynamic> file) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete File"),
        content: Text("Are you sure you want to delete '${file['name']}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await _deleteFile(file);
    }
  }
  Future<void> _confirmRenameFile(Map<String, dynamic> file) async {
    final controller = TextEditingController();
    setState(() => renamingFilePath = file['path']);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename File"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: "Enter new filename"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final shouldRename = await showDialog<bool>(
                context: ctx,
                builder: (confirmCtx) => AlertDialog(
                  title: const Text("Confirm Rename"),
                  content: Text("Rename '${file['name']}' to '${controller.text}'?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(confirmCtx, false), child: const Text("Cancel")),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(confirmCtx, true),
                      child: const Text("Rename"),
                    ),
                  ],
                ),
              );
              if (shouldRename == true) {
                Navigator.pop(ctx, controller.text);
              }
            },
            child: const Text("Rename"),
          ),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      final response = await http.post(
        Uri.parse('$backendUrl/rename-file'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({"oldPath": file['path'], "newPath": 'uploads/$newName'}),
      );
      if (response.statusCode == 200) {
        await fetchFiles();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Renamed to $newName")));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Rename failed")));
      }
    }
    setState(() => renamingFilePath = null);
  }
  Future<void> uploadFolder() async {
    setState(() {
      isUploading = true;
      uploadStatus = "Preparing to upload folder...";
    });
    try {
      String? dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null) {
        setState(() {
          isUploading = false;
          uploadStatus = "❌ No folder selected.";
        });
        return;
      }
      final dir = Directory(dirPath);
      final files = await dir
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is File)
          .cast<File>()
          .toList();
      if (files.isEmpty) {
        setState(() {
          isUploading = false;
          uploadStatus = "❌ No files in selected folder.";
        });
        return;
      }
      final folderName = p.basename(dir.path);
      int uploaded = 0, skipped = 0;
      for (final file in files) {
        final relativePath = file.path.substring(dir.path.length + 1).replaceAll('\\', '/');
        final firebasePath = 'uploads/$folderName/$relativePath';
        if (uploadedFileData.any((f) => f['path'] == firebasePath)) {
          skipped++;
          continue;
        }
        final url = 'https://firebasestorage.googleapis.com/v0/b/$firebaseBucket/o?name=${Uri.encodeComponent(firebasePath)}';
        final bytes = await file.readAsBytes();
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/octet-stream'},
          body: bytes,
        );
        if (response.statusCode == 200) {
          uploaded++;
        }
        setState(() {
          uploadStatus = "Uploading: $uploaded/${files.length} (Skipped: $skipped)";
        });
      }
      setState(() {
        isUploading = false;
        uploadStatus = "✅ Uploaded: $uploaded, Skipped: $skipped";
      });
      await fetchFiles();
    } catch (e) {
      setState(() {
        isUploading = false;
        uploadStatus = "❌ Error uploading folder: $e";
      });
    }
  }
  Future<void> uploadSingleFile() async {
    setState(() {
      isUploading = true;
      uploadStatus = "Preparing to upload file...";
    });
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles();
      if (result == null || result.files.isEmpty) {
        setState(() {
          isUploading = false;
          uploadStatus = "❌ No file selected.";
        });
        return;
      }
      final file = File(result.files.single.path!);
      final fileName = p.basename(file.path);
      final firebasePath = 'uploads/$fileName';
      if (uploadedFileData.any((f) => f['path'] == firebasePath)) {
        setState(() {
          isUploading = false;
          uploadStatus = "❌ File already exists.";
        });
        return;
      }
      final url = 'https://firebasestorage.googleapis.com/v0/b/$firebaseBucket/o?name=${Uri.encodeComponent(firebasePath)}';
      final bytes = await file.readAsBytes();
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/octet-stream'},
        body: bytes,
      );
      if (response.statusCode == 200) {
        setState(() {
          isUploading = false;
          uploadStatus = "✅ Uploaded: $fileName";
        });
        await fetchFiles();
      } else {
        setState(() {
          isUploading = false;
          uploadStatus = "❌ Upload failed: ${response.body}";
        });
      }
    } catch (e) {
      setState(() {
        isUploading = false;
        uploadStatus = "❌ Error uploading file: $e";
      });
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
          constraints: const BoxConstraints(maxWidth: 340, minWidth: 0),
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
                "${widget.username}!",
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
                "Glad to see you on your dashboard.\nManage, upload, and enjoy your files!",
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
    final size = MediaQuery.of(context).size;
    final fileExtensions = getFileExtensions(uploadedFileData);
    final folderNames = getFolderNames(uploadedFileData);
    return AnimatedBrandingOverlay(
      child: WillPopScope(
        onWillPop: () async => false,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Admin Dashboard',style: TextStyle(color: Colors.black),),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Icons.people, size: 28,color: Colors.black,),
                tooltip: "Manage Users",
                onPressed: () {
                  Navigator.pushNamed(context, '/manage_users');
                },
              ),
              IconButton(
                icon: const Icon(Icons.add, size: 28,color: Colors.black,),
                tooltip: "Create",
                onPressed: _showCreatePopup,
              ),
              IconButton(
                icon: const Icon(Icons.logout, size: 28,color:Colors.black),
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
                        children: [
                          Stack(
                            children: [
                              SizedBox(
                                width: 220,
                                child: TextField(
                                  controller: _searchController,
                                  decoration: InputDecoration(
                                    labelText: 'Search files or folders...',
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
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              DropdownButton<String>(
                                value: selectedExtension,
                                hint: const Text("Type"),
                                items: [
                                  const DropdownMenuItem(value: '', child: Text("All Types")),
                                  ...fileExtensions.map((ext) => DropdownMenuItem(
                                        value: ext,
                                        child: Text(ext.isEmpty ? "No Ext" : ext),
                                      )),
                                ],
                                onChanged: (val) {
                                  setState(() => selectedExtension = val!);
                                  _onSearchChanged();
                                },
                              ),
                              DropdownButton<String>(
                                value: folderNames.contains(selectedFolder) || selectedFolder == 'ALL' || selectedFolder == ''
                                    ? selectedFolder
                                    : 'ALL',
                                hint: const Text("Folder"),
                                items: [
                                  const DropdownMenuItem(value: 'ALL', child: Text("All Folders")),
                                  const DropdownMenuItem(value: '', child: Text("Base Folder (uploads/)")),
                                  ...folderNames
                                    .where((folder) => folder.isNotEmpty)
                                    .map((folder) => DropdownMenuItem(
                                      value: folder,
                                      child: Text(folder),
                                    )),
                                ],
                                onChanged: (val) {
                                  setState(() => selectedFolder = val!);
                                  _onSearchChanged();
                                },
                              ),
                              ElevatedButton.icon(
                                onPressed: uploadFolder,
                                icon: const Icon(Icons.folder_copy),
                                label: const Text("Upload Folder"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                onPressed: uploadSingleFile,
                                icon: const Icon(Icons.file_upload),
                                label: const Text("Upload File"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                              if (selectedFilePaths.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: isLoading ? null : _deleteSelectedFiles,
                                  icon: const Icon(Icons.delete),
                                  label: const Text("Delete Selected"),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (isUploading)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(uploadStatus)),
                                ],
                              ),
                            ),
                          if (!isUploading && uploadStatus.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(uploadStatus),
                            ),
                          if (isLoading)
                            const Expanded(
                              child: Center(
                                child: CircularProgressIndicator(color: Colors.blue),
                              ),
                            )
                          else
                            Expanded(
                              child: filteredFileData.isEmpty
                                  ? const Center(child: Text("No files found"))
                                  : ListView.separated(
                                      itemCount: filteredFileData.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.grey),
                                      itemBuilder: (_, i) {
                                        final file = filteredFileData[i];
                                        final isSelected = selectedFilePaths.contains(file['path']);
                                        final folderName = getFolderName(file['path']);
                                        return ListTile(
                                          leading: Checkbox(
                                            value: isSelected,
                                            onChanged: (checked) {
                                              setState(() {
                                                if (checked == true) {
                                                  selectedFilePaths.add(file['path']);
                                                } else {
                                                  selectedFilePaths.remove(file['path']);
                                                }
                                              });
                                            },
                                          ),
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
                                              renamingFilePath == file['path']
                                                  ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : IconButton(
                                                      icon: const Icon(Icons.edit),
                                                      tooltip: "Rename",
                                                      onPressed: () => _confirmRenameFile(file),
                                                    ),
                                              deletingFilePath == file['path']
                                                  ? const SizedBox(
                                                      width: 24,
                                                      height: 24,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    )
                                                  : IconButton(
                                                      icon: const Icon(Icons.delete),
                                                      tooltip: "Delete",
                                                      onPressed: () => _confirmDeleteFile(file),
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
