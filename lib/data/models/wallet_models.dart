import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

/// Wallet account model
class WalletAccount extends Equatable {
  final String id;
  final String name;
  final String address;
  final String publicKey;
  final String privateKeyEncrypted;
  final SignatureScheme signatureScheme;
  final DateTime createdAt;
  final bool isCurrent;

  const WalletAccount({
    required this.id,
    required this.name,
    required this.address,
    required this.publicKey,
    required this.privateKeyEncrypted,
    required this.signatureScheme,
    required this.createdAt,
    this.isCurrent = false,
  });

  /// Create a new account
  factory WalletAccount.create({
    required String name,
    required String address,
    required String publicKey,
    required String privateKeyEncrypted,
    SignatureScheme signatureScheme = SignatureScheme.ed25519,
  }) {
    return WalletAccount(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      address: address,
      publicKey: publicKey,
      privateKeyEncrypted: privateKeyEncrypted,
      signatureScheme: signatureScheme,
      createdAt: DateTime.now(),
    );
  }

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'address': address,
    'publicKey': publicKey,
    'privateKeyEncrypted': privateKeyEncrypted,
    'signatureScheme': signatureScheme.name,
    'createdAt': createdAt.toIso8601String(),
    'isCurrent': isCurrent,
  };

  /// Create from JSON
  factory WalletAccount.fromJson(Map<String, dynamic> json) => WalletAccount(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    publicKey: json['publicKey'] as String,
    privateKeyEncrypted: json['privateKeyEncrypted'] as String,
    signatureScheme: _parseSignatureScheme(json['signatureScheme']),
    createdAt: DateTime.parse(json['createdAt'] as String),
    isCurrent: json['isCurrent'] as bool? ?? false,
  );

  /// Create a copy with modified fields
  WalletAccount copyWith({
    String? id,
    String? name,
    String? address,
    String? publicKey,
    String? privateKeyEncrypted,
    SignatureScheme? signatureScheme,
    DateTime? createdAt,
    bool? isCurrent,
  }) {
    return WalletAccount(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      publicKey: publicKey ?? this.publicKey,
      privateKeyEncrypted: privateKeyEncrypted ?? this.privateKeyEncrypted,
      signatureScheme: signatureScheme ?? this.signatureScheme,
      createdAt: createdAt ?? this.createdAt,
      isCurrent: isCurrent ?? this.isCurrent,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    publicKey,
    privateKeyEncrypted,
    signatureScheme,
    createdAt,
    isCurrent,
  ];

  static SignatureScheme _parseSignatureScheme(Object? value) {
    if (value is String && value.trim().toLowerCase() == 'ed25519') {
      return SignatureScheme.ed25519;
    }

    if (value is int && value == 1) {
      return SignatureScheme.ed25519;
    }

    return SignatureScheme.ed25519;
  }
}

/// Signature scheme enumeration
enum SignatureScheme {
  ed25519, // Native ZeroChain
}

/// Account balance model
class AccountBalance extends Equatable {
  final String address;
  final String balance;
  final String balanceFormatted;
  final int decimals;
  final String symbol;
  final DateTime updatedAt;

  const AccountBalance({
    required this.address,
    required this.balance,
    required this.balanceFormatted,
    required this.decimals,
    required this.symbol,
    required this.updatedAt,
  });

  /// Create from raw balance
  factory AccountBalance.fromRaw({
    required String address,
    required String rawBalance,
    int decimals = 18,
    String symbol = 'ZC',
  }) {
    final balance =
        BigInt.tryParse(
          rawBalance.startsWith('0x') ? rawBalance.substring(2) : rawBalance,
          radix: 16,
        ) ??
        BigInt.zero;

    return AccountBalance(
      address: address,
      balance: balance.toString(),
      balanceFormatted: _formatBalance(balance, decimals),
      decimals: decimals,
      symbol: symbol,
      updatedAt: DateTime.now(),
    );
  }

  /// Format balance for display
  static String _formatBalance(BigInt balance, int decimals) {
    final divisor = BigInt.from(10).pow(decimals);
    final whole = balance ~/ divisor;
    final fraction = balance % divisor;

    // Format fraction with leading zeros
    var fractionStr = fraction.toString().padLeft(decimals, '0');
    // Trim trailing zeros but keep at least 4 decimal places
    fractionStr = fractionStr.replaceAll(RegExp(r'0+$'), '');
    if (fractionStr.length > 4) {
      fractionStr = fractionStr.substring(0, 4);
    }

    if (fractionStr.isEmpty) {
      return whole.toString();
    }

    return '$whole.$fractionStr';
  }

  /// Get balance as double
  double get balanceAsDouble {
    final divisor = BigInt.from(10).pow(decimals);
    return int.parse(balance) / int.parse(divisor.toString());
  }

  /// Check if balance is zero
  bool get isZero => balance == '0';

  @override
  List<Object?> get props => [
    address,
    balance,
    balanceFormatted,
    decimals,
    symbol,
    updatedAt,
  ];
}

/// Transaction model
class Transaction extends Equatable {
  final String hash;
  final String from;
  final String to;
  final String value;
  final String valueFormatted;
  final int? blockNumber;
  final DateTime timestamp;
  final TransactionStatus status;
  final String? gasUsed;
  final String? gasPrice;
  final String? nonce;
  final String? input;
  final String? memo;
  final int decimals;
  final String symbol;

  const Transaction({
    required this.hash,
    required this.from,
    required this.to,
    required this.value,
    required this.valueFormatted,
    this.blockNumber,
    required this.timestamp,
    required this.status,
    this.gasUsed,
    this.gasPrice,
    this.nonce,
    this.input,
    this.memo,
    this.decimals = 18,
    this.symbol = 'ZC',
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() => {
    'hash': hash,
    'from': from,
    'to': to,
    'value': value,
    'valueFormatted': valueFormatted,
    'blockNumber': blockNumber,
    'timestamp': timestamp.toIso8601String(),
    'status': status.index,
    'gasUsed': gasUsed,
    'gasPrice': gasPrice,
    'nonce': nonce,
    'input': input,
    'memo': memo,
    'decimals': decimals,
    'symbol': symbol,
  };

  /// Create from JSON
  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
    hash: json['hash'] as String,
    from: json['from'] as String,
    to: json['to'] as String,
    value: json['value'] as String,
    valueFormatted: json['valueFormatted'] as String,
    blockNumber: json['blockNumber'] as int?,
    timestamp: DateTime.parse(json['timestamp'] as String),
    status: TransactionStatus.values[json['status'] as int],
    gasUsed: json['gasUsed'] as String?,
    gasPrice: json['gasPrice'] as String?,
    nonce: json['nonce'] as String?,
    input: json['input'] as String?,
    memo: json['memo'] as String?,
    decimals: json['decimals'] as int? ?? 18,
    symbol: json['symbol'] as String? ?? 'ZC',
  );

  /// Check if transaction is incoming
  bool isIncoming(String currentAddress) {
    return to.toLowerCase() == currentAddress.toLowerCase();
  }

  /// Check if transaction is outgoing
  bool isOutgoing(String currentAddress) {
    return from.toLowerCase() == currentAddress.toLowerCase();
  }

  @override
  List<Object?> get props => [
    hash,
    from,
    to,
    value,
    valueFormatted,
    blockNumber,
    timestamp,
    status,
    gasUsed,
    gasPrice,
    nonce,
    input,
    memo,
    decimals,
    symbol,
  ];
}

/// Transaction status
enum TransactionStatus { pending, confirmed, failed }

/// Network configuration for wallet
/// Network configuration for wallet
class WalletNetwork extends Equatable {
  final String id;
  final String name;
  final NetworkType type;
  final String rpcUrl;
  final String wsUrl;
  final int chainId;
  final int networkId;
  final String explorerUrl;
  final String currencySymbol;
  final int decimals;
  final bool isCustom;
  final bool isActive;

  const WalletNetwork({
    required this.id,
    required this.name,
    required this.type,
    required this.rpcUrl,
    required this.wsUrl,
    required this.chainId,
    required this.networkId,
    required this.explorerUrl,
    required this.currencySymbol,
    required this.decimals,
    this.isCustom = false,
    this.isActive = false,
  });

  factory WalletNetwork.fromConfig(
    NetworkConfig config, {
    bool isActive = false,
  }) {
    return WalletNetwork(
      id: config.id,
      name: config.name,
      type: config.type,
      rpcUrl: config.rpcUrl,
      wsUrl: config.wsUrl,
      chainId: config.chainId,
      networkId: config.networkId,
      explorerUrl: config.explorerUrl,
      currencySymbol: config.currencySymbol,
      decimals: config.decimals,
      isActive: isActive,
    );
  }

  NetworkConfig toConfig() {
    return NetworkConfig(
      id: id,
      name: name,
      type: type,
      rpcUrl: rpcUrl,
      wsUrl: wsUrl,
      chainId: chainId,
      networkId: networkId,
      explorerUrl: explorerUrl,
      isTestnet: type != NetworkType.mainnet,
      currencySymbol: currencySymbol,
      decimals: decimals,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    type,
    rpcUrl,
    wsUrl,
    chainId,
    networkId,
    explorerUrl,
    currencySymbol,
    decimals,
    isCustom,
    isActive,
  ];
}
