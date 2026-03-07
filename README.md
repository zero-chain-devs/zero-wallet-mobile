# Zero Wallet Mobile (Native-Only)

Flutter 版 ZeroChain 钱包当前为 native-only 形态：
- 创建 `ed25519` 原生账户
- 导入 `ed25519` 私钥
- 本地加密保险库
- native compute 交易模拟与提交
- 网络切换与余额刷新

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

移动端不再提供 legacy provider 与非原生账户路径，所有发送流程统一为 native compute。

