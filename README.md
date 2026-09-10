# Quantus Lite Wallet

Quantus Lite Wallet 是一个面向 Quantus 主网的精简 Android 钱包。项目只构建 Android ARM64（`arm64-v8a`），提供助记词导入、钱包地址查看、QTC 余额查询和转账功能。

> 本项目尚未经过独立安全审计。首次使用应先完成小额转入、转出测试，不要直接存放大额资产。

## 功能

- 导入 12 或 24 个助记词。
- 支持当前默认的 ML-DSA-65 和旧钱包使用的 ML-DSA-87。
- 支持账户索引和可选的已知地址校验。
- 查看与复制钱包地址。
- 通过两个官方 Quantus 主网 RPC 自动故障切换查询余额。
- 每次转账必须输入钱包密码，验证成功后才解密、派生密钥并签名。
- 广播交易前显示金额、预估手续费、总计和完整收款地址。
- 支持旧版钱包的一次性密码保护迁移。

## 主网锁定

- Genesis：`0xfb5487c0be6ae4ade2d41d16e50465129861636c2b8d61fa94d7a19631626fba`
- Runtime：spec `152`
- Transaction version：`6`
- 首选 RPC：`https://rpc1-mainnet.quantus.com`
- 备用 RPC：`https://rpc2-mainnet.quantus.com`

应用会在余额查询和签名前核对 genesis 与 runtime 版本。任一值不匹配时都会拒绝签名。可执行以下只读命令检查实时主网 metadata；该命令不会读取钱包或提交交易：

```bash
dart run tool/verify_mainnet_metadata.dart
```

如果 runtime 已升级，不要只修改版本常量绕过检查。必须重新核对生成的 metadata、调用索引、签名上下文和交易编码。

## 密码与本地存储

- 钱包密码至少 10 个字符，密码本身不会保存。
- 使用 Argon2id 派生加密密钥：64 MiB 内存、3 次迭代、1 个 lane、随机 128-bit salt。
- 助记词使用 AES-256-GCM 认证加密。
- AAD 会绑定钱包地址、派生路径和签名方案，防止密文被替换到其他账户上下文。
- 只有版本化密文 envelope 会写入 `flutter_secure_storage`。
- Android Keystore 会再使用 RSA-OAEP/AES-GCM 保护该密文。
- 密码错误、账户上下文变化或密文被篡改时，签名前即会失败。
- 忘记密码后无法找回密码，只能使用离线备份的助记词重新导入。

签名期间，解密后的助记词必须短暂存在于进程内存。解密字节、派生密钥及 ML-DSA 私钥的可变缓冲区会在使用后覆盖为零；但当前 Dart 流程会短暂创建不可变的助记词 `String`，它只能等待垃圾回收，不能保证立即物理清零。明文助记词不会写入文件、日志或 RPC 请求。更多说明见 [SECURITY.md](SECURITY.md)。

## 目录结构

```text
android/                         Android 工程与 ARM64 打包配置
lib/src/wallet_vault.dart        Argon2id、AES-GCM envelope 和安全存储
lib/src/wallet_controller.dart   导入、迁移、解锁和密钥生命周期
lib/src/mainnet_service.dart     主网验证、余额、手续费和交易广播
lib/src/send_screen.dart         密码输入与转账确认界面
packages/quantus_sdk/            vendored Quantus Dart/Rust SDK
test/                            金额和密码加密测试
tool/verify_mainnet_metadata.dart 主网 metadata 只读检查
```

SDK 来源和本地集成补丁记录见 [UPSTREAM.md](UPSTREAM.md)。

## Ubuntu 构建 Android ARM64 APK

以下教程适用于 Ubuntu 22.04 或 Ubuntu 24.04。Android APK 的目标架构是 ARM64；Ubuntu 构建机本身可以是 x86_64 或 ARM64，但必须下载与构建机架构对应的 Flutter Linux SDK。

官方参考：

- [Flutter Linux SDK 安装](https://docs.flutter.dev/install/manual)
- [Flutter Android 开发环境](https://docs.flutter.dev/platform-integration/android/setup)
- [Android sdkmanager](https://developer.android.com/tools/sdkmanager)
- [Android NDK 与 CMake](https://developer.android.com/studio/projects/install-ndk)
- [Rustup 安装](https://rust-lang.github.io/rustup/installation/)
- [Rust 交叉编译 target](https://rust-lang.github.io/rustup/cross-compilation.html)

### 1. 工具版本与磁盘空间

本项目已验证的组合：

| 工具 | 版本 |
|---|---:|
| Flutter | 3.47.3 stable |
| JDK | 17 |
| Android compile/target SDK | 36 |
| Android Build Tools | 36.0.0 |
| Android NDK | 28.2.13676358 |
| CMake | 3.22.1 |
| Gradle Wrapper | 9.3.1 |
| Android Gradle Plugin | 9.1.0 |
| Kotlin Plugin | 2.4.0 |
| Rust | `nightly-2025-12-20` + `rust-src` |
| Rust Android target | `aarch64-linux-android` |

首次完整构建会下载 Flutter、Gradle、Android SDK/NDK、Pub 和 Rust 依赖，建议准备至少 20 GB 可用空间。

### 2. 安装 Ubuntu 基础依赖

```bash
sudo apt-get update
sudo apt-get install -y \
  binutils \
  ca-certificates \
  clang \
  cmake \
  curl \
  git \
  libglu1-mesa \
  ninja-build \
  openjdk-17-jdk \
  pkg-config \
  unzip \
  xz-utils \
  zip
```

确认 Java：

```bash
java -version
javac -version
```

两条命令都应显示 Java 17。

### 3. 安装 Flutter 3.47.3

从 [Flutter SDK Archive](https://docs.flutter.dev/install/archive) 下载与 Ubuntu 构建机 CPU 架构匹配的 Flutter 3.47.3 stable Linux 压缩包，然后安装到 `/opt/flutter-sdk`：

```bash
sudo mkdir -p /opt/flutter-sdk
sudo chown "$USER":"$USER" /opt/flutter-sdk
tar -xf /path/to/flutter_linux_3.47.3-stable.tar.xz -C /opt/flutter-sdk
```

设置当前终端环境：

```bash
export FLUTTER_HOME=/opt/flutter-sdk/flutter
export PATH="$FLUTTER_HOME/bin:$PATH"
```

验证安装：

```bash
flutter --version
dart --version
```

如需每次登录自动生效，请把 `FLUTTER_HOME` 和 `PATH` 两行加入当前用户的 `~/.bashrc`，然后重新登录终端。

### 4. 安装 Android Command-line Tools

从 [Android Studio 下载页面](https://developer.android.com/studio#command-tools) 下载 Linux Command-line Tools ZIP。创建独立 SDK 目录：

```bash
sudo mkdir -p /opt/android-sdk/cmdline-tools/latest
sudo chown -R "$USER":"$USER" /opt/android-sdk
mkdir -p /tmp/android-command-tools
unzip /path/to/commandlinetools-linux-latest.zip -d /tmp/android-command-tools
mv /tmp/android-command-tools/cmdline-tools/* /opt/android-sdk/cmdline-tools/latest/
```

设置当前终端环境：

```bash
export ANDROID_HOME=/opt/android-sdk
export JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
export PATH="$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"
```

告诉 Flutter 使用这些路径：

```bash
flutter config --android-sdk "$ANDROID_HOME"
flutter config --jdk-dir "$JAVA_HOME"
```

### 5. 安装 Android SDK、NDK 和 CMake

```bash
sdkmanager --sdk_root="$ANDROID_HOME" \
  "platform-tools" \
  "platforms;android-36" \
  "build-tools;36.0.0" \
  "ndk;28.2.13676358" \
  "cmake;3.22.1"
```

交互式阅读并接受需要的许可：

```bash
sdkmanager --sdk_root="$ANDROID_HOME" --licenses
```

检查 Flutter Android 环境：

```bash
flutter doctor -v
```

### 6. 安装 Rust nightly 和 Android ARM64 target

如果系统尚未安装 rustup：

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source "$HOME/.cargo/env"
```

只安装本项目需要的 nightly、`rust-src` 和 ARM64 Android target：

```bash
rustup toolchain install nightly-2025-12-20 --profile minimal --component rust-src
rustup target add --toolchain nightly-2025-12-20 aarch64-linux-android
```

不要安装 `armv7-linux-androideabi`、`i686-linux-android` 或 `x86_64-linux-android`。

### 7. 准备源码目录

为了避免个人主目录被编译器写入二进制，可把源码放在中性目录：

```bash
sudo mkdir -p /opt/quantus-build
sudo chown "$USER":"$USER" /opt/quantus-build
```

将本项目复制或检出到：

```text
/opt/quantus-build/quantus-lite-wallet
```

进入项目并设置 Rust 路径重映射：

```bash
cd /opt/quantus-build/quantus-lite-wallet
export RUSTFLAGS="--remap-path-prefix=$HOME=/home/builder --remap-path-prefix=/opt/quantus-build=/workspace"
```

这里读取 `$HOME` 只是为了替换编译器记录的路径，不会修改 HOME。

### 8. 下载项目依赖并运行检查

```bash
flutter pub get
flutter analyze
flutter test
dart run tool/verify_mainnet_metadata.dart
```

最后一个命令需要联网。输出的 genesis、specVersion、transactionVersion、Balances pallet index 和 transfer call index 必须与应用预期一致。

### 9. 构建纯 ARM64 APK

```bash
flutter build apk --release --target-platform android-arm64
```

项目有两层 ABI 限制：

- `android/gradle.properties` 中的 `ONLY_ARM64=true` 让 Rust Cargokit 只编译 `aarch64-linux-android`。
- `android/app/build.gradle.kts` 使用 `abiFilters` 和 packaging exclusions 排除其他 ABI。

生成文件位于：

```text
build/app/outputs/flutter-apk/app-release.apk
```

### 10. 验证构建结果

检查 APK 内所有原生库：

```bash
zipinfo -1 build/app/outputs/flutter-apk/app-release.apk \
  | grep '^lib/' \
  | sort
```

输出路径必须全部以 `lib/arm64-v8a/` 开头，不应出现 `armeabi-v7a`、`x86` 或 `x86_64`。

验证 APK 签名：

```bash
"$ANDROID_HOME/build-tools/36.0.0/apksigner" verify \
  --verbose \
  --print-certs \
  build/app/outputs/flutter-apk/app-release.apk
```

计算 SHA-256：

```bash
sha256sum build/app/outputs/flutter-apk/app-release.apk
```

检查 APK 是否包含真实 HOME 路径或用户名：

```bash
if unzip -p build/app/outputs/flutter-apk/app-release.apk | strings | grep -F "$HOME"; then
  echo "发现本机 HOME 路径，停止发布"
  exit 1
fi

if unzip -p build/app/outputs/flutter-apk/app-release.apk | strings | grep -F "$USER"; then
  echo "发现本机用户名，停止发布"
  exit 1
fi
```

## 构建后清理

清除项目构建产物：

```bash
flutter clean
cargo clean --manifest-path packages/quantus_sdk/rust/Cargo.toml
```

Gradle、Pub、Flutter、Android SDK 和 NDK 是全局共享依赖。删除它们会影响同一 Ubuntu 主机上的其他项目；确认不再需要构建环境后再卸载。

## 已完成的测试与限制

- Flutter 静态检查通过。
- 金额精度测试通过。
- 错误密码、错误账户上下文和 AES-GCM 篡改检测通过。
- 正式 Argon2id 参数测试通过。
- 官方 ML-DSA-65/87 地址向量测试通过。
- spec 152 签名上下文测试通过。
- 主网 genesis、runtime 和 `Balances.transfer_allow_death` metadata 已核对。
- 纯 ARM64 APK 内容和 APK v2 签名曾完成验证。
- 尚未进行独立第三方安全审计。
