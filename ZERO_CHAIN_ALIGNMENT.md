# Zero Chain Alignment

## 对齐目标

`zero-wallet-mobile` 已对齐到 ZeroChain 钱包主路径实现：
- 账户方案：`ed25519`
- 交易路径：compute tx
- RPC 方法：`zero_*`

## 对齐结果

1. 账户
- 创建与导入统一使用 ed25519 私钥
- 账户列表仅展示 ed25519 账户

2. 交易
- 发送页统一为 compute JSON 编辑与签名
- 支持 `zero_simulateComputeTx` / `zero_submitComputeTx`

3. 文档
- README 与页面文案更新为当前单一路径口径
- 旧能力说明从当前文档移除

## 验证

- `flutter analyze`
- `flutter test`
