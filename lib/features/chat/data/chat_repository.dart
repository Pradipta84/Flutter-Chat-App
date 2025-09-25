import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ChatRepository {
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8000';
    return 'http://127.0.0.1:8000';
  }

  Stream<String> streamAnswer(String prompt, {double? latitude, double? longitude}) async* {
    final root = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    final dio = Dio(BaseOptions(
      baseUrl: root,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Content-Type': 'application/json'},
      responseType: ResponseType.stream,
    ));

    final data = <String, dynamic>{'prompt': prompt};
    if (latitude != null && longitude != null) {
      data['latitude'] = latitude;
      data['longitude'] = longitude;
    }

    final res = await dio.post<ResponseBody>('/chat/stream', data: jsonEncode(data));
    if (res.statusCode != null && res.statusCode! >= 400) {
      throw Exception('HTTP ${res.statusCode}');
    }
    final stream = res.data?.stream;
    if (stream == null) return;
    // Dio yields Stream<Uint8List>; cast to List<int> before decoding
    yield* stream.cast<List<int>>().transform(utf8.decoder);
  }

}


