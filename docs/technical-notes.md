# 技術メモ：パドルの発射ボタンを調べた経緯

このページは必須手順ではありません。通常のセットアップは[README](../README.md)と[Webガイド](../index.html)をご覧ください。

## Windowsでの見え方

- **パドル回転**：マウスホイールの上下スクロール。
- **トラックボール**：マウスカーソル移動。
- **発射ボタン**：通常のマウスクリックにはならず、一般的な入力テスターにも表示されない。

## USB機器の識別

USB Device Tree Viewerで確認した値：

- Product string: `TAITO USB Paddle & Trackball Controller`
- VID: `0AE4`
- PID: `0701`

**VIDは `04E8` ではなく `0AE4` です。** 取り違えるとWiresharkの表示フィルターで機器が見つかりません。

## WiresharkとUSBPcapでの検証

1. WiresharkのUSBPcapインターフェースでキャプチャを開始してコントローラを挿す。
2. 表示フィルター `usb.idVendor == 0x0ae4 && usb.idProduct == 0x0701` でディスクリプタを確認。
3. 接続時に割り当てられたUSBバス番号・デバイスアドレスを調べる。実測例はバス `1`、アドレス `17`。
4. `usb.bus_id == 1 && usb.device_address == 17 && usbhid.data` で対象機器の入力レポートを比較。

| 状態 | HID Data（5バイト） |
|---|---|
| ボタンを押す前 | `00 00 00 00 00` |
| ボタン押下中 | `00 01 00 00 00` |
| ボタンを離した後 | `00 00 00 00 00` |

2バイト目の最下位ビットがボタンの押下状態に対応しました。発射ボタン変換スクリプトはこのビットの立ち上がりを検知して、Mesenが前面にあるときだけSpaceキーを送信します。

## 実装上の注意

- 起動用CMDはWindows PowerShellのプロセス限定で `-ExecutionPolicy Bypass` を使用します。出所の確認できないスクリプトを無条件に実行しないでください。
- Windows PowerShell 5.1の厳しいエラー処理では、TSharkの正常な標準エラー出力 `Capturing on 'USBPcap1'` が例外として扱われました。実機で動作した修正版では `$ErrorActionPreference = 'Continue'` を使っています。
- 対象機器のバス・アドレスを特定するには **USBケーブルを抜く → 監視開始 → 差し直す** 順で操作します。
- `USBPcap1` は検証PCでの名前です。別PCでは `USBPcap2` などの可能性があります。
- USBPcapはほかの接続機器の通信も取得する可能性があります。公開キャプチャを取得したり、機密情報の入力中に監視を続けたりしないでください。
- この方法はWindowsのHIDドライバー全体に汎用マウスボタンを追加するものではありません。Mesenが前面のときにSpaceを送る試験的な処理です。
- 動作実績は2026年11月の単一環境に基づきます。別個体、別バージョン、長時間運用、ほかのゲームへの対応は未検証です。

## 関連する先行調査

[HID RemapperのTaito Egret II関連Issue](https://github.com/jfedor2/hid-remapper/issues/47)では、通常のマウスボタンに変換しにくい入力について報告されています。今回のWindowsソフトウェア方式は、USBPcap＋TSharkを使う別の実験的アプローチです。
