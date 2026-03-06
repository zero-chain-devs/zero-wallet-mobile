/// Application-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Zero Wallet';
  static const String appVersion = '1.0.0';
  static const int defaultDecimals = 18;
  static const String nativeTokenSymbol = 'ZC';
  static const String nativeTokenName = 'ZeroChain';
  static const int maxMemoLength = 256;
  static const int sessionTimeoutSeconds = 300;
  static const int biometricTimeoutSeconds = 30;
  static const int networkTimeoutSeconds = 30;
  static const int connectionRetryAttempts = 3;
  static const int connectionRetryDelayMs = 1000;
  static const int blockTimeSeconds = 10;
  static const int confirmationsRequired = 6;
  static const int dustAmount = 1000;
  static const int defaultGasPrice = 20000000000;
  static const int defaultGasLimitTransfer = 21000;
  static const int defaultGasLimitContract = 100000;
  static const int pbkdf2Iterations = 120000;
  static const String defaultDerivationPath = "m/44'/60'/0'/0/0";

  static const String storageKeyMnemonic = 'encrypted_mnemonic';
  static const String storageKeyPrivateKey = 'encrypted_private_key';
  static const String storageKeyCurrentNetwork = 'current_network';
  static const String storageKeyCustomNetworks = 'custom_networks';
  static const String storageKeyWalletName = 'wallet_name';
  static const String storageKeyBiometricEnabled = 'biometric_enabled';
  static const String storageKeyTheme = 'theme_mode';
  static const String storageKeyCurrency = 'currency';
  static const String storageKeyLanguage = 'language';
  static const String storageKeyWalletAccounts = 'wallet_accounts_json';
  static const String storageKeyCurrentAccountId = 'current_account_id';
  static const String storageKeyNetworkRpcOverrides = 'network_rpc_overrides';
}

enum NetworkType { local, devnet, testnet, mainnet }

class NetworkConfig {
  final String id;
  final String name;
  final NetworkType type;
  final String rpcUrl;
  final String wsUrl;
  final int chainId;
  final int networkId;
  final String explorerUrl;
  final String? faucetUrl;
  final String? bridgeUrl;
  final bool isTestnet;
  final String currencySymbol;
  final int decimals;

  const NetworkConfig({
    required this.id,
    required this.name,
    required this.type,
    required this.rpcUrl,
    required this.wsUrl,
    required this.chainId,
    required this.networkId,
    required this.explorerUrl,
    this.faucetUrl,
    this.bridgeUrl,
    required this.isTestnet,
    required this.currencySymbol,
    required this.decimals,
  });

  static const local = NetworkConfig(
    id: 'local',
    name: 'Local Network',
    type: NetworkType.local,
    rpcUrl: 'http://127.0.0.1:8545',
    wsUrl: 'ws://127.0.0.1:8546',
    chainId: 31337,
    networkId: 31337,
    explorerUrl: '',
    isTestnet: true,
    currencySymbol: 'ZC',
    decimals: 18,
  );

  static const devnet = NetworkConfig(
    id: 'devnet',
    name: 'Devnet',
    type: NetworkType.devnet,
    rpcUrl: 'http://127.0.0.1:28545',
    wsUrl: 'ws://127.0.0.1:28546',
    chainId: 10088,
    networkId: 10088,
    explorerUrl: '',
    faucetUrl: '',
    isTestnet: true,
    currencySymbol: 'ZC',
    decimals: 18,
  );

  static const testnet = NetworkConfig(
    id: 'testnet',
    name: 'Testnet',
    type: NetworkType.testnet,
    rpcUrl: 'http://127.0.0.1:18545',
    wsUrl: 'ws://127.0.0.1:18546',
    chainId: 10087,
    networkId: 10087,
    explorerUrl: '',
    faucetUrl: '',
    isTestnet: true,
    currencySymbol: 'ZC',
    decimals: 18,
  );

  static const mainnet = NetworkConfig(
    id: 'mainnet',
    name: 'Mainnet',
    type: NetworkType.mainnet,
    rpcUrl: 'http://127.0.0.1:8545',
    wsUrl: 'ws://127.0.0.1:8546',
    chainId: 10086,
    networkId: 10086,
    explorerUrl: '',
    isTestnet: false,
    currencySymbol: 'ZC',
    decimals: 18,
  );

  static const List<NetworkConfig> predefined = [
    local,
    devnet,
    testnet,
    mainnet,
  ];

  static NetworkConfig? getById(String id) {
    try {
      return predefined.firstWhere((network) => network.id == id);
    } catch (_) {
      return null;
    }
  }

  NetworkConfig copyWith({
    String? id,
    String? name,
    NetworkType? type,
    String? rpcUrl,
    String? wsUrl,
    int? chainId,
    int? networkId,
    String? explorerUrl,
    String? faucetUrl,
    String? bridgeUrl,
    bool? isTestnet,
    String? currencySymbol,
    int? decimals,
  }) {
    return NetworkConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      rpcUrl: rpcUrl ?? this.rpcUrl,
      wsUrl: wsUrl ?? this.wsUrl,
      chainId: chainId ?? this.chainId,
      networkId: networkId ?? this.networkId,
      explorerUrl: explorerUrl ?? this.explorerUrl,
      faucetUrl: faucetUrl ?? this.faucetUrl,
      bridgeUrl: bridgeUrl ?? this.bridgeUrl,
      isTestnet: isTestnet ?? this.isTestnet,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      decimals: decimals ?? this.decimals,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type.index,
    'rpcUrl': rpcUrl,
    'wsUrl': wsUrl,
    'chainId': chainId,
    'networkId': networkId,
    'explorerUrl': explorerUrl,
    'faucetUrl': faucetUrl,
    'bridgeUrl': bridgeUrl,
    'isTestnet': isTestnet,
    'currencySymbol': currencySymbol,
    'decimals': decimals,
  };

  factory NetworkConfig.fromJson(Map<String, dynamic> json) => NetworkConfig(
    id: json['id'] as String,
    name: json['name'] as String,
    type: NetworkType.values[json['type'] as int],
    rpcUrl: json['rpcUrl'] as String,
    wsUrl: json['wsUrl'] as String,
    chainId: json['chainId'] as int,
    networkId: json['networkId'] as int,
    explorerUrl: json['explorerUrl'] as String,
    faucetUrl: json['faucetUrl'] as String?,
    bridgeUrl: json['bridgeUrl'] as String?,
    isTestnet: json['isTestnet'] as bool,
    currencySymbol: json['currencySymbol'] as String,
    decimals: json['decimals'] as int,
  );
}
