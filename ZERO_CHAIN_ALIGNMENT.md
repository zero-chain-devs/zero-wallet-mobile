# Zero Wallet Mobile 与 `zero-chain` 对齐说明

本文档用于纠正旧版移动端文档里“只做 EVM”或“Native 只是概念预留”的错误描述。

## 1. 对齐基准

- 钱包账户方案：`/home/de/works/zero-chain/crates/zerocli/src/commands/wallet.rs`
- RPC 方法：`/home/de/works/zero-chain/crates/zeroapi/src/rpc/mod.rs`
- Compute 编码：`/home/de/works/zero-chain/crates/zerocore/src/compute/tx.rs`
- 钱包 PBKDF2 参数：`/home/de/works/zero-chain/crates/zerocli/src/commands/wallet.rs`

## 2. 已确认的链侧事实

1. ZeroChain 同时支持 `secp256k1` 与 `ed25519` 两类账户。
2. `ed25519` 原生地址不是 ETH 地址，而是 `native1` + `keccak256(public_key_32)` 的后 20 字节。
3. 原生 compute 交易有正式 RPC：
   - `zero_simulateComputeTx`
   - `zero_submitComputeTx`
   - `zero_getComputeTxResult`
4. Compute 签名签的是 preimage，不是 ETH 风格交易哈希签名。

## 3. 对旧移动端实现的修正

### 3.1 钱包范围修正

旧说法：移动端是 v1 `secp256k1 / EVM` 钱包。  
当前真实状态：移动端已对齐为混合钱包，支持 `secp256k1 / EVM` 与 `ed25519 / Native` 两类账户，并支持 UI 切换当前账户。

### 3.2 Native 创建/导入方式修正

旧实现问题：Native 账户仍在走“助记词导出 seed 前 32 字节”的伪方案。  
当前修正后：

- Native 创建：随机生成 `ed25519` 私钥
- Native 导入：导入原生私钥
- Native 备份：展示原生私钥，而不是伪助记词恢复路径

### 3.3 EVM 助记词派生修正

只对 `secp256k1 / EVM` 账户适用：

- 助记词使用 BIP39
- 路径固定 `m/44'/60'/0'/0/0`
- 本地密码不参与 seed 派生
- BIP39 passphrase 固定为空字符串 `""`

### 3.4 本地加密修正

- 使用 `PBKDF2-SHA256 (120000)` + `AES-256-GCM`
- 敏感账户数据写入 `flutter_secure_storage`
- 不再使用演示型拼接密文逻辑

### 3.5 网络矩阵修正

移动端默认网络端口已修正为与 `zero-chain` 一致：

- `local`: `8545 / 8546`
- `devnet`: `28545 / 28546`
- `testnet`: `18545 / 18546`
- `mainnet`: `8545 / 8546`

### 3.6 Native 交易流修正

旧说法：移动端 Native 交易广播未实现。  
当前修正后：移动端发送页已按账户类型分流：

- `secp256k1`：EVM 发送
- `ed25519`：Native compute JSON -> 本地签名 -> `zero_simulateComputeTx` / `zero_submitComputeTx`

### 3.7 余额模型修正

- EVM 账户继续查询 `eth_getBalance`
- Native 账户当前不再误用 ETH 余额接口做假余额展示
- Native 对象/UTXO 聚合仍属于后续能力

## 4. 当前可交付范围

- 创建/导入 `secp256k1` EVM 账户
- 创建/导入 `ed25519` Native 账户
- 本地加密保存助记词与私钥
- UI 切换当前账户
- EVM 余额查询与发送
- Native compute 模拟与提交
- 网络切换与自定义 RPC URL

## 5. 当前不承诺

- Native 对象/资产首页聚合
- 完整交易历史
- receipt 驱动的强确认体验
- WebSocket 推送
- Indexer 级资产视图

## 6. 结论

移动端现在不能再写成“只支持 EVM”。正确表述应为：

- **Zero Wallet Mobile 已是混合钱包**
- **创建/导入/切换同时支持 EVM 与 Native**
- **Native 发送已走真实 compute RPC，不再停留在占位文档**
