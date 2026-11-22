# イーグレットツーミニのパドルで Mesen の『アルカノイド』を遊ぶ

WindowsのMesen 2で、イーグレットツーミニ パドル＆トラックボールコントローラの回転と5つのボタンを使うためのガイドです。

パドル回転はAutoHotkey、ボタンはUSBPcap＋TShark＋PowerShellで変換します。追加の変換ハードウェアは不要です。

> 旧版ではパドル回転と右ボタンでの発射が実機確認済みです。今回の5ボタン版はオフラインテスト済みですが、実機での同時押し・Mesenの操作確認はこれからです。

[Webガイド](https://cac-gwd.github.io/egret2-mesen-paddle-guide/) ／ [最新版一式（ZIP）](https://github.com/cac-gwd/egret2-mesen-paddle-guide/archive/refs/heads/main.zip)

## 必要なもの

- Windows 10/11
- イーグレットツーミニ パドル＆トラックボールコントローラ（VID `0AE4` / PID `0701`）
- [Mesen 2](https://github.com/SourMesen/Mesen2/releases) または [MesenCE](https://github.com/nesdev-org/MesenCE/releases)
- [AutoHotkey v2](https://www.autohotkey.com/)
- [Wireshark（TSharkを含む）](https://www.wireshark.org/download.html) と [USBPcap](https://github.com/desowin/usbpcap/releases)
- Windows PowerShell 5.1（Windows標準搭載）
- 自分で用意したゲームデータ（この配布物には含まれません）

## 起動手順

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
8. `TAITO detected` の表示後にMesenを前面にしてプレイします。

終了は、ボタン変換の黒い画面で **Ctrl+C**。AutoHotkeyは **Ctrl+Alt+Q** です。旧版のボタン変換は終了してから新版を起動してください。

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

保存後にボタン変換を終了し、`START_FIRE.cmd` を再起動します。Mesen側でもZとXに使いたい機能を割り当ててください。

- 使用可能：`A`～`Z`、`0`～`9`（テンキーではない数字キー）、`F1`～`F12`、`Space`、`Enter`、`Escape`、`Tab`、`Backspace`、`Left`、`Right`、`Up`、`Down`、`Home`、`End`、`PageUp`、`PageDown`、`Insert`、`Delete`。
- キー名は大文字・小文字どちらでも可。`Esc` と `Return` も使用できます。
- 無効にするには引用符なしの `null` を指定します。
- 5つの設定名は省略せず、そのまま残してください。
- キー名の誤記や不正なJSONは起動時にエラーになります。
- 複数ボタンに同じキーを割り当てられます。キーの組み合わせ（`Ctrl+Z` など）やマクロには対応していません。

### 押しっぱなし・同時押し

各ボタンのビットを個別に判定し、押したときにキーを押下、離したときにキーを解放します。旧版の「Spaceを65ミリ秒だけ押す」方式から変更しています。連射を自動生成する機能はありません。

左右ともSpaceの場合は、右を押す → 左も押す → 右を離す、という操作でもSpaceは保持され、左も離すと解除されます。Enterなど別のキーとの同時押しにも対応します。

Mesen以外が前面になると、このプログラムが押したキーを解除します。Mesenに戻った際、押し続けていたボタンは一度離してから押し直してください。

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

- **起動直後にJoin-Pathの「Pathが空の文字列」エラー：** 初期配布版の不具合です。修正版の `mesen_fire.ps1` に置き換えてください。設定ファイルの場所を起動引数の既定値で計算していた処理を、本体の実行開始後へ移しました。`buttons.json` はそのまま使えます。
- **VAUSが動かない：** Mesenのパドル設定とAHKの起動を確認。普通のマウスでVAUSが動くかも試してください。回転が逆ならAHKの `-10` と `10` を入れ替えます。
- **TAITO detectedが出ない：** USBを抜く → 監視開始 → 挿し直す、の順序とUSBPcap番号を確認してください。
- **Spaceのログは出るが発射しない：** FireへのSpace割り当てと、Mesenが前面かを確認します。新版のログは `Key down: 0x20` / `Key up: 0x20` です。
- **スタートできない：** 1PコントローラのStartにEnterを設定してください。Enterのログは `0x0D` です。
- **設定エラー：** 半角の二重引用符、カンマ、引用符なしの `null` を確認してください。元の `buttons.json` に戻すこともできます。
- **ファイルが見つからない：** `scripts` 内の5ファイルを同じフォルダにそろえてください。
- **Capturing on 'USBPcap1'：** これは正常な開始メッセージです。新版ではTSharkの標準エラー出力をPowerShellの例外として扱いません。

## 動作確認

実機では、右・左それぞれの発射、上部下のスタート、左右の同時押しと片方だけの解放、パドル回転との併用を確認してください。USB同時押しデータは各ビットの論理和になると想定しています。今回提供された単独押下の5つのデータはテストに収録しています。

開発用のオフラインテスト：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
```

5ボタンの全32状態の遷移、重複割り当て、無効化、フォーカス喪失、設定エラー、別機器の除外、キャプチャ子プロセスの終了を検証します。テストはキーボード入力や実際のUSBキャプチャを発生させません。

## 技術情報

[技術メモ](docs/technical-notes.md) ／ [Webガイド](index.html)

USBPcapは同じUSBバスの他の機器の通信も取得しうるため、キャプチャ中の機密情報入力は避けてください。このスクリプトは通信をファイル保存しません。`ExecutionPolicy Bypass` は起動したPowerShellプロセスだけに適用します。AutoHotkey側のホイール変換は他のアプリにも作用するため、使用後は終了してください。

タイトー、Mesen開発者とは無関係の非公式ガイドです。
