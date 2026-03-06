import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/crypto.dart' as web3crypto;
import 'package:web3dart/web3dart.dart' as web3;

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
    SignatureScheme signatureScheme = SignatureScheme.secp256k1,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      DerivedWalletData derivedWallet;
      String? encryptedMnemonic;
      String? backupValue;
      String? backupTitle;
      String? backupDescription;

      if (signatureScheme == SignatureScheme.secp256k1) {
        final mnemonic = CryptoUtils.generateMnemonic(wordCount: 12);
        derivedWallet = await CryptoUtils.deriveWalletFromMnemonic(
          mnemonic,
          signatureScheme: signatureScheme,
        );
        encryptedMnemonic = await CryptoUtils.encryptData(mnemonic, password);
        backupValue = mnemonic;
        backupTitle = 'Backup Your EVM Recovery Phrase';
        backupDescription =
            'This BIP39 mnemonic restores your secp256k1 / EVM account.';
      } else {
        derivedWallet = await CryptoUtils.createNativeWallet();
        backupValue = CryptoUtils.normalizeHex(derivedWallet.privateKey);
        backupTitle = 'Backup Your Native Private Key';
        backupDescription =
            'This ed25519 private key restores your ZeroChain native account.';
      }

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
        mnemonicEncrypted: encryptedMnemonic,
        signatureScheme: signatureScheme,
      );

      _accounts = _markCurrent(<WalletAccount>[
        ..._accounts,
        account,
      ], account.id);
      _currentAccount = _accounts.firstWhere((item) => item.id == account.id);
      await _persistAccounts();
      await refreshBalance();
      _error = null;

      return CreateWalletResult(
        success: true,
        account: _currentAccount,
        backupValue: backupValue,
        backupTitle: backupTitle,
        backupDescription: backupDescription,
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
    SignatureScheme signatureScheme = SignatureScheme.secp256k1,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      DerivedWalletData derivedWallet;
      String? encryptedMnemonic;

      if (signatureScheme == SignatureScheme.ed25519) {
        if (importMode != WalletImportMode.privateKey) {
          return ImportWalletResult(
            success: false,
            error: 'Native ed25519 import requires a private key',
          );
        }
        derivedWallet = await CryptoUtils.deriveWalletFromPrivateKey(
          data,
          signatureScheme: SignatureScheme.ed25519,
        );
      } else if (importMode == WalletImportMode.privateKey) {
        derivedWallet = await CryptoUtils.deriveWalletFromPrivateKey(
          data,
          signatureScheme: SignatureScheme.secp256k1,
        );
      } else {
        final mnemonic = data.trim().toLowerCase();
        if (!CryptoUtils.validateMnemonic(mnemonic)) {
          return ImportWalletResult(
            success: false,
            error: 'Invalid mnemonic phrase',
          );
        }
        derivedWallet = await CryptoUtils.deriveWalletFromMnemonic(
          mnemonic,
          signatureScheme: SignatureScheme.secp256k1,
        );
        encryptedMnemonic = await CryptoUtils.encryptData(mnemonic, password);
      }

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
        mnemonicEncrypted: encryptedMnemonic,
        signatureScheme: signatureScheme,
      );

      _accounts = _markCurrent(<WalletAccount>[
        ..._accounts,
        account,
      ], account.id);
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

  Future<SendPaymentResult> sendPayment({
    required String toAddress,
    required String amountText,
    required String password,
  }) async {
    if (_currentAccount == null) {
      return SendPaymentResult(success: false, error: 'No active account');
    }

    if (_currentAccount!.signatureScheme != SignatureScheme.secp256k1) {
      return SendPaymentResult(
        success: false,
        error:
            'Current account is native ed25519. Switch to an EVM account first.',
      );
    }

    if (!_isValidEvmAddress(toAddress)) {
      return SendPaymentResult(
        success: false,
        error: 'Invalid recipient address',
      );
    }

    final amountWei = _parseAmountToBaseUnit(
      amountText,
      _currentNetwork.decimals,
    );
    if (amountWei == null || amountWei <= BigInt.zero) {
      return SendPaymentResult(success: false, error: 'Invalid amount');
    }

    _isLoading = true;
    notifyListeners();

    http.Client? client;
    web3.Web3Client? web3Client;
    try {
      final privateKeyHex = await getPrivateKey(
        _currentAccount!.address,
        password,
      );
      if (privateKeyHex == null || privateKeyHex.isEmpty) {
        return SendPaymentResult(
          success: false,
          error: 'Password incorrect or private key unavailable',
        );
      }

      _rpcClient ??= ZeroChainRpcClient(network: _currentNetwork.toConfig());
      final nonce = await _rpcClient!.getTransactionCount(
        _currentAccount!.address,
      );
      final gasPriceHex = await _rpcClient!.getGasPrice();
      final gasPrice = _parseHexToBigInt(gasPriceHex);
      final chainId = await _rpcClient!.getChainId();

      client = http.Client();
      web3Client = web3.Web3Client(_currentNetwork.rpcUrl, client);
      final credentials = web3.EthPrivateKey.fromHex(privateKeyHex);
      final tx = web3.Transaction(
        from: web3.EthereumAddress.fromHex(_currentAccount!.address),
        to: web3.EthereumAddress.fromHex(toAddress),
        maxGas: AppConstants.defaultGasLimitTransfer,
        gasPrice: web3.EtherAmount.inWei(gasPrice),
        nonce: nonce,
        value: web3.EtherAmount.inWei(amountWei),
      );

      final signed = await web3Client.signTransaction(
        credentials,
        tx,
        chainId: chainId,
      );
      final rawTxHex = web3crypto.bytesToHex(signed, include0x: true);
      final txHash = await _rpcClient!.sendRawTransaction(rawTxHex);

      _error = null;
      await refreshBalance();
      return SendPaymentResult(success: true, txHash: txHash);
    } catch (e) {
      _error = 'Send payment failed: $e';
      AppLogger.error('Send payment failed', e);
      return SendPaymentResult(success: false, error: _error);
    } finally {
      web3Client?.dispose();
      client?.close();
      _isLoading = false;
      notifyListeners();
    }
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
        error:
            'Current account is EVM secp256k1. Switch to a native account first.',
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

  Future<TxConfirmationResult> waitForTransactionConfirmation(
    String txHash, {
    Duration timeout = const Duration(seconds: 90),
    Duration pollInterval = const Duration(seconds: 3),
  }) async {
    _rpcClient ??= ZeroChainRpcClient(network: _currentNetwork.toConfig());

    final startedAt = DateTime.now();
    while (DateTime.now().difference(startedAt) < timeout) {
      try {
        final receipt = await _rpcClient!.getTransactionReceipt(txHash);
        if (receipt != null) {
          final status = (receipt['status'] as String?)?.toLowerCase();
          final blockNumber = (receipt['blockNumber'] as String?) ?? '';
          final confirmed = status == '0x1' || status == '1';
          final failed = status == '0x0' || status == '0';

          if (confirmed) {
            return TxConfirmationResult(
              state: TxConfirmationState.confirmed,
              txHash: txHash,
              blockNumber: blockNumber,
            );
          }

          if (failed) {
            return TxConfirmationResult(
              state: TxConfirmationState.failed,
              txHash: txHash,
              blockNumber: blockNumber,
              error: 'Transaction execution failed on-chain',
            );
          }
        }
      } catch (e) {
        AppLogger.error('Check tx receipt failed', e);
      }

      await Future<void>.delayed(pollInterval);
    }

    return TxConfirmationResult(
      state: TxConfirmationState.pending,
      txHash: txHash,
      error: 'Confirmation timeout, status still pending',
    );
  }

  Future<void> refreshBalance() async {
    if (_currentAccount == null) {
      _currentBalance = null;
      return;
    }

    if (_currentAccount!.signatureScheme != SignatureScheme.secp256k1) {
      _currentBalance = null;
      _error = null;
      notifyListeners();
      return;
    }

    try {
      _rpcClient ??= ZeroChainRpcClient(network: _currentNetwork.toConfig());
      final rawBalance = await _rpcClient!.getBalance(_currentAccount!.address);
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
      return await CryptoUtils.decryptData(
        account.privateKeyEncrypted,
        password,
      );
    } catch (e) {
      AppLogger.error('Get private key failed', e);
      return null;
    }
  }

  Future<String?> getMnemonic(String address, String password) async {
    try {
      final account = _accounts.firstWhere(
        (item) => item.address.toLowerCase() == address.toLowerCase(),
      );
      if (account.mnemonicEncrypted == null) {
        return null;
      }

      return await CryptoUtils.decryptData(
        account.mnemonicEncrypted!,
        password,
      );
    } catch (e) {
      AppLogger.error('Get mnemonic failed', e);
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
      config = config.copyWith(
        rpcUrl: overrideRpc,
        wsUrl: _toWsUrl(overrideRpc),
      );
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

  bool _isValidEvmAddress(String value) {
    final trimmed = value.trim();
    return RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(trimmed);
  }

  BigInt? _parseAmountToBaseUnit(String amountText, int decimals) {
    final cleaned = amountText.trim();
    if (cleaned.isEmpty) {
      return null;
    }

    final match = RegExp(r'^\d+(\.\d+)?$').firstMatch(cleaned);
    if (match == null) {
      return null;
    }

    final parts = cleaned.split('.');
    final whole = BigInt.parse(parts[0]);
    final fraction = parts.length == 2 ? parts[1] : '';
    if (fraction.length > decimals) {
      return null;
    }

    final padded = fraction.padRight(decimals, '0');
    final fracValue = padded.isEmpty ? BigInt.zero : BigInt.parse(padded);
    return whole * BigInt.from(10).pow(decimals) + fracValue;
  }

  BigInt _parseHexToBigInt(String value) {
    final normalized = value.startsWith('0x') ? value.substring(2) : value;
    if (normalized.isEmpty) {
      return BigInt.zero;
    }
    return BigInt.parse(normalized, radix: 16);
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
          (account) =>
              account.copyWith(isCurrent: account.id == currentAccountId),
        )
        .toList();
  }

  Future<void> _persistAccounts() async {
    final payload = jsonEncode(
      _accounts.map((account) => account.toJson()).toList(),
    );
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

enum WalletImportMode { mnemonic, privateKey }

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

class SendPaymentResult {
  final bool success;
  final String? txHash;
  final String? error;

  SendPaymentResult({required this.success, this.txHash, this.error});
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

enum TxConfirmationState { pending, confirmed, failed }

class TxConfirmationResult {
  final TxConfirmationState state;
  final String txHash;
  final String? blockNumber;
  final String? error;

  TxConfirmationResult({
    required this.state,
    required this.txHash,
    this.blockNumber,
    this.error,
  });
}
