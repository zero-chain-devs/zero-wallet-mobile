# Zero Wallet Mobile

Flutter 版 ZeroChain 钱包当前已经按 `zero-chain` 的真实能力对齐为 **混合钱包**：同时支持 `secp256k1 / EVM` 与 `ed25519 / Native` 两类账户，并允许在移动端 UI 中切换当前账户。

## 当前能力

- 创建 `secp256k1` EVM 助记词钱包
- 导入 `secp256k1` 助记词或私钥
- 创建 `ed25519` 原生钱包
- 导入 `ed25519` 原生私钥
- 本地密码加密保险库
- 多账户管理与当前账户切换
- EVM 余额查询与 `eth_sendRawTransaction`
- Native compute 交易模拟与提交：`zero_simulateComputeTx` / `zero_submitComputeTx`
- 网络切换（`local` / `devnet` / `testnet` / `mainnet`）
- 自定义当前网络 RPC URL

## 当前限制

- Native 首页当前不聚合对象/UTXO 余额
- `eth_getTransactionReceipt` 不宣称稳定可用
- 完整交易历史仍未实现
- WebSocket 推送未接入主流程

## 账户模型

### `secp256k1 / EVM`

- 助记词：BIP39
- 派生路径：`m/44'/60'/0'/0/0`
- BIP39 passphrase：固定为空字符串 `""`
- 本地密码：仅用于本地保险库加密

### `ed25519 / Native`

- 创建方式：随机 `ed25519` 私钥
- 导入方式：原生私钥
- 地址规则：`native1` + `keccak256(public_key_32)` 后 20 字节十六进制
- Compute 签名：签名 `zero-chain` 定义的 compute signing preimage，并附带 `public_key`

## 网络矩阵

| 网络 | Chain ID | Network ID | RPC | WS |
| --- | --- | --- | --- | --- |
| local | 31337 | 31337 | `http://127.0.0.1:8545` | `ws://127.0.0.1:8546` |
| devnet | 10088 | 10088 | `http://127.0.0.1:28545` | `ws://127.0.0.1:28546` |
| testnet | 10087 | 10087 | `http://127.0.0.1:18545` | `ws://127.0.0.1:18546` |
| mainnet | 10086 | 10086 | `http://127.0.0.1:8545` | `ws://127.0.0.1:8546` |

## 安全模型

- 本地加密：`PBKDF2-SHA256 (120000)` + `AES-256-GCM`
- 敏感数据存储：`flutter_secure_storage`
- 助记词与私钥均不上传服务器
- Native 私钥与 EVM 私钥都只在本地签名

## 项目结构

```text
lib/
├── core/
│   ├── constants/      # 网络配置与全局常量
│   ├── network/        # HTTP JSON-RPC 客户端
│   ├── theme/          # 主题
│   └── utils/          # 加密、日志、native compute 编码
├── data/
│   └── models/         # 钱包数据模型
├── presentation/
│   ├── pages/          # 页面
│   └── providers/      # 钱包状态管理
└── main.dart           # 入口
```

## 本地运行

```bash
flutter pub get --offline
flutter analyze
flutter run
```

## 相关文档

- `ZERO_CHAIN_ALIGNMENT.md`：与 `zero-chain` 的设计对齐说明
