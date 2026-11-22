# イーグレットツーミニのパドルで Mesen・MAME の『アルカノイド』を遊ぶ

WindowsのMesen 2などで、イーグレットツーミニ パドル＆トラックボールコントローラの回転と5つのボタンを使うためのガイドです。

パドル回転はAutoHotkey、ボタンはUSBPcap＋TShark＋PowerShellで変換します。追加の変換ハードウェアは不要です。

> 2026年11月22日、ユーザー環境の **MAMEUI64 0.263.0（Feb 28 2024）** でパドル回転と本体の右ボタンによる発射を確認しました。Mesenでは旧版の回転・右ボタン発射が実機確認済みです。全ボタンの組み合わせや長時間動作は未確認です。

[Webガイド](https://cac-gwd.github.io/egret2-mesen-paddle-guide/) ／ [最新版一式（ZIP）](https://github.com/cac-gwd/egret2-mesen-paddle-guide/archive/refs/heads/main.zip)

配布版は**全アプリ対応・MAME用スキャンコード修正済み**です。Mesen限定の判定を外し、操作中のアプリへキーを送ります。アプリ側の入力方式・キー割り当てによっては追加設定が必要です。

## 必要なもの

- Windows 10/11
- イーグレットツーミニ パドル＆トラックボールコントローラ（VID `0AE4` / PID `0701`）
- 使用するエミュレーター：[Mesen 2](https://github.com/SourMesen/Mesen2/releases)、[MesenCE](https://github.com/nesdev-org/MesenCE/releases)、またはMAME／MAMEUI（今回の追加検証はMAMEUI64 0.263.0）
- [AutoHotkey v2](https://www.autohotkey.com/)
- [Wireshark（TSharkを含む）](https://www.wireshark.org/download.html) と [USBPcap](https://github.com/desowin/usbpcap/releases)
- Windows PowerShell 5.1（Windows標準搭載）
- 自分で用意したゲームデータ（この配布物には含まれません）

## Mesenでの起動手順

1. `scripts` フォルダを丸ごと保存・展開します。次の5ファイルを同じフォルダに置いてください。
   - `mesen_spinner.ahk`：パドル回転
   - `START_FIRE.cmd`：ボタン変換の起動
   - `mesen_fire.ps1`：起動処理と設定の読み込み
   - `EgretButtons.cs`：ボタン処理本体（起動時に自動コンパイル。手動ビルドは不要）
   - `buttons.json`：変更可能なキー割り当て
2. Mesenの `Settings → NES → Input` で、日本版なら拡張端子の **Arkanoid Controller (Famicom)** を選びます。海外NES版はポート2の **Arkanoid Controller (NES)** を使用します。
3. パドル用コントローラの **FireにSpace**、通常の **1PコントローラのStartにEnter** を割り当てます。Enterは自動的にStartになるわけではありません。まずキーボードでSpaceによる発射とEnterによるスタートを確認してください。
4. `mesen_spinner.ahk` をAutoHotkey v2で起動します。
5. Wiresharkのキャプチャを停止し、コントローラのUSBを抜きます。
6. `START_FIRE.cmd` をダブルクリック。表示された割り当てを確認してEnterを押します。
7. `Starting USBPcap1 monitoring` が出たらUSBを挿し直します。
8. `TAITO detected` の表示後に、操作したいアプリを前面にします。Mesen以外でもボタンをキーボード入力として使用できます。

終了は、ボタン変換の黒い画面で **Ctrl+C**。AutoHotkeyは **Ctrl+Alt+Q** です。旧版のボタン変換は終了してから新版を起動してください。

## MAME／MAMEUIで使う

**動作確認環境：MAMEUI64 0.263.0（Feb 28 2024）、Windows、アルカノイド。** パドル回転と本体右ボタンでの発射が確認できています。確認に使ったゲーム設定は `arkanoidjb` です。

### 1. MAME側の入力方式を変更する

MAMEUIを完全に終了し、`ini/mame.ini` など実際に読み込まれるINIの該当項目を次の値にします。同じ項目を重複させず既存の行を書き換えてください。

```ini
keyboardprovider          win32
mouseprovider             win32
mouse                     1
```

`arkanoidjb.ini` などゲーム専用のINIがある場合、そちらの値が優先されるため同じ設定にします。今回の環境では実行ファイルと同じフォルダ、および `ini` フォルダにゲーム用INIがありました。別のROMセットで遊ぶときは、そのセットの設定も確認してください。

Windows版MAMEの標準のRawInputでは、今回のようなソフトウェアによるキー・マウス入力を受け取れない場合があります。`win32` は0.263でも利用できます。[MAME 0.263の公式資料](https://github.com/mamedev/mame/blob/mame0263/docs/source/commandline/commandline-all.rst)

### 2. 回転とボタンの変換を両方起動する

- `mesen_spinner.ahk` を起動します。これは回転の変換です。
- コントローラのUSBを抜き、`START_FIRE.cmd` を起動してEnterを押します。監視開始後にUSBを挿し、`TAITO detected` を確認します。これはボタンの変換です。
- 全アプリ版の起動画面には `Input target: ALL APPLICATIONS` と表示されます。
- MAMEUIを起動し、アルカノイドを開きます。

`START_FIRE.cmd` だけでは回転は変換されません。

### 3. ゲームごとの入力を割り当てる

ゲーム中にTabを押し、そのゲームの入力設定を開きます。メニューや項目名はバージョン・表示言語によって異なります。

| MAME側の入力 | 初期設定で使うキー／軸 |
|---|---|
| P1 Dial Analog（ダイヤルのアナログ入力） | マウスX軸 |
| P1 Button 1（発射） | Space |
| 1 Player Start | Enter |
| Coin 1（コイン） | 通常はキーボードの5 |

マウスX軸は、割り当て待ちの状態で普通のマウスを左右に動かすと設定できます。ダイヤルの増加・減少用のデジタル入力欄ではなく、アナログ入力本体に割り当てます。ゲーム開始にはコイン入力も必要です。

SpaceやEnterが自動的に発射・スタートになるわけではありません。まず普通のキーボードとマウスで動作を確認し、その後パドルと本体ボタンを試してください。

### 4. 旧版から更新する

変換をCtrl+Cで終了し、最新版の `mesen_fire.ps1` と `EgretButtons.cs` を同じフォルダに置いて再起動します。編集済みの `buttons.json` は残してください。

「普通のSpaceキーは効く」「本体ボタンでKey down／upのログも出る」「でもMAMEでは発射しない」という症状は、スキャンコードを0で送っていた旧版の不具合でした。修正版は正しいスキャンコードを付けて送信します。

## ボタンをカスタマイズする

`buttons.json` をメモ帳などで編集し、保存してからボタン変換を再起動します。初期設定：

```json
{
  "right": "Space",
  "left": "Space",
  "topLeft": null,
  "topRight": null,
  "topBottom": "Enter"
}
```

| 設定名 | 物理ボタン | 初期設定 |
|---|---|---|
| `right` | 右ボタン | Space → 発射 |
| `left` | 左ボタン | Space → 発射 |
| `topLeft` | 上部左ボタン | 未割り当て |
| `topRight` | 上部右ボタン | 未割り当て |
| `topBottom` | 上部下ボタン | Enter → スタート |

アルファベットのA〜Zにも対応しています。例えば上部左をZ、上部右をXにする設定：

```json
{
  "right": "Space",
  "left": "Space",
  "topLeft": "Z",
  "topRight": "X",
  "topBottom": "Enter"
}
```

保存後にボタン変換を終了し、`START_FIRE.cmd` を再起動します。MesenやMAMEなど、使用するアプリ側でもZとXに使いたい機能を割り当ててください。

- 使用可能：`A`～`Z`、`0`～`9`（テンキーではない数字キー）、`F1`～`F12`、`Space`、`Enter`、`Escape`、`Tab`、`Backspace`、`Left`、`Right`、`Up`、`Down`、`Home`、`End`、`PageUp`、`PageDown`、`Insert`、`Delete`。
- キー名は大文字・小文字どちらでも可。`Esc` と `Return` も使用できます。
- 無効にするには引用符なしの `null` を指定します。
- 5つの設定名は省略せず、そのまま残してください。
- キー名の誤記や不正なJSONは起動時にエラーになります。
- 複数ボタンに同じキーを割り当てられます。キーの組み合わせ（`Ctrl+Z` など）やマクロには対応していません。

### 押しっぱなし・同時押し

各ボタンのビットを個別に判定し、押したときにキーを押下、離したときにキーを解放します。旧版の「Spaceを65ミリ秒だけ押す」方式から変更しています。連射を自動生成する機能はありません。

左右ともSpaceの場合は、右を押す → 左も押す → 右を離す、という操作でもSpaceは保持され、左も離すと解除されます。Enterなど別のキーとの同時押しにも対応します。

この版は全アプリで有効です。通常のキーボードと同様に、操作中（前面）のアプリへ設定したキーを送ります。全ウィンドウへの一斉送信ではありません。Mesenの起動は不要で、アプリを切り替えてもボタンを離すまでキーの押下状態を保持します。起動画面の `Input target: ALL APPLICATIONS` が目印です。

変換を終了するには黒い画面でCtrl+Cを押してください。

終了・キャプチャ停止時もキーを解除します。ただしUSBの物理切断だけを検知する機能はありません。接続し直す際は変換を終了してから、起動手順をやり直してください。

## USBPcapの番号・保存場所が異なる場合

コマンドプロンプトで `scripts` フォルダから起動できます。

```bat
START_FIRE.cmd -CaptureInterface USBPcap2
START_FIRE.cmd -TSharkPath "D:\Wireshark\tshark.exe"
START_FIRE.cmd -ConfigPath "D:\My Settings\buttons.json"
```

標準は `USBPcap1`、`C:\Program Files\Wireshark\tshark.exe`、スクリプトと同じフォルダの `buttons.json` です。

## 困ったとき

- **MAMEで、キーボードのSpaceは効くのに本体ボタンだけ効かない：** 変換ログが出ている場合、初期版でスキャンコードを0としていた不具合の可能性があります。修正版の `EgretButtons.cs` に置き換え、ボタン変換をCtrl+Cで終了してから再起動してください。MAME側は `keyboardprovider win32` を使用します。`buttons.json` は変更不要です。
- **起動直後にJoin-Pathの「Pathが空の文字列」エラー：** 初期配布版の不具合です。修正版の `mesen_fire.ps1` に置き換えてください。設定ファイルの場所を起動引数の既定値で計算していた処理を、本体の実行開始後へ移しました。`buttons.json` はそのまま使えます。
- **VAUSが動かない：** Mesenのパドル設定とAHKの起動を確認。普通のマウスでVAUSが動くかも試してください。回転が逆ならAHKの `-10` と `10` を入れ替えます。
- **TAITO detectedが出ない：** USBを抜く → 監視開始 → 挿し直す、の順序とUSBPcap番号を確認してください。
- **Spaceのログは出るが発射しない：** FireへのSpace割り当てと、Mesenが前面かを確認します。新版のログは `Key down: 0x20` / `Key up: 0x20` です。
- **スタートできない：** 1PコントローラのStartにEnterを設定してください。Enterのログは `0x0D` です。
- **設定エラー：** 半角の二重引用符、カンマ、引用符なしの `null` を確認してください。元の `buttons.json` に戻すこともできます。
- **ファイルが見つからない：** `scripts` 内の5ファイルを同じフォルダにそろえてください。
- **Capturing on 'USBPcap1'：** これは正常な開始メッセージです。新版ではTSharkの標準エラー出力をPowerShellの例外として扱いません。

## 動作確認

MAMEUI64 0.263.0で、回転と右ボタンによる発射は実機確認済みです。左ボタンの発射、上部下のスタート、左右の同時押しと片方だけの解放など、その他の組み合わせは必要に応じて実機確認してください。USB同時押しデータは各ビットの論理和になると想定しています。今回提供された単独押下の5つのデータはテストに収録しています。

開発用のオフラインテスト：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
```

5ボタンの全32状態の遷移、重複割り当て、無効化、アプリ判定なしの入力・終了時の解放、設定エラー、別機器の除外、キャプチャ子プロセスの終了を検証します。テストはキーボード入力や実際のUSBキャプチャを発生させません。

## 技術情報

[技術メモ](docs/technical-notes.md) ／ [Webガイド](index.html)

USBPcapは同じUSBバスの他の機器の通信も取得しうるため、キャプチャ中の機密情報入力は避けてください。このスクリプトは通信をファイル保存しません。`ExecutionPolicy Bypass` は起動したPowerShellプロセスだけに適用します。AutoHotkey側のホイール変換は他のアプリにも作用するため、使用後は終了してください。

タイトー、Mesen開発者とは無関係の非公式ガイドです。
