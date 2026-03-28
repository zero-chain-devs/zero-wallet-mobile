# Zero Wallet Mobile

Flutter 版 ZeroChain 钱包当前聚焦单一路径实现：
- 创建 `ed25519` 账户
- 导入 `ed25519` 私钥
- 本地加密保险库
- compute 交易模拟与提交
- 网络切换与余额刷新

共享 compute JSON 规范见：
- [COMPUTE_JSON_SPEC.md](/root/workspaces/blockchain/zero-chain/docs/COMPUTE_JSON_SPEC.md)

## 开发

```bash
flutter pub get
flutter run
```

## 验证

```bash
flutter analyze
flutter test
```

## 说明

移动端不再提供旧页面桥接与非 `ed25519` 账户路径，所有发送流程统一为 compute 交易。
