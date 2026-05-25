import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../storage/local_storage.dart';

class DioClient {
  static DioClient? _instance;
  late final Dio _dio;
  Function()? onUnauthorized;

  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(milliseconds: ApiConfig.connectTimeout),
        receiveTimeout: const Duration(milliseconds: ApiConfig.receiveTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await LocalStorage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          if (kDebugMode) {
            debugPrint('[DIO] ${options.method} ${options.path}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            debugPrint('[DIO] ${response.statusCode} ${response.requestOptions.path}');
          }
          handler.next(response);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await LocalStorage.clearToken();
            onUnauthorized?.call();
          }
          if (kDebugMode) {
            debugPrint('[DIO ERROR] ${error.message}');
          }
          handler.next(error);
        },
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint(o.toString()),
      ));
    }
  }

  factory DioClient() {
    _instance ??= DioClient._internal();
    return _instance!;
  }

  Dio get dio => _dio;

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return _retryRequest(() => _dio.get(path, queryParameters: queryParameters));
  }

  Future<Response> post(String path, {dynamic data}) async {
    return _retryRequest(() => _dio.post(path, data: data));
  }

  Future<Response> put(String path, {dynamic data}) async {
    return _retryRequest(() => _dio.put(path, data: data));
  }

  Future<Response> delete(String path) async {
    return _retryRequest(() => _dio.delete(path));
  }

  Future<Response> _retryRequest(Future<Response> Function() request) async {
    int attempts = 0;
    while (true) {
      try {
        return await request();
      } on DioException catch (e) {
        if (attempts >= ApiConfig.maxRetries ||
            e.type != DioExceptionType.connectionTimeout &&
            e.type != DioExceptionType.receiveTimeout) {
          rethrow;
        }
        attempts++;
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
  }
}
