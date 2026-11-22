# イーグレットツーミニのパドルで Mesen の『アルカノイド』を遊ぶ

**追加の変換ハードなし**で、タイトー「イーグレットツーミニ パドル＆トラックボールコントローラ」の**パドル回転と本体の発射ボタン**を Windows 上の Mesen 2 で使うための日本語ガイドです。

> ✅ 2026年11月、実機で **VAUSの左右移動と本体ボタンによる発射**に成功しました。  
> ⚠️ 個人環境での実験結果です。すべてのWindows環境・Mesenバージョンでの動作は保証しません。

**[図解Webガイド（GitHub Pagesを有効化した後）](https://cac-gwd.github.io/egret2-mesen-paddle-guide/)**

## 必要なもの

- Windows 10/11 と「イーグレットツーミニ パドル＆トラックボールコントローラ」
- [MesenCE](https://github.com/nesdev-org/MesenCE/releases) または [Mesen 2](https://github.com/SourMesen/Mesen2/releases)（動作確認はMesen 2系）
- [AutoHotkey v2](https://www.autohotkey.com/)
- [Wireshark](https://www.wireshark.org/download.html)（TSharkを含む）＋ [USBPcap](https://github.com/desowin/usbpcap/releases)
- 適法に用意したゲームデータ（このリポジトリには含まれません）

## 最短の使い方

1. Mesen の `Settings → NES → Input` で、日本版なら拡張端子側の **Arkanoid Controller (Famicom)** を選ぶ。海外NES版はポート2に **Arkanoid Controller (NES)** を設定。
2. Mesenの専用コントローラ設定で **Fire = Space** に割り当てる。普通のマウスを横に動かしてVAUSの反応を確認する。
3. [`scripts/mesen_spinner.ahk`](scripts/mesen_spinner.ahk) をAutoHotkey v2で実行。パドル回転（ホイール）をマウスの左右移動に変換。
4. Wiresharkによるキャプチャを停止し、イーグレットツーミニのUSBケーブルをPCから**抜く**。
5. [`scripts/mesen_fire.ps1`](scripts/mesen_fire.ps1) と [`scripts/START_FIRE.cmd`](scripts/START_FIRE.cmd) を**同じフォルダ**に保存。 `START_FIRE.cmd` をダブルクリック。
6. Enterを押し、`Starting USBPcap1 monitoring` が出たらパドルを挿し直す。`TAITO detected` が表示されたらMesenを前面にする。
7. パドルの回転でVAUSを動かし、本体ボタンで発射できる。黒い画面に `Fire!` と出るのが検出成功の目印。

終了時：AHKは **Ctrl + Alt + Q**、発射側はコマンド画面で **Ctrl + C**。今回のAHKはほかのアプリでもマウスホイールを変換するため、ゲーム後には終了してください。

## 入力変換の仕組み

| 操作 | Windowsでの認識 | 変換 |
|---|---|---|
| パドル回転 | マウスホイール | AutoHotkeyでマウス横移動へ |
| パドル本体ボタン | 通常のマウスクリックではないHID入力 | TShark＋PowerShellで検出し、MesenにSpaceを送信 |
| トラックボール | マウス移動 | 今回は変換しない |

検証したUSB識別子は **VID `0AE4` / PID `0701`**。ボタンを押す前、押下中、離した後のHIDデータはそれぞれ `0000000000` → `0001000000` → `0000000000` でした。

解析の経緯：[技術メモ](docs/technical-notes.md)。

## 困ったとき

- **VAUSが動かない：** MesenのArkanoid専用入力設定とAHK起動を確認。左右逆ならAHKの `-10` と `10` を入れ替える。
- **`71 hotkeys...` と警告される：** 配布版に `A_MaxHotkeysPerInterval := 500` が入っていることを確認。
- **`TAITO detected` が出ない：** Wiresharkのキャプチャを終了し、USBを抜く → `START_FIRE.cmd` 開始 → USBを挿し直す。PCによっては `USBPcap1` 以外の番号なので、PS1ファイル内の `-i USBPcap1` を修正する。
- **`Capture failed: Capturing on 'USBPcap1'`：** 旧試作版の問題。ここに置いた修正版を使用する。
- **`Fire!` は出るのに発射しない：** MesenのFireがSpaceに設定されているか、Mesenが前面にあるか確認。

## 安全・互換性について

スクリプトの内容を確認し、納得したうえで実行してください。発射ボタンのスクリプトは `ExecutionPolicy Bypass` を**そのPowerShellプロセスに限って**指定して起動します。USBPcapは同じUSBバスのほかの機器の通信も監視しうるので、実行中に機密情報を入力しないでください。通信データをファイルへ保存しない設計ですが、長時間安定性・遅延・ほかのゲームでの動作は未検証です。

タイトー、Mesen開発者とは無関係の非公式ガイドです。ゲームROMは配布していません。

関連：[HID Remapperでの同製品の特殊HID入力に関する報告](https://github.com/jfedor2/hid-remapper/issues/47) / [USBPcap](https://github.com/desowin/usbpcap) / [AutoHotkey](https://www.autohotkey.com/)。