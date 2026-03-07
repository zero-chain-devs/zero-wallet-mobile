import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/network/rpc_client.dart';
import '../../core/utils/crypto_utils.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/native_compute.dart';
import '../../data/models/wallet_models.dart';

/// Wallet state management provider
class WalletProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  List<WalletAccount> _accounts = <WalletAccount>[];
  WalletAccount? _currentAccount;
  WalletNetwork _currentNetwork = WalletNetwork.fromConfig(
    NetworkConfig.local,
    isActive: true,
  );
  AccountBalance? _currentBalance;
  List<Transaction> _transactions = <Transaction>[];
  ZeroChainRpcClient? _rpcClient;
  Map<String, String> _networkRpcOverrides = <String, String>{};
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;

  List<WalletAccount> get accounts => _accounts;
  WalletAccount? get currentAccount => _currentAccount;
  WalletNetwork get currentNetwork => _currentNetwork;
  AccountBalance? get currentBalance => _currentBalance;
  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isInitialized => _isInitialized;
  bool get hasWallet => _accounts.isNotEmpty;
  String get currentRpcUrl => _currentNetwork.rpcUrl;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final networkId =
          prefs.getString(AppConstants.storageKeyCurrentNetwork) ??
          NetworkConfig.local.id;
      _networkRpcOverrides = _loadRpcOverrides(prefs);
      _currentNetwork = _getNetworkById(networkId);
      _rpcClient = ZeroChainRpcClient(network: _currentNetwork.toConfig());

      final storedAccounts = await _secureStorage.read(
        key: AppConstants.storageKeyWalletAccounts,
      );
      if (storedAccounts != null && storedAccounts.isNotEmpty) {
        final decoded = jsonDecode(storedAccounts) as List<dynamic>;
        _accounts = decoded
            .map(
              (item) => WalletAccount.fromJson(
                Map<String, dynamic>.from(item as Map),
              ),
            )
            .map(_normalizeAccountAddress)
            .toList();
      } else {
        _accounts = <WalletAccount>[];
      }

      final currentAccountId = await _secureStorage.read(
        key: AppConstants.storageKeyCurrentAccountId,
      );
      if (_accounts.isNotEmpty) {
        _currentAccount = _selectCurrentAccount(currentAccountId);
        _accounts = _markCurrent(_accounts, _currentAccount?.id);
        await refreshBalance();
      } else {
        _currentAccount = null;
        _currentBalance = null;
      }

      _isInitialized = true;
      _error = null;
    } catch (e) {
      _error = 'Failed to initialize wallet: $e';
      AppLogger.error('Initialize wallet failed', e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<CreateWalletResult> createWallet({
    required String name,
    required String password,
    SignatureScheme signatureScheme = SignatureScheme.ed25519,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (signatureScheme != SignatureScheme.ed25519) {
        return CreateWalletResult(
          success: false,
          error: 'Only native ed25519 wallet is supported',
        );
      }

      final derivedWallet = await CryptoUtils.createNativeWallet();
      final normalizedPrivateKey = CryptoUtils.normalizeHex(
        derivedWallet.privateKey,
      );

      if (_accounts.any(
        (account) =>
            account.address.toLowerCase() ==
            derivedWallet.address.toLowerCase(),
      )) {
        return CreateWalletResult(
          success: false,
          error: 'Account already exists',
        );
      }

      final encryptedPrivateKey = await CryptoUtils.encryptData(
        derivedWallet.privateKey,
        password,
      );

      final account = WalletAccount.create(
        name: name,
        address: derivedWallet.address,
        publicKey: derivedWallet.publicKey,
        privateKeyEncrypted: encryptedPrivateKey,
        signatureScheme: SignatureScheme.ed25519,
      );

      _accounts = _markCurrent(<WalletAccount>[..._accounts, account], account.id);
      _currentAccount = _accounts.firstWhere((item) => item.id == account.id);
      await _persistAccounts();
      await refreshBalance();
      _error = null;

      return CreateWalletResult(
        success: true,
        account: _currentAccount,
        backupValue: normalizedPrivateKey,
        backupTitle: 'Backup Your Native Private Key',
        backupDescription:
            'This ed25519 private key restores your ZeroChain native account.',
      );
    } catch (e) {
      _error = 'Failed to create wallet: $e';
      AppLogger.error('Create wallet failed', e);
      return CreateWalletResult(success: false, error: _error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ImportWalletResult> importWallet({
    required String data,
    required String name,
    required String password,
    required WalletImportMode importMode,
    SignatureScheme signatureScheme = SignatureScheme.ed25519,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      if (signatureScheme != SignatureScheme.ed25519) {
        return ImportWalletResult(
          success: false,
          error: 'Only native ed25519 wallet is supported',
        );
      }

      if (importMode != WalletImportMode.privateKey) {
        return ImportWalletResult(
          success: false,
          error: 'Native wallet import requires private key',
        );
      }

      final derivedWallet = await CryptoUtils.deriveWalletFromPrivateKey(data);

      if (_accounts.any(
        (account) =>
            account.address.toLowerCase() ==
            derivedWallet.address.toLowerCase(),
      )) {
        return ImportWalletResult(
          success: false,
          error: 'Account already exists',
        );
      }

      final encryptedPrivateKey = await CryptoUtils.encryptData(
        derivedWallet.privateKey,
        password,
      );

      final account = WalletAccount.create(
        name: name,
        address: derivedWallet.address,
        publicKey: derivedWallet.publicKey,
        privateKeyEncrypted: encryptedPrivateKey,
        signatureScheme: SignatureScheme.ed25519,
      );

      _accounts = _markCurrent(<WalletAccount>[..._accounts, account], account.id);
      _currentAccount = _accounts.firstWhere((item) => item.id == account.id);
      await _persistAccounts();
      await refreshBalance();
      _error = null;

      return ImportWalletResult(success: true, account: _currentAccount);
    } catch (e) {
      _error = 'Failed to import wallet: $e';
      AppLogger.error('Import wallet failed', e);
      return ImportWalletResult(success: false, error: _error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> switchAccount(String accountId) async {
    WalletAccount? nextAccount;
    for (final account in _accounts) {
      if (account.id == accountId) {
        nextAccount = account;
        break;
      }
    }

    if (nextAccount == null) {
      _error = 'Account not found';
      notifyListeners();
      return;
    }

    _currentAccount = nextAccount;
    _accounts = _markCurrent(_accounts, accountId);
    await _persistAccounts();
    await refreshBalance();
    _error = null;
    notifyListeners();
  }

  Future<void> switchNetwork(String networkId) async {
    try {
      _currentNetwork = _getNetworkById(networkId);
      _rpcClient = ZeroChainRpcClient(network: _currentNetwork.toConfig());

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.storageKeyCurrentNetwork, networkId);

      await refreshBalance();
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to switch network: $e';
      AppLogger.error('Switch network failed', e);
      notifyListeners();
    }
  }

  Future<bool> updateCurrentNetworkRpcUrl(String rpcUrl) async {
    final normalized = _normalizeRpcUrl(rpcUrl);
    if (normalized == null) {
      _error = 'Invalid RPC URL. Use http://host:port or https://host';
      notifyListeners();
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    _networkRpcOverrides[_currentNetwork.id] = normalized;
    await prefs.setString(
      AppConstants.storageKeyNetworkRpcOverrides,
      jsonEncode(_networkRpcOverrides),
    );

    _currentNetwork = _getNetworkById(_currentNetwork.id);
    _rpcClient = ZeroChainRpcClient(network: _currentNetwork.toConfig());
    await refreshBalance();
    _error = null;
    notifyListeners();
    return true;
  }

  Future<bool> resetCurrentNetworkRpcUrl() async {
    final prefs = await SharedPreferences.getInstance();
    _networkRpcOverrides.remove(_currentNetwork.id);
    await prefs.setString(
      AppConstants.storageKeyNetworkRpcOverrides,
      jsonEncode(_networkRpcOverrides),
    );

    _currentNetwork = _getNetworkById(_currentNetwork.id);
    _rpcClient = ZeroChainRpcClient(network: _currentNetwork.toConfig());
    await refreshBalance();
    _error = null;
    notifyListeners();
    return true;
  }

  Future<NativeComputeActionResult> simulateNativeComputeTx({
    required String jsonText,
    required String password,
  }) {
    return _runNativeCompute(
      jsonText: jsonText,
      password: password,
      submit: false,
    );
  }

  Future<NativeComputeActionResult> submitNativeComputeTx({
    required String jsonText,
    required String password,
  }) {
    return _runNativeCompute(
      jsonText: jsonText,
      password: password,
      submit: true,
    );
  }

  Future<NativeComputeActionResult> _runNativeCompute({
    required String jsonText,
    required String password,
    required bool submit,
  }) async {
    if (_currentAccount == null) {
      return NativeComputeActionResult(
        success: false,
        error: 'No active account',
      );
    }

    if (_currentAccount!.signatureScheme != SignatureScheme.ed25519) {
      return NativeComputeActionResult(
        success: false,
        error: 'Current account is not native ed25519',
      );
    }

    _isLoading = true;
    notifyListeners();

    try {
      final privateKeyHex = await getPrivateKey(
        _currentAccount!.address,
        password,
      );
      if (privateKeyHex == null || privateKeyHex.isEmpty) {
        return NativeComputeActionResult(
          success: false,
          error: 'Password incorrect or private key unavailable',
        );
      }

      final payload = jsonDecode(jsonText);
      if (payload is! Map) {
        return NativeComputeActionResult(
          success: false,
          error: 'Native compute transaction must be a JSON object',
        );
      }

      final txInput = Map<String, dynamic>.from(payload);
      final signedTx = await NativeCompute.signTransaction(
        input: txInput,
        privateKeyHex: privateKeyHex,
        publicKeyHex: _currentAccount!.publicKey,
      );

      _rpcClient ??= ZeroChainRpcClient(network: _currentNetwork.toConfig());
      final result = submit
          ? await _rpcClient!.submitComputeTx(signedTx)
          : await _rpcClient!.simulateComputeTx(signedTx);

      _error = null;
      return NativeComputeActionResult(
        success: true,
        signedTx: signedTx,
        result: result,
      );
    } catch (e) {
      _error = 'Native compute failed: $e';
      AppLogger.error('Native compute failed', e);
      return NativeComputeActionResult(success: false, error: _error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshBalance() async {
    if (_currentAccount == null) {
      _currentBalance = null;
      return;
    }

    try {
      _rpcClient ??= ZeroChainRpcClient(network: _currentNetwork.toConfig());
      final accountInfo = await _rpcClient!.getAccount(_currentAccount!.address);
      final rawBalance = accountInfo['balance']?.toString() ?? '0x0';

      _currentBalance = AccountBalance.fromRaw(
        address: _currentAccount!.address,
        rawBalance: rawBalance,
        decimals: _currentNetwork.decimals,
        symbol: _currentNetwork.currencySymbol,
      );
      _error = null;
      notifyListeners();
    } catch (e) {
      AppLogger.error('Refresh balance failed', e);
      _currentBalance = AccountBalance.fromRaw(
        address: _currentAccount!.address,
        rawBalance: '0x0',
        decimals: _currentNetwork.decimals,
        symbol: _currentNetwork.currencySymbol,
      );
      _error = 'Balance unavailable on ${_currentNetwork.name}: $e';
      notifyListeners();
    }
  }

  Future<String?> getPrivateKey(String address, String password) async {
    try {
      final account = _accounts.firstWhere(
        (item) => item.address.toLowerCase() == address.toLowerCase(),
      );
      return await CryptoUtils.decryptData(account.privateKeyEncrypted, password);
    } catch (e) {
      AppLogger.error('Get private key failed', e);
      return null;
    }
  }

  Future<void> clearWallet() async {
    await _secureStorage.delete(key: AppConstants.storageKeyWalletAccounts);
    await _secureStorage.delete(key: AppConstants.storageKeyCurrentAccountId);

    _accounts = <WalletAccount>[];
    _currentAccount = null;
    _currentBalance = null;
    _transactions = <Transaction>[];
    _error = null;
    _isInitialized = false;

    notifyListeners();
  }

  WalletNetwork _getNetworkById(String id) {
    var config = NetworkConfig.getById(id) ?? NetworkConfig.local;
    final overrideRpc = _networkRpcOverrides[id];
    if (overrideRpc != null && overrideRpc.isNotEmpty) {
      config = config.copyWith(rpcUrl: overrideRpc, wsUrl: _toWsUrl(overrideRpc));
    }
    return WalletNetwork.fromConfig(config, isActive: true);
  }

  Map<String, String> _loadRpcOverrides(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.storageKeyNetworkRpcOverrides);
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }

    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(key, value.toString()));
    } catch (_) {
      return <String, String>{};
    }
  }

  String? _normalizeRpcUrl(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return null;
    }

    return uri.toString();
  }

  String _toWsUrl(String rpcUrl) {
    if (rpcUrl.startsWith('https://')) {
      return rpcUrl.replaceFirst('https://', 'wss://');
    }
    if (rpcUrl.startsWith('http://')) {
      return rpcUrl.replaceFirst('http://', 'ws://');
    }
    return rpcUrl;
  }

  WalletAccount _selectCurrentAccount(String? accountId) {
    if (accountId != null) {
      for (final account in _accounts) {
        if (account.id == accountId) {
          return account;
        }
      }
    }

    return _accounts.first;
  }

  List<WalletAccount> _markCurrent(
    List<WalletAccount> accounts,
    String? currentAccountId,
  ) {
    return accounts
        .map(
          (account) => account.copyWith(isCurrent: account.id == currentAccountId),
        )
        .toList();
  }

  WalletAccount _normalizeAccountAddress(WalletAccount account) {
    try {
      final normalized = CryptoUtils.normalizeNativeAddress(account.address);
      return account.copyWith(address: normalized, signatureScheme: SignatureScheme.ed25519);
    } catch (_) {}

    try {
      final normalized = CryptoUtils.formatNativeAddressFromPublicKey(account.publicKey);
      return account.copyWith(address: normalized, signatureScheme: SignatureScheme.ed25519);
    } catch (_) {
      return account.copyWith(signatureScheme: SignatureScheme.ed25519);
    }
  }

  Future<void> _persistAccounts() async {
    final payload = jsonEncode(_accounts.map((account) => account.toJson()).toList());
    await _secureStorage.write(
      key: AppConstants.storageKeyWalletAccounts,
      value: payload,
    );

    if (_currentAccount != null) {
      await _secureStorage.write(
        key: AppConstants.storageKeyCurrentAccountId,
        value: _currentAccount!.id,
      );
    } else {
      await _secureStorage.delete(key: AppConstants.storageKeyCurrentAccountId);
    }
  }
}

enum WalletImportMode { privateKey }

class CreateWalletResult {
  final bool success;
  final WalletAccount? account;
  final String? backupValue;
  final String? backupTitle;
  final String? backupDescription;
  final String? error;

  CreateWalletResult({
    required this.success,
    this.account,
    this.backupValue,
    this.backupTitle,
    this.backupDescription,
    this.error,
  });
}

class ImportWalletResult {
  final bool success;
  final WalletAccount? account;
  final String? error;

  ImportWalletResult({required this.success, this.account, this.error});
}

class NativeComputeActionResult {
  final bool success;
  final Map<String, dynamic>? signedTx;
  final dynamic result;
  final String? error;

  NativeComputeActionResult({
    required this.success,
    this.signedTx,
    this.result,
    this.error,
  });
}
