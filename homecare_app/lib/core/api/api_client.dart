import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

/// Một trình bao bọc (wrapper) cho Dio để quản lý các request, interceptor,
/// và logic tự động làm mới token.
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  ApiClient(String baseUrl, this._secureStorage)
      : _dio = Dio(
          BaseOptions(baseUrl: _normalizeBaseUrl(baseUrl)),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        // 1. Tự động thêm access token vào header
        onRequest: (options, handler) async {
          final accessToken = await _secureStorage.read(key: StorageKeys.accessToken);
          if (accessToken != null) {
            options.headers['Authorization'] = 'Bearer $accessToken';
          }
          return handler.next(options);
        },

        // 2. Xử lý lỗi, đặc biệt là lỗi 401 để refresh token
        onError: (DioException e, handler) async {
          final refreshPath = _resolvePath('auth/refresh');
          final isRefreshRequest =
              e.requestOptions.path == refreshPath || e.requestOptions.path == '/$refreshPath';
          if (e.response?.statusCode == 401 && !isRefreshRequest) {
            try {
              final refreshToken = await _secureStorage.read(key: StorageKeys.refreshToken);
              if (refreshToken == null) {
                // Không có refresh token, không thể làm gì hơn
                return handler.next(e);
              }

              // Gọi API để lấy token mới
              final response = await _dio.post(
                refreshPath,
                data: {'refreshToken': refreshToken},
              );

              final newAccessToken = response.data['accessToken'] as String?;
              final newRefreshToken = response.data['refreshToken'] as String?;

              if (newAccessToken != null && newRefreshToken != null) {
                // Lưu token mới
                await _secureStorage.write(key: StorageKeys.accessToken, value: newAccessToken);
                await _secureStorage.write(key: StorageKeys.refreshToken, value: newRefreshToken);

                // Cập nhật header của request đã lỗi và thử lại
                final updatedOptions = e.requestOptions;
                updatedOptions.headers['Authorization'] = 'Bearer $newAccessToken';

                final clonedRequest = await _dio.fetch(updatedOptions);
                return handler.resolve(clonedRequest);
              } else {
                return handler.next(e);
              }

            } on DioException {
              // Nếu refresh token cũng thất bại (ví dụ: đã hết hạn),
              // xóa tất cả token và trả về lỗi ban đầu.
              await _secureStorage.deleteAll();
              return handler.next(e);
            }
          }
          return handler.next(e);
        },
      ),
    );
  }

  // Các phương thức để DataSource sử dụng
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) =>
      _dio.get(_resolvePath(path), queryParameters: queryParameters);
  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(_resolvePath(path), data: data);
  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(_resolvePath(path), data: data);
  Future<Response> delete(String path) => _dio.delete(_resolvePath(path));

  /// Allow callers (primarily tests or dependency setup) to register
  /// additional interceptors such as logging utilities.
  void addInterceptor(Interceptor interceptor) => _dio.interceptors.add(interceptor);

  /// Exposes a way for tests to inject a mocked [HttpClientAdapter].
  set httpClientAdapter(HttpClientAdapter adapter) => _dio.httpClientAdapter = adapter;

  static String _normalizeBaseUrl(String baseUrl) {
    return baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
  }

  static String _resolvePath(String path) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return 'api';
    }

    final sanitized = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
    return sanitized.startsWith('api/') ? sanitized : 'api/$sanitized';
  }
}
