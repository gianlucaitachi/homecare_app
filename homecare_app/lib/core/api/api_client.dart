import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/storage_keys.dart';

/// Một trình bao bọc (wrapper) cho Dio để quản lý các request, interceptor,
/// và logic tự động làm mới token.
class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  ApiClient(String baseUrl, this._secureStorage)
      : _dio = Dio(BaseOptions(baseUrl: baseUrl)) {
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
        onError: (DioError e, handler) async {
          if (e.response?.statusCode == 401 && e.requestOptions.path != '/auth/refresh') {
            try {
              final refreshToken = await _secureStorage.read(key: StorageKeys.refreshToken);
              if (refreshToken == null) {
                // Không có refresh token, không thể làm gì hơn
                return handler.next(e);
              }

              // Gọi API để lấy token mới
              final response = await _dio.post('/auth/refresh', data: {'refreshToken': refreshToken});

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

            } on DioError {
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
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) => _dio.get(path, queryParameters: queryParameters);
  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);
  Future<Response> put(String path, {dynamic data}) => _dio.put(path, data: data);
  Future<Response> delete(String path) => _dio.delete(path);
}
