import 'package:dio/dio.dart';

import '../constants/app_constants.dart';
import '../utils/logger.dart';

/// ZeroChain RPC client for blockchain interactions
class ZeroChainRpcClient {
  final Dio _dio;
  final NetworkConfig network;
  int _requestId = 0;

  ZeroChainRpcClient({required this.network})
      : _dio = Dio(
          BaseOptions(
            baseUrl: network.rpcUrl,
            connectTimeout:
                Duration(seconds: AppConstants.networkTimeoutSeconds),
            receiveTimeout:
                Duration(seconds: AppConstants.networkTimeoutSeconds),
            headers: {'Content-Type': 'application/json'},
          ),
        ) {
    _dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestHeader: false,
        requestBody: false,
        responseHeader: false,
        responseBody: false,
        error: true,
        logPrint: (obj) => AppLogger.debug(obj.toString()),
      ),
    );
  }

  int _nextId() => ++_requestId;

  Future<Map<String, dynamic>> _request({
    required String method,
    List<dynamic>? params,
  }) async {
    final response = await _dio.post(
      '',
      data: {
        'jsonrpc': '2.0',
        'method': method,
        'params': params ?? <dynamic>[],
        'id': _nextId(),
      },
    );

    if (response.data is! Map<String, dynamic>) {
      throw RpcException(code: -32700, message: 'Invalid response format');
    }

    final payload = response.data as Map<String, dynamic>;
    if (payload.containsKey('error')) {
      final error = payload['error'] as Map<String, dynamic>;
      final code = error['code'] as int? ?? -32000;
      final message = error['message'] as String? ?? 'Unknown error';
      throw RpcException(code: code, message: message);
    }

    return payload;
  }

  Future<dynamic> request(String method, [List<dynamic>? params]) async {
    final response = await _request(method: method, params: params);
    return response['result'];
  }

  Future<Map<String, dynamic>> getAccount(String address) async {
    final response = await _request(
      method: 'zero_getAccount',
      params: [address],
    );
    return response['result'] as Map<String, dynamic>;
  }

  Future<dynamic> simulateComputeTx(Map<String, dynamic> tx) {
    return request('zero_simulateComputeTx', [tx]);
  }

  Future<dynamic> submitComputeTx(Map<String, dynamic> tx) {
    return request('zero_submitComputeTx', [tx]);
  }

  Future<dynamic> getComputeTxResult(String txId) {
    return request('zero_getComputeTxResult', [txId]);
  }

  Future<Map<String, dynamic>?> getLatestBlock() async {
    final response = await _request(
      method: 'zero_getLatestBlock',
      params: const <dynamic>[],
    );
    return response['result'] as Map<String, dynamic>?;
  }

  Future<bool> isConnected() async {
    try {
      await getLatestBlock();
      return true;
    } catch (_) {
      return false;
    }
  }
}

class RpcException implements Exception {
  final int code;
  final String message;

  RpcException({required this.code, required this.message});

  @override
  String toString() => 'RpcException($code): $message';
}

String mapRpcErrorMessage({
  required int code,
  required String method,
  required String defaultMessage,
}) {
  return defaultMessage;
}
