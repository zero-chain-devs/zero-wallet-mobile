# RabbitChain Alignment

## 对齐目标

`rabbitchain-wallet-mobile` 已对齐到 RabbitChain 钱包主路径实现：
- 账户方案：`ed25519`
- 账户生成：助记词生成 + 私钥加密存储
- 交易路径：compute tx
- RPC 方法：`rabbit_*`
- mainnet 默认 RPC：内置主网 bootnode RPC

## 对齐结果

1. 账户
- 创建钱包时生成助记词，导入支持 ed25519 私钥和 BIP39 助记词
- 账户列表仅展示 ed25519 账户

2. 交易
- 发送页统一为 compute JSON 编辑与签名
- 支持 `rabbit_simulateComputeTx` / `rabbit_submitComputeTx`

3. 文档
- README 与页面文案更新为当前单一路径口径
- 旧能力说明从当前文档移除

## 验证

- `flutter analyze`
- `flutter test`
