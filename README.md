# ASUS ExpertBook BR1104FTA — OpenCore EFI (macOS Tahoe)

ASUS ExpertBook BR1104FTA（Intel N150 / Twin Lake）で macOS Tahoe 26 を動かすための OpenCore EFI 一式です。
内蔵ディスクの EFI パーティションに置いて常用している構成と同じ内容です。

> 実験的な構成です。特にグラフィックスは未マージの修正を含む WhateverXe の独自ビルドに依存しています。自己責任で使用してください。

## ハードウェア

| 項目 | 内容 |
| --- | --- |
| 機種 | ASUS ExpertBook BR1104FTA |
| CPU | Intel N150（Twin Lake、4 コア） |
| iGPU | Intel Graphics `8086:46D4`（24 EU） |
| 内蔵ディスプレイ | eDP 1366x768、タッチ／スタイラス対応 |
| メモリ | 8 GB |
| 内蔵ストレージ | UFS（`8086:54FF`） |
| Wi-Fi / Bluetooth | Intel CNVi `8086:54F0`（AX201 系） |
| 有線 LAN | Realtek RTL8111 |
| オーディオ | Intel Smart Sound Technology（`8086:54C8`、class `0x0401`） |
| トラックパッド | I2C HID `ASUP1201`（I2C0） |
| タッチスクリーン | I2C HID `ILIT2901`（I2C3） |

## 動作確認環境

| 項目 | 内容 |
| --- | --- |
| macOS | Tahoe 26.7.3（25G342） |
| ブートローダ | OpenCore（RELEASE ビルド） |
| SMBIOS | MacBookPro16,2 |
| 起動ディスク | 外付け USB ディスク（内蔵 UFS は macOS から使用不可のため） |

## 動作状況

✅ 動作　△ 一部動作・制限あり　× 動作しない　－ 未確認

| 機能 | 状況 | 備考 |
| --- | :---: | --- |
| グラフィックス加速（Metal） | ✅ | WhateverXe 0.8.2 + eDP 起動ポート修正（独自ビルド）、WhateverXe Graphics pkg が必要。VRAM 1536 MB |
| 内蔵ディスプレイ | ✅ | 1366x768 |
| 外部ディスプレイ（HDMI） | ✅ | |
| 輝度調整 | △ | 一部のみ動作（`SSDT-PNLF` + BrightnessKeys） |
| キーボード | ✅ | VoodooPS2Controller |
| トラックパッド | ✅ | VoodooI2C + VoodooI2CHID、ポーリング動作（`-vi2c-force-polling`） |
| タッチスクリーン／スタイラス | △ | 専用の ACPI パッチを入れれば動作するが、同時にトラックパッドが無反応になるため本構成では無効 |
| Wi-Fi | ✅ | itlwm 2.3.0 + [HeliPort](https://github.com/OpenIntelWireless/HeliPort) 1.5.0 |
| Bluetooth | ✅ | IntelBluetoothFirmware + IntelBTPatcher + BlueToolFixup |
| 有線 LAN | ✅ | RealtekRTL8111 |
| バッテリー表示 | ✅ | SMCBatteryManager + ECEnabler |
| USB ポート | ✅ | USBToolBox + UTBDefault（個別のポートマップは未作成） |
| 内蔵オーディオ（スピーカー／マイク／イヤホン） | × | コーデックが Intel SST（`INTELAUDIO`）接続で AppleHDA 非対応。USB オーディオか Bluetooth で代替 |
| 内蔵 Web カメラ | × | |
| スリープ／復帰 | × | 復帰できない。`sudo pmset -a disablesleep 1` でスリープ自体を無効化して運用 |
| 内蔵 UFS ストレージ | × | macOS にドライバがない |
| SD カードリーダー | － | |
| USB-C（映像出力・充電） | － | |
| iCloud / iMessage などの Apple サービス | － | |

## この機種固有の修正

### 1. DSDT のロード失敗（`ACPI > Patch`）

`\_SB.PC00.XHCI.RHUB.HS01` への `Scope` が条件付き `Device` を前方参照しており、macOS で DSDT のロードに失敗します。
`Scope` を `If` に書き換えるバイナリパッチで回避しています（`ASUS HS01 Scope to If`）。

### 2. トラックパッドが認識されない（`ACPI > Patch`）

`\_SB.PC00.I2C0.TPD0._CRS` は `OSYS < 0x07DC`（Windows 8 未満）のとき割り込みリソースしか返しません。
macOS では `OSYS = 0x03E8` になるため I2C シリアルバス宣言が得られず、VoodooI2C がデバイスを接続できません。

比較値 `0x07DC` を `0x0000` に書き換えて、常に I2C 宣言を返すようにしています（`ASUS TPD0 _CRS`）。

```
Find:    5F435253 00 A00E 95 4F535953 0B DC07 A4 53424649 A484 4932434D
Replace: 5F435253 00 A00E 95 4F535953 0B 0000 A4 53424649 A484 4932434D
```

タッチスクリーン（`TPL1._CRS`）にも同じゲートがあり、次のパッチで有効化できます。ただしトラックパッドが無反応になる問題が未解決のため、本構成には含めていません。

```
Find:    5F435253 00 A00E 95 4F535953 0B DC07 A4 53424649 A01E 93 54504C4D
Replace: 5F435253 00 A00E 95 4F535953 0B 0000 A4 53424649 A01E 93 54504C4D
```

### 3. グラフィックス加速が有効にならない（WhateverXe）

WhateverXe 0.8.2 RELEASE では、内蔵 eDP の起動ポートがネイティブモード 0 のまま拒否され、加速が有効になりません（`N97FramebufferStartAccepted = No`）。
同梱の `WhateverXe.kext` は、0.8.2 に上流の修正コミット `9c219ee`（"Admit the eDP boot port with native mode 0 at the firmware handoff"）を適用して GitHub Actions でビルドしたものです。

詳細な調査内容は [docs/WhateverXe-issue-edp-boot-port.md](docs/WhateverXe-issue-edp-boot-port.md) にあります。

### 4. 内蔵ディスクに EFI パーティションがない場合

APFS でボリュームだけを消去してインストールすると EFI パーティションが作られません。
次のコマンドで APFS コンテナを縮小し、FAT32 パーティションを追加して EFI フォルダを置きました（識別子は `diskutil list` で確認してください）。

```sh
sudo diskutil apfs resizeContainer disk0s2 999g FAT32 OCEFI 0b
```

パーティション種別は「Microsoft Basic Data」のままですが、本機のファームウェアは `\EFI\BOOT\BOOTx64.efi` から起動できました。

## 使い方

1. `EFI` フォルダを FAT32 の USB メモリ（または EFI パーティション）の直下にコピーします。
2. `EFI/OC/config.plist` の `PlatformInfo > Generic` にある `MLB`・`SystemSerialNumber`・`SystemUUID`・`ROM` はダミー値です。[GenSMBIOS](https://github.com/corpnewt/GenSMBIOS) で `MacBookPro16,2` 用の値を生成して書き換えてください。
3. macOS をインストールします。インストール時は boot-args に `-wexoff` を追加し、WhateverXe を無効にしておきます。
4. インストール後、[WhateverXe Graphics](https://github.com/b00t0x/WhateverXe) の pkg をインストールし、`-wexoff` を外して再起動します。
5. HeliPort を `/Applications` に入れて起動し、Wi-Fi に接続します。未接続時のメニューバーアイコンはかなり薄く表示されます。
6. スリープから復帰できないため、スリープを無効化します。

   ```sh
   sudo pmset -a disablesleep 1
   ```

### boot-args

```
-v debug=0x100 keepsyms=1 -allow3d -disablegfxfirmware -igfxdvmt -vi2c-force-polling
```

`-v debug=0x100 keepsyms=1` はデバッグ用です。不要なら削除できます。

## 同梱 kext

| kext | バージョン | 状態 |
| --- | --- | :---: |
| Lilu | 1.7.3 | 有効 |
| WhateverXe | 0.8.2 + `9c219ee`（独自ビルド） | 有効 |
| AMFIPass | 1.4.1 Mod | 有効 |
| VirtualSMC / SMCProcessor / SMCSuperIO / SMCBatteryManager | 1.3.9 | 有効 |
| ECEnabler | 1.0.6 | 有効 |
| ForgedInvariant | 1.5.0 | 有効 |
| RestrictEvents | 1.1.7 | 有効 |
| VoodooPS2Controller | 2.3.8 | 有効（Trackpad プラグインは無効） |
| VoodooI2C / VoodooI2CHID | 2.9.1（master の CI ビルド） | 有効 |
| itlwm | 2.3.0 | 有効 |
| IntelBluetoothFirmware / IntelBTPatcher | 2.5.0 | 有効 |
| BlueToolFixup | 2.7.3 | 有効 |
| BrightnessKeys | — | 有効 |
| RealtekRTL8111 | 2.4.2 | 有効 |
| USBToolBox / UTBDefault | 1.2.0 | 有効 |
| AirportItlwm | 2.4.0 | 無効 |
| AppleALC | 1.9.9 | 無効（オーディオ非対応のため） |
| SimpleHDA | 1.0.1 | 無効（同上） |
| SMCLightSensor | 1.3.9 | 無効 |

## 診断スクリプト（`tools/`）

macOS 上で `sudo sh <スクリプト>` として実行すると、スクリプトと同じ場所に結果を保存します。

| スクリプト | 内容 |
| --- | --- |
| `diag.sh` | システム全般、ロード済み kext、GPU／I2C の ioreg、カーネルログ |
| `diag2.sh` | VoodooI2C と Intel GPU の起動ログ |
| `diag3.sh` | トラックパッド、Wi-Fi、Bluetooth、バッテリー、GPU |
| `diag4.sh` | トラックパッドの認識状態とスリープ／復帰失敗の切り分け |
| `diag5.sh` | オーディオ（AppleALC + SimpleHDA）とタッチスクリーン |
| `sleepfix.sh` | hibernate / standby / Power Nap を無効化 |
| `rename-mac.sh` | 「この Mac について」の機種名表示を変更（sudo なしで実行） |

出力にはシリアル番号や MAC アドレスが含まれます。公開する前に確認してください。

## 未解決の課題

- **スリープ／復帰**: 原因は未特定です。候補はファームウェアの S3 復帰不良、WhateverXe のシステムスリープ対応（eDP 機は未検証）、USB 起動ディスクの給電断です。
- **タッチスクリーンとトラックパッドの両立**: 両方を有効にするとトラックパッドが無反応になります。ドライバ上は両方とも正常に起動しており、仮想トラックパッド（VoodooInput）が 2 つ生成されることが原因と推測していますが未確認です。
- **オーディオ**: コントローラが DSP モード（class `0x0401`）で、コーデックが HDA ではなく Intel SST 経由のため、AppleHDA / AppleALC では動作しません。
- **USB ポートマップ**: 未作成です。

## クレジット

- [acidanthera](https://github.com/acidanthera)（OpenCore、Lilu、VirtualSMC、VoodooPS2 ほか）
- [b00t0x/WhateverXe](https://github.com/b00t0x/WhateverXe)
- [VoodooI2C](https://github.com/VoodooI2C/VoodooI2C)
- [OpenIntelWireless](https://github.com/OpenIntelWireless)（itlwm、HeliPort、IntelBluetoothFirmware）
- [USBToolBox](https://github.com/USBToolBox)、[ChefKiss](https://github.com/ChefKissInc)（ForgedInvariant）、[1Revenger1](https://github.com/1Revenger1/ECEnabler)、[dhinakg](https://github.com/dhinakg/AMFIPass)、[Mieze](https://github.com/Mieze/RTL8111_driver_for_OS_X)、[laobamac](https://github.com/laobamac/SimpleHDA)

同梱の各バイナリの著作権とライセンスは、それぞれの作者に帰属します。
