import 'dart:convert';
import 'dart:typed_data';
import 'package:shelf/shelf.dart';

class MultipartFile {
  final String fieldName;
  final String? filename;
  final String? contentType;
  final Uint8List bytes;

  MultipartFile({
    required this.fieldName,
    this.filename,
    this.contentType,
    required this.bytes,
  });
}

Future<List<MultipartFile>> parseMultipartRequest(Request request) async {
  final contentType = request.headers['content-type'] ?? '';
  final boundaryMatch = RegExp(r'boundary=(.+)').firstMatch(contentType);
  if (boundaryMatch == null) throw Exception('No boundary found in content-type');

  var boundary = boundaryMatch.group(1)!.trim();
  if (boundary.startsWith('"') && boundary.endsWith('"')) {
    boundary = boundary.substring(1, boundary.length - 1);
  }

  final bodyBytes = await request.read().expand((chunk) => chunk).toList();
  final body = Uint8List.fromList(bodyBytes);
  final boundaryBytes = utf8.encode('--$boundary');
  final files = <MultipartFile>[];

  var start = _indexOf(body, boundaryBytes, 0);
  if (start == -1) return files;

  while (true) {
    start += boundaryBytes.length;
    if (start + 2 <= body.length && body[start] == 0x2D && body[start + 1] == 0x2D) {
      break;
    }
    if (start + 2 <= body.length && body[start] == 0x0D && body[start + 1] == 0x0A) {
      start += 2;
    }

    final nextBoundary = _indexOf(body, boundaryBytes, start);
    if (nextBoundary == -1) break;

    final partBytes = body.sublist(start, nextBoundary);
    final separatorBytes = utf8.encode('\r\n\r\n');
    final headerEnd = _indexOf(partBytes, separatorBytes, 0);
    if (headerEnd == -1) {
      start = nextBoundary;
      continue;
    }

    final headersStr = utf8.decode(partBytes.sublist(0, headerEnd));
    var fileBytes = partBytes.sublist(headerEnd + 4);
    if (fileBytes.length >= 2 &&
        fileBytes[fileBytes.length - 2] == 0x0D &&
        fileBytes[fileBytes.length - 1] == 0x0A) {
      fileBytes = fileBytes.sublist(0, fileBytes.length - 2);
    }

    String? fieldName;
    String? filename;
    String? partContentType;
    for (final line in headersStr.split('\r\n')) {
      final lower = line.toLowerCase();
      if (lower.startsWith('content-disposition:')) {
        final nameMatch = RegExp(r'name="([^"]*)"').firstMatch(line);
        final filenameMatch = RegExp(r'filename="([^"]*)"').firstMatch(line);
        fieldName = nameMatch?.group(1);
        filename = filenameMatch?.group(1);
      } else if (lower.startsWith('content-type:')) {
        partContentType = line.split(':').sublist(1).join(':').trim();
      }
    }

    if (fieldName != null) {
      files.add(MultipartFile(
        fieldName: fieldName,
        filename: filename,
        contentType: partContentType,
        bytes: Uint8List.fromList(fileBytes),
      ));
    }

    start = nextBoundary;
  }

  return files;
}

int _indexOf(Uint8List data, List<int> pattern, int start) {
  for (var i = start; i <= data.length - pattern.length; i++) {
    var found = true;
    for (var j = 0; j < pattern.length; j++) {
      if (data[i + j] != pattern[j]) {
        found = false;
        break;
      }
    }
    if (found) return i;
  }
  return -1;
}
