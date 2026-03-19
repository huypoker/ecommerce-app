import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

Future<String> uploadToCloudinary(Uint8List fileBytes, String filename) async {
  final cloudName = Platform.environment['CLOUDINARY_CLOUD_NAME'];
  final apiKey = Platform.environment['CLOUDINARY_API_KEY'];
  final apiSecret = Platform.environment['CLOUDINARY_API_SECRET'];

  if (cloudName == null || apiKey == null || apiSecret == null) {
    throw Exception('Cloudinary environment variables not set');
  }

  final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final paramsToSign = 'folder=ecommerce&timestamp=$timestamp';
  final signature = sha1.convert(utf8.encode('$paramsToSign$apiSecret')).toString();

  final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
  final request = http.MultipartRequest('POST', uri)
    ..fields['folder'] = 'ecommerce'
    ..fields['timestamp'] = '$timestamp'
    ..fields['api_key'] = apiKey
    ..fields['signature'] = signature
    ..files.add(http.MultipartFile.fromBytes('file', fileBytes, filename: filename));

  final streamedResponse = await request.send();
  final body = await streamedResponse.stream.bytesToString();
  final json = jsonDecode(body) as Map<String, dynamic>;

  if (streamedResponse.statusCode != 200) {
    throw Exception('Cloudinary upload failed: ${json['error']?['message'] ?? body}');
  }

  return json['secure_url'] as String;
}
