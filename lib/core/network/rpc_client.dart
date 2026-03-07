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
          connectTimeout: Duration(seconds: AppConstants.networkTimeoutSeconds),
          receiveTimeout: Duration(seconds: AppConstants.networkTimeoutSeconds),
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
      var message = error['message'] as String? ?? 'Unknown error';
      if (code == -32010 && method == 'eth_sendRawTransaction') {
        message =
            '节点默认关闭 eth_sendRawTransaction，请以 --rpc-enable-eth-write-rpcs 启动节点（仅建议开发环境）。';
      }
      throw RpcException(
        code: code,
        message: message,
      );
    }

    return payload;
  }

  Future<dynamic> request(String method, [List<dynamic>? params]) async {
    final response = await _request(method: method, params: params);
    return response['result'];
  }

  Future<int> getBlockNumber() async {
    final response = await _request(method: 'eth_blockNumber');
    return _parseHexInt(response['result'] as String);
  }

  Future<String> getBalance(String address, {String block = 'latest'}) async {
    final response = await _request(
      method: 'eth_getBalance',
      params: [address, block],
    );
    return response['result'] as String;
  }

  Future<Map<String, dynamic>> getAccount(String address) async {
    final response = await _request(
      method: 'zero_getAccount',
      params: [address],
    );
    return response['result'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getTransaction(String txHash) async {
    final response = await _request(
      method: 'eth_getTransactionByHash',
      params: [txHash],
    );
    return response['result'] as Map<String, dynamic>?;
  }

  Future<String> sendRawTransaction(String signedTx) async {
    final response = await _request(
      method: 'eth_sendRawTransaction',
      params: [signedTx],
    );
    return response['result'] as String;
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

  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    try {
      final response = await _request(
        method: 'eth_getTransactionReceipt',
        params: [txHash],
      );
      return response['result'] as Map<String, dynamic>?;
    } on RpcException catch (error) {
      if (error.code == -32601) {
        return null;
      }
      rethrow;
    }
  }

  Future<String> getGasPrice() async {
    final response = await _request(method: 'eth_gasPrice');
    return response['result'] as String;
  }

  Future<String> estimateGas(Map<String, dynamic> transaction) async {
    final response = await _request(
      method: 'eth_estimateGas',
      params: [transaction],
    );
    return response['result'] as String;
  }

  Future<int> getChainId() async {
    final response = await _request(method: 'eth_chainId');
    return _parseHexInt(response['result'] as String);
  }

  Future<int> getNetworkId() async {
    final response = await _request(method: 'net_version');
    return int.parse(response['result'] as String);
  }

  Future<String> getClientVersion() async {
    final response = await _request(method: 'web3_clientVersion');
    return response['result'] as String;
  }

  Future<String> call({
    required Map<String, dynamic> transaction,
    String block = 'latest',
  }) async {
    final response = await _request(
      method: 'eth_call',
      params: [transaction, block],
    );
    return response['result'] as String;
  }

  Future<int> getTransactionCount(
    String address, {
    String block = 'latest',
  }) async {
    final response = await _request(
      method: 'eth_getTransactionCount',
      params: [address, block],
    );
    return _parseHexInt(response['result'] as String);
  }

  Future<Map<String, dynamic>?> getBlockByNumber(int blockNumber) async {
    final response = await _request(
      method: 'eth_getBlockByNumber',
      params: ['0x${blockNumber.toRadixString(16)}', true],
    );
    return response['result'] as Map<String, dynamic>?;
  }

  Future<Map<String, dynamic>?> getLatestBlock() async {
    final response = await _request(
      method: 'eth_getBlockByNumber',
      params: ['latest', true],
    );
    return response['result'] as Map<String, dynamic>?;
  }

  Future<bool> isConnected() async {
    try {
      await getBlockNumber();
      return true;
    } catch (_) {
      return false;
    }
  }

  int _parseHexInt(String value) {
    return int.parse(
      value.startsWith('0x') ? value.substring(2) : value,
      radix: 16,
    );
  }
}

class RpcException implements Exception {
  final int code;
  final String message;

  RpcException({required this.code, required this.message});

  @override
  String toString() => 'RpcException($code): $message';
}
