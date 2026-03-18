<p align="center">
  <a href="README.md"><img alt="简体中文" src="https://img.shields.io/badge/Language-ZH-2ea043"></a>
  <a href="README.en.md"><img alt="English" src="https://img.shields.io/badge/Language-EN-4c8eda"></a>
  <a href="README.ja.md"><img alt="日本語" src="https://img.shields.io/badge/Language-JA-f4c542"></a>
</p>

<p align="center">
  <img src="pack_assets/HeyboxCardStatsOverlay/mod_image.png" alt="STS2 Card Stats Overlay" width="160">
</p>

<h1 align="center">STS2 カード統計オーバーレイ</h1>

<p align="center">
  Slay the Spire 2 のカード選択、確認、デッキ構築の流れに、コミュニティカード統計をそのまま重ねて表示します。
</p>

<p align="center">
  カードにカーソルを合わせるだけで、勝率、取得率、スキップ率、サンプル数、クラス内順位を確認できます。
</p>

<p align="center">
  <a href="https://github.com/XMeowchan/STS2_Card_Stats/releases"><strong>最新版をダウンロード</strong></a>
  ·
  <a href="https://github.com/XMeowchan/STS2_Card_Stats/releases">Releases を見る</a>
</p>

<p align="center">
  <img alt="release" src="https://img.shields.io/github/v/release/XMeowchan/STS2_Card_Stats?label=Release&color=2ea043">
  <img alt="game" src="https://img.shields.io/badge/Game-Slay%20the%20Spire%202-f4c542">
  <img alt="platform" src="https://img.shields.io/badge/Platform-Windows%20%7C%20Steam-4c8eda">
</p>

<p align="center">
  <a href="#スクリーンショット">スクリーンショット</a>
  ·
  <a href="#現在のハイライト">現在のハイライト</a>
  ·
  <a href="#インストール方法">インストール方法</a>
  ·
  <a href="#使い方">使い方</a>
  ·
  <a href="#faq">FAQ</a>
</p>

| ホバーですぐ確認 | ブラウザ不要 | 参考情報のみ |
| --- | --- | --- |
| 重要な統計をカードの横に直接表示 | カード選択、確認、構築をゲーム内で完結 | カード効果、戦闘進行、セーブデータは変更しません |

## スクリーンショット

以下の画像では、ホバー統計、カードライブラリの並び替え、単体カード詳細パネルを確認できます。

<table>
  <tr>
    <td align="center" width="50%">
      <img src="docs/images/readme-feature-hover-stats.png" alt="カードにホバーしたときに統計と説明を表示" width="100%">
      <br>
      <strong>ホバーですぐ統計表示</strong>
      <br>
      カードツールチップの横に勝率、取得率、スキップ率、クラス内順位を表示します。
    </td>
    <td align="center" width="50%">
      <img src="docs/images/readme-feature-library-sort.png" alt="カードライブラリを取得率と勝率で並び替え" width="308">
      <br>
      <strong>ライブラリを素早く整理</strong>
      <br>
      取得率、勝率、名前順を切り替えて、見たいカードをすばやく探せます。
    </td>
  </tr>
  <tr>
    <td align="center" colspan="2">
      <img src="docs/images/readme-feature-card-detail.png" alt="単体カード詳細画面に統計パネルを表示" width="100%">
      <br>
      <strong>カード詳細でも表示</strong>
      <br>
      1 枚のカードに集中して確認するときも、同じ統計パネルを維持します。
    </td>
  </tr>
</table>

## 現在のハイライト

この README は現在 `v0.2.4` をベースに紹介しています。

- カードライブラリを取得率 / 勝率で並び替えでき、強いカードを見つけやすい
- README に匿名ユーザー推移を掲載し、プロジェクトの成長を把握しやすい
- インストーラー、ポータブル版、リリーススクリプトが同じビルドフローを共有し、リリースが安定している

## ユーザー推移

<p align="center">
  <img src="https://xmeowchan.github.io/STS2_Card_Stats/users-history.svg?v=20260314-042406" alt="STS2 Mod ユーザー推移" width="100%">
</p>

> この曲線は Mod の匿名デイリーハートビートに基づいています。各インストールは 1 日に最大 1 回だけ報告し、ランダムなインストール ID だけを使用します。Steam アカウント、ユーザー名、ハードウェア指紋は収集しません。

## この Mod について

この Slay the Spire 2 用 Mod は、カードのホバーツールチップや単体カード詳細画面の横に統計パネルを追加し、ゲーム内でコミュニティデータを直接参照できるようにします。

表示できる内容:

- 勝率
- 取得率
- スキップ率
- 取得回数、勝利数、敗北数、更新時刻
- クラス内での相対順位
- カードライブラリでの取得率 / 勝率ソート

これらはすべてコミュニティ統計であり、参考情報としてのみ提供されます。カード挙動、戦闘フロー、セーブデータは変更しません。

## どんな場面で役立つか

| 利用シーン | 得られること |
| --- | --- |
| カード報酬選択時 | ゲームを離れずに、そのカードを取る価値があるか判断しやすい |
| デッキ構築時 | 取得率、勝率、クラス内順位を素早く比較できる |
| カード確認時 | ライブラリと単体カード詳細の両方で同じ参考パネルを維持できる |

## インストール方法

もっとも簡単なのはインストーラーを使う方法です。

1. [Releases](https://github.com/XMeowchan/STS2_Card_Stats/releases) を開く
2. 最新の `HeyboxCardStatsOverlay-Setup-バージョン.exe` をダウンロードする
3. 先にゲームを終了する
4. インストーラーを実行する
5. 完了後に Slay the Spire 2 を起動する

インストーラーは自動で Mod をゲームの `mods` フォルダへ配置します。

インストーラーの警告が気になる場合は、`portable.zip` をダウンロードして手動でコピーすることもできます。

## 手動インストール

1. Slay the Spire 2 のゲームフォルダ内にある `mods` フォルダを見つける
2. `HeyboxCardStatsOverlay` フォルダを丸ごとそこへコピーする
3. ゲームを起動する

最終的なパス:

```text
Slay the Spire 2\mods\HeyboxCardStatsOverlay
```

## 安全性について

- 現在のインストーラーには商用コード署名証明書がまだ付いていないため、Windows やブラウザが「発行元不明」や「一般的でないファイル」と警告することがあります。これは多くの場合、評判不足を示すもので、マルウェア確定を意味しません。
- 公開された正式な配布元は、このリポジトリの [GitHub Releases](https://github.com/XMeowchan/STS2_Card_Stats/releases) のみです。
- インストーラーは Slay the Spire 2 のフォルダを探し、`HeyboxCardStatsOverlay` をゲームの `mods` フォルダへコピーするだけです。サービス、タスクスケジューラ、自動起動などは追加しません。
- インストーラーを使いたくない場合は `portable.zip` で手動導入できます。
- Mod はデフォルトで 3 つのネットワーク動作を行います: カード統計の取得、GitHub Releases の更新確認、アクティブインストール数のための匿名ハートビート送信。
- ネットワーク動作を無効にしたい場合は、Mod フォルダ内の `config.cfg` を編集し、`remote_data_enabled`、`mod_update_enabled`、`telemetry_enabled` を `false` にしてください。

## 使い方

インストール後は追加設定なしで使えます。

1. ゲームを起動する
2. カードにカーソルを合わせる
3. 横に表示される統計パネルを見る

## FAQ

### ダウンロードが危険扱いされる / 発行元不明と表示される

インストーラーに商用コード署名証明書が付いていないため、Windows やブラウザが「発行元不明」や「一般的でないダウンロード」と判定することがあります。

気になる場合は、次の方法をおすすめします。

- このリポジトリの GitHub Releases からのみダウンロードする
- `portable.zip` で手動インストールを優先する
- Windows セキュリティや普段使っているウイルス対策ソフトで再スキャンする
- ソースコードを確認するか、今後の正式署名付きリリースを待つ

### この Mod はどんなデータを送信するか

- デフォルトでは遠端のカード統計を取得します
- デフォルトでは GitHub Releases の更新確認を行います
- デフォルトでは 1 日 1 回、匿名インストール ID、Mod バージョン、プラットフォーム、OS バージョン、送信時刻だけを含む匿名ハートビートを送信します

### インストールしたのに統計パネルが見えない

まず次を確認してください。

- ゲームを完全に再起動したか
- Mod が `Slay the Spire 2\mods\HeyboxCardStatsOverlay` に入っているか
- 直前に更新した場合は、一度ゲームを再起動してから再確認する

### 一部のカードにデータがないのはなぜか

多くの場合、現在のデータセットにそのカードがまだ含まれていないだけです。

### データは手動で更新する必要があるか

通常のプレイヤーは不要です。インストールしたらそのまま使えます。

### ユーザー推移は何を収集するか

匿名インストール ID、Mod バージョン、プラットフォーム、送信時刻だけを送信し、累計ユーザー数と日次アクティブ数を集計します。

匿名統計に参加したくない場合は、`config.cfg` の `telemetry_enabled` を `false` にしてください。
