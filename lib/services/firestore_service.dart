import 'dart:convert';
import 'package:http/http.dart' as http;

class FirestoreService {
  final String _projectId = 'msds-cornerstone'; // e.g., my-app-id
  final String _baseUrl = 'https://firestore.googleapis.com/v1';

  // Add or update document
  Future<Map<String, dynamic>> setDocument({
    required String collectionPath,
    required String docId,
    required Map<String, dynamic> data,
    required String idToken,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/projects/$_projectId/databases/(default)/documents/$collectionPath/$docId',
    );

    final formattedData = _formatToFirestore(data);

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $idToken',
      },
      body: json.encode({'fields': formattedData}),
    );

    if (response.statusCode == 200) {
      return {'success': true, 'response': json.decode(response.body)};
    } else {
      return {
        'success': false,
        'message': json.decode(response.body)['error']['message']
      };
    }
  }

  // Get document
  Future<Map<String, dynamic>> getDocument({
    required String collectionPath,
    required String docId,
    required String idToken,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/projects/$_projectId/databases/(default)/documents/$collectionPath/$docId',
    );

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return {'success': true, 'data': _parseFirestoreData(data['fields'])};
    } else {
      return {
        'success': false,
        'message': json.decode(response.body)['error']['message']
      };
    }
  }

  // List all documents in a collection
  Future<Map<String, dynamic>> listDocuments({
    required String collectionPath,
    required String idToken,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/projects/$_projectId/databases/(default)/documents/$collectionPath',
    );

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List<Map<String, dynamic>> docs = [];

      for (var doc in data['documents'] ?? []) {
        docs.add({
          'name': doc['name'].split('/').last,
          'fields': _parseFirestoreData(doc['fields']),
        });
      }

      return {'success': true, 'documents': docs};
    } else {
      return {
        'success': false,
        'message': json.decode(response.body)['error']['message']
      };
    }
  }

  // Delete document
  Future<Map<String, dynamic>> deleteDocument({
    required String collectionPath,
    required String docId,
    required String idToken,
  }) async {
    final url = Uri.parse(
      '$_baseUrl/projects/$_projectId/databases/(default)/documents/$collectionPath/$docId',
    );

    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $idToken'},
    );

    if (response.statusCode == 200) {
      return {'success': true};
    } else {
      return {
        'success': false,
        'message': json.decode(response.body)['error']['message']
      };
    }
  }

  /// Converts a simple Map<String, dynamic> to Firestore REST format
  Map<String, dynamic> _formatToFirestore(Map<String, dynamic> data) {
    final Map<String, dynamic> formatted = {};

    data.forEach((key, value) {
      if (value is String) {
        formatted[key] = {'stringValue': value};
      } else if (value is int) {
        formatted[key] = {'integerValue': value.toString()};
      } else if (value is double) {
        formatted[key] = {'doubleValue': value};
      } else if (value is bool) {
        formatted[key] = {'booleanValue': value};
      } else if (value is Map) {
        formatted[key] = {'mapValue': {'fields': _formatToFirestore(Map<String, dynamic>.from(value))}};
      } else if (value is List) {
        formatted[key] = {
          'arrayValue': {
            'values': value.map((e) => _formatToFirestore({'val': e})['val']).toList()
          }
        };
      } else {
        formatted[key] = {'stringValue': value.toString()};
      }
    });

    return formatted;
  }

  /// Converts Firestore REST response to a clean Map
  Map<String, dynamic> _parseFirestoreData(Map<String, dynamic> fields) {
    final Map<String, dynamic> result = {};

    fields.forEach((key, value) {
      if (value.containsKey('stringValue')) {
        result[key] = value['stringValue'];
      } else if (value.containsKey('integerValue')) {
        result[key] = int.tryParse(value['integerValue']) ?? value['integerValue'];
      } else if (value.containsKey('doubleValue')) {
        result[key] = value['doubleValue'];
      } else if (value.containsKey('booleanValue')) {
        result[key] = value['booleanValue'];
      } else if (value.containsKey('mapValue')) {
        result[key] = _parseFirestoreData(value['mapValue']['fields']);
      } else if (value.containsKey('arrayValue')) {
        result[key] = (value['arrayValue']['values'] ?? [])
            .map((e) => _parseFirestoreData({'val': e})['val'])
            .toList();
      } else {
        result[key] = null;
      }
    });

    return result;
  }
}
