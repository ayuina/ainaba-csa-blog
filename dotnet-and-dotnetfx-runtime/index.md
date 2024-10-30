---
layout: default
title: .NET Framework アプリケーションを .NET (Core) へ移行する？しない？
---

# はじめに

.NET の歴史を振り返ってみると 2002 年に .NET Framework 1.0 がリリース、2016 年に .NET Core 1.0 が 2016 年にリリース、
2020 年にリリースされた .NET 5 が .NET Framework と .NET Core の統合された後継として位置づけられ、
今年（2024 年）に .NET 9 がリリースされる予定です（現在10月なのでまだRC2）。
私の IT のキャリアは .NET Framework 1.0 とのお付き合いから始まったといっても過言ではなく、長いお付き合いになったなあと感慨深い気持ちになります。

なーんて昔話をしたいわけではなく、最近は「.NET Framework で作られた既存資産は今後どうしたらいいのか？」というご相談もいただ供養になってきました。
移行方針は単純な技術論で決まるものではなく、既存アプリの特性、現在の運用の状況、移行にかけられるコストと期間、自社あるいはパートナーのポートフォリオ、今後の保守の計画など様々な要因を考慮することになるので、「これが正解！」と言えるものが無いというのが厄介です。
とはいえ、技術的な観点も無視出来るわけではもちろんなく、互換性や移植性は意識しておく必要があります。

というわけで、今更ながらちょっと移行方針を検討する上で前提となる知識を整理しておこうかなと思った次第であります。
現在の正式名称は **.NET** なのですが、字面からして **.NET Framework** と区別がつきにくいので、本記事ではあえて旧名称である **.NET Core** と記載しています。
あと Framework もちょっと長いので **.NET Fx** と省略表記することにします。

# 移行方式検討の観点

移行方式検討の際に議論の焦点になりやすいのは以下の観点かなと思いますので、以降ではこれらについて整理していきたいと思います。

- アプリケーションフレームワークと実行プラットフォーム
- ASP.NET 4.x と ASP.NET Core
- プログラミング言語
- サポートライフサイクル
- 実行プラットフォーム(OS)
- クラウド対応

## アプリケーション フレームワークと実行プラットフォーム

.NET Core はクロスプラットフォームという側面が強くアピールされることが多く、また .NET Fx の後継でもあることから、期待値が最大限に高まると「古い .NET Fx のアプリがあるんだけど、これ Linux でも動くんでしょ？」という話になりがちです。
残念ながらそんな素敵な世界は実現できていないというのが現実です。

「.NET Fx で作られたアプリ」と一言で言っても、実体としては様々なアプリケーション フレームワークが存在し、その上で動作するように実装されたユーザーアプリなわけです。
まずこのアプリケーション フレームワークが、.NET Fx と .NET Core で一致しない部分が多々あります。
またアプリをデプロイして実行するプラットフォーム(OS) という観点で言えば、.NET Fx は Windows 一択ですが .NET Core はマルチプラットフォームです。
とはいえすべてのアプリケーション フレームワークが 全ての対応 OS 上で動作するというわけでもありません。

というややこしい状況があるので表にしてみました。
.NET Fx と .NET Core で類似のアプリケーション フレームワークが提供されているか？という観点で整理したものですので、
**互換性が保証されているとか移植が容易とかいうものではないことにご注意ください。**
.NET Core への移植先の選択肢として比較的取り組みやすいものが何か、という観点でご参照ください。

|ワークロード|.NET Fx 4.8|.NET Core 9|
|:--|:-:|:-:|
| Console                          | W                  | W, L, M      |
| Class Library                    | W                  | W, L, M      |
| Web Forms (aspx)                 | W                  | -            |
| XML Web Services (asmx)          | W                  | -            |
| MVC                              | W                  | W, L, M      |
| Web Pages                        | W                  | -            |
| Razor Pages                      | -                  | W, L, M      |
| Blazor                           | -                  | W, L, M      |
| Web API (Controller base)        | W                  | W, L, M      |
| Web API (Minimul)                | W                  | W, L, M      |
| SignalR                          | W                  | W, L, M      |
| gRPC                             | -                  | W, L, M      |
| Windows Forms                    | W                  | W            |
| Windows Presentation Foundation  | W                  | W            |
| Windows Communication Foundation | W                  | -            |
| Windows Workflow Foundation      | W                  | -            |
| MAUI                             | -                  | W, A, I, M   |
| Windows Service                  | W                  | W            |

表中の記号は .NET Fx / .NET Core で対応するプラットフォームを表したものです。
- W: Windows
- L: Linux
- A: Android
- M: macOS
- I: iOS

## ASP.NET 4.x と ASP.NET Core

ASP.NET は Web アプリや Web API を開発するためのフレームワークですが、そこで開発出来るアプリの種類にもバリエーションがあります。
前述の表で言う Web Forms から gRPC までが ASP.NET で作れるアプリケーションの種別に該当します。

この ASP.NET も .NET Core が開発される際に合わせて再設計され、ASP.NET Core という名前になりました。
.NET Core の名前は Version 5 がリリースされた際に `Core` が取れて単独の `.NET` が正式名称になりましたが、ASP.NET に関して言えば現在でも Core が残っています。
ざっくり言えば .NET Fx 上で動くのが ASP.NET であり、.NET 上で動くのが ASP.NET Core というフレームワークです。
ASP.NET Core と区別するために .NET Fx 上で動く方を ASP.NET Framework と表記しているドキュメントもあります。

表にまとめる際にマッピングするために明確な区別はしませんでしたが、ASP.NET Core は ASP.NET を元に **再設計された** フレームワークですので、
厳密に言えば [ASP.NET と ASP.NET Core は別物](https://learn.microsoft.com/ja-jp/aspnet/core/fundamentals/choose-aspnet-framework?view=aspnetcore-8.0)です。
とはいえプログラミング モデルなど様々なものを継承しており、例えば ASP.NET MVC の後継として ASP.NET Core MVC が開発されていますので、他のものに比べるとアップグレードの容易性は高いでしょう。
[ASP.NET から ASP.NET Core へのアップグレード](https://learn.microsoft.com/ja-jp/aspnet/core/migration/proper-to-2x/?view=aspnetcore-8.0) に関しては公式ドキュメントも参考にして下さい。

> より正確に言えば .NET Fx 上で動作する ASP.NET Core というものが存在します。
> つまり .NET Fx でも .NET Core でも動作する ASP.NET のフレームワークです。
> しかし、こちらは ASP.NET Core 2.x までが両対応しており、その後 .NET Core 3.0 とともに開発された ASP.NET Core 3.0 およびそれ以降のバージョンは .NET Fx 上で動かすことはできず .NET Core のみで動作します
> もし現在 .NET Fx で動かしているアプリケーションが ASP.NET Core 2.x であれば、現在も開発が続いている ASP.NET Core の系譜なので移行性は高いかと思います。

## プログラミング言語

.NET Fx は C# と VB.NET といった複数のプログラミング言語で開発したアプリケーションを、共通のクラスライブラリおよびランタイム上で動かすことが出来る、というのがウリの１つでした。
.NET Core においても C# および VB.NET の両方が利用できるのですが、実はこれも上記のアプリケーション フレームワークによって制限があります。

まず大きな注意点として ASP.NET Core は C# および F# のみをサポートしています。
このため ASP.NET MVC などの類似のアプリケーション フレームワークが提供されているパターンであったとしても、VB で作られている場合にはコードの書き換えが必要になり、一気に移行の難度と工数が高まります。
それ以外のフレームワーク Console、 ClassLibrary、Windows Forms、WPF では[引き続き Visual Basic がサポートされています](https://devblogs.microsoft.com/vbteam/visual-basic-support-planned-for-net-5-0/)ので、
これらの種別のアプリケーションであれば .NET Core においても VB のまま保守を継続することが出来るでしょう。

上記リンク先のブログに記載がありますが Visual Basic は言語として進化する予定がないとのことです。
言語として安定しており、多くの VB エンジニアも現役であるということは、アプリケーションの保守性の観点から価値は高いといえます。
ただ今後 ASP.NET Core アプリケーションの多くは C# で書かれることになるでしょうし、また現時点でも VB 対応のフレームワークにおいてもサンプルコードやリファレンスの多くが C# で提供されています。
つまり将来的には VB 関連の情報収集が難しくなるでしょうし、VB 開発者人口も徐々に減っていく可能性が高いのではないかと想像しています。
このため中長期的には VB で作られたソースコード資産は移行を迫られることになるのではないでしょうか。
（あくまでも個人の予想です）

## サポート ライフサイクル

本記事執筆時点で .NET Fx は最新かつ最終バージョンが 4.8 で、.NET Core は最新が バージョン 9 (RC2) になります。
「バージョンが新しい方がサポート期間が長い」と勘違いしてしまいそうですが、実はそうでもありません。

### .NET Fx の場合

.NET Fx は現在では Windows OS のコンポーネントの１つとして位置づけられており、そのサポート期間は搭載された Windows OS に準じます。
そして .NET Fx は Windows 11 や Windows Server 2022、および次期サーバー OS で現在プレビュー中の Windows Server 2025 でも .NET Fx は 3.5 と 4.8 が搭載されています。

- [ライフサイクルに関する FAQ - .NET Framework](https://learn.microsoft.com/ja-jp/lifecycle/faq/dotnet-framework)
- [Windows Server のエディションの比較](https://learn.microsoft.com/ja-jp/windows-server/get-started/editions-comparison?pivots=windows-server-2025)

つまり ASP.NET をホストするサーバー OS がサポート期間中であれば、そこで動く .NET Fx および ASP.NET もサポート期間に含まれるということになります。
これは（多くの場合）クライアント OS 上で動く Windows Forms や WPF などでも同じ考え方になります。
以下に代表的なものを記載しますが、サポートライフサイクルの詳細は公式ドキュメントで確認するようにしてください。

|OS|延長サポート終了|
|---|---|
|Windows Server 2016|[2027 年 1 月 12 日](https://learn.microsoft.com/ja-jp/lifecycle/products/windows-server-2016)|
|Windows Server 2019|[2029 年 1 月 9 日](https://learn.microsoft.com/ja-jp/lifecycle/products/windows-server-2019)|
|Windows Server 2022|[2031 年 10 月 14 日](https://learn.microsoft.com/ja-jp/lifecycle/products/windows-server-2022)|
|Windows 10 22H2|[2025 年 10 月 14 日](https://learn.microsoft.com/ja-jp/windows/release-health/release-information)|
|Windows 11 24H2|[2027 年 10 月 10 日](https://learn.microsoft.com/ja-jp/windows/release-health/windows11-release-information)|
|Windows 11 24H2 LTSC|[2034 年 10 月 10 日](https://learn.microsoft.com/ja-jp/windows/release-health/windows11-release-information)|

.NET Core に移行せずに .NET Fx ベースのままで保守を継続するのであれば以下がポイントになるといえます。

- .NET Fx の最新版である 4.8 までアップグレードする
- 実行環境である Windows OS をサポートが受けられる状態に保つ

### .NET Core の場合

.NET Core は各バージョンごとにライフサイクルが決められています。
大きく分けて偶数バージョンの長期サポート（LTS）がリリース日から 3 年、奇数バージョンの標準機間サポート（STS）が 18 か月になります。
慣例では毎年11月にメジャーバージョンアップがありますので、LTS の場合は次の LTS がリリースされてから 1 年、STS の場合は次の LTS が出てから半年、ということになります。

|バージョン|リリース日|サポート終了|
|---|---|---|
|.NET 10 LTS|2025 年 11 月|2028 年 11 月|
|.NET 9 STS|2024 年 11 月|2026 年 5月|
|.NET 8 LTS|2023 年 11 月 14 日|2026 年 11 月 10 日|
|.NET 7 STS|2022 年 11 月 8 日|2023 年 5 月 14 日|
|.NET 6 LTS|2021 年 11 月 8 日|2024 年 11 月 12 日|

本記事執筆時の 2024 年 10 月現在の状況としては以下のようになります。

- .NET 9 および 10 は正式リリースされていませんので、上記の日付は確定されたものではなく、過去の状況から推定されるものになります
- .NET 8 はあと 2 年程度のサポート期間が残されています
- .NET 7 は既にサポート期間が終了しています
- .NET 6 はもうじき .NET 9 の正式リリースされる頃にサポート期間が終了します

このように最長のサポート期間を持つ LTS でも 3 年という、.NET Fx のサポートライフサイクルからするととても短いサポート期間しかありません。
このため .NET Fx から .NET Core に移行する場合には、このサポート ライフサイクルに追従するために保守プロセスの改善が必要になる可能性が高いことに注意が必要です。

## プラットフォーム(OS)

.NET Core の登場で複数のプラットフォーム（OS）上で動作するアプリケーションを開発することが出来るようになりました。
とはいえ、Windows Form、Windows Presentation Foundation、Windows Service といったいかにも `Windows` というタイプのアプリケーションを、macOS や Linux 上で動かせるわけではありません。
.NET Fx 時代と類似のアプリケーション フレームワークを提供し、かつ、クロスプラットフォーム対応できるという意味では ASP.NET や Console アプリケーションとなるでしょう。
ざっくり言えば Web サーバー上で動作している Web アプリや Web API、常駐型のバックグラウンド処理や定時バッチなどで使われていたようなコマンドライン型のアプリケーションです。

従来 .NET Fx で作られたアプリを Windows 以外で動かしたいので .NET Core に移行しよう、となるような代表的なトリガーは以下のようになるのではないでしょうか。

- Linux コンテナ化して動かしたい
- Mac や Linux を開発端末として利用したい

そしてこれらの阻害要因となるのは Windows 固有の機能を利用しているケースです。

### .NET Core コンテナアプリ

アプリの実行環境を Kubernetes や RedHat OpenShift のようなコンテナ基盤上で動かしたいとなれば、現実的には Linux 化が必要になることが多く、その場合は .NET Core への移行が必要です。
もちろん Windows コンテナという選択肢もあるので、その場合は .NET Fx のままコンテナ化するという選択肢も存在します。
ただ以下の理由から Linux 化することが多いんじゃないでしょうか。

- クラウドサービスで提供されている Container as a Service は Linux コンテナを要求するものが多い
- インターネットに出回っているコンテナ系の情報の多くは Linux を前提としている
- Windows Server コンテナ技術者は（おそらく）それほど多くない

### 開発端末として Mac および Linux を使いたい

これが理由でアプリケーションを .NET Fx から .NET Core にする、なんてことは滅多にないだろうとは思いますが、.NET Core アプリは Windows 以外でも動作するだけでなくアプリケーション開発も可能です。
Visual Studio for Mac は残念ながら [2024 年 8 月 31 日にサポートが終了](https://learn.microsoft.com/ja-jp/visualstudio/releases/2022/what-happened-to-vs-for-mac) しました。

このため Windows 以外の端末で .NET Core アプリを開発する場合には Mac や Linux に Visual Studio Code をインストールして利用するケースが多いのではないでしょうか。
VSCode には C# でのアプリケーション開発を支援する拡張機能が Microsoft 公式からいくつか提供されています。

- [C# Dev Kit](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csdevkit)
- [IntelliCode for C# Dev Kit](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.vscodeintellicode-csharp)
- [C#](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csharp)

このうちご注意いただきたいのが [C# Dev Kit は Visual Studio のライセンスが必要](https://marketplace.visualstudio.com/items/ms-dotnettools.csdevkit/license) ということです。
有償か無償かという意味で言えば無償で使おうと思えば使えますが、個人開発、アカデミア、OSS 開発など Visual Studio Community のライセンスが得られるのと同条件が必要になります。
これ以外のケースで利用する場合は Visual Studio のライセンスを別途購入する必要がある、ということになります。
なお後述の GitHub Codespaces 上で利用する場合にはそちらにライセンスが含まれる形になりますので、別途 Visual Studio を購入する必要はありません。
詳細は上記のライセンス条項をよく読んでご利用ください。

### GitHub Codespaces 

.NET Core アプリを Linux で開発したいもう 1 つのユースケースは [Github Codespaces](https://github.co.jp/features/codespaces) を利用出来るという点だと思います。
GitHub Codespaces はそれ単独でも便利ですが、[Dev Container](https://docs.github.com/ja/codespaces/setting-up-your-project-for-codespaces/adding-a-dev-container-configuration/introduction-to-dev-containers) と合わせて利用することで、構成ファイルで開発環境を定義・共有し、かつ手元の開発端末を汚さずに済むクラウドベースの開発環境が手に入ります。

GitHub Codespaces で .NET Core アプリを開発する際にお勧めしたいのは [Port Forwarding](https://docs.github.com/ja/codespaces/developing-in-a-codespace/forwarding-ports-in-your-codespace) の機能です。
これを利用することでインターネット FQDN を使用して開発中の ASP.NET Core アプリへ転送することが出来るようになります。
SaaS の WebHook を開発したいケースなどでは Build と Debug を繰り返しながらインターネト経由でのリクエストを受けられるのは非常に便利です。
ローカル開発端末では ngrok や Dev Tunnel を利用したりしますが、GitHub Codespaces だとそれらのツールも不要になるということになります。


### Windows 固有機能を使用するアプリケーションに注意

Windows 上で動作する .NET Fx アプリを Linux や Mac でも動作する .NET Core アプリに移植したい、というときに気を付けなければならないことは、（当然のことながら） Windows と Linux/macOS は互換性がなく、Windows 固有の機能は Linux や macOS には存在しません。
.NET やクラスライブラリが非互換を吸収してくれているケースはいいのですが、無い場合は互換レイヤーを自力で作り上げるか、その機能をまるっと別の実装に切り替えることになります。
規模にもよりますが、移行というよりは再開発に近い工数が必要になるのではないでしょうか。

これは様々なケースが考えられるのですが、私が遭遇したのは以下のようなものでした。

- Windows 標準の Web サーバーである IIS : Internet Information Service の機能に依存している
- COM や Win32 API などを呼び出している（個人的な観測範囲では Excel が多い）
- Windows DTC や DCOM といった COM＋ サービスを活用している
- Windows タスクスケジューラや Windows サービスマネージャーからの制御を前提としている
- レジストリの読み書きがある
- GDI+ を使用したレンダリングを行っている
- Etc...

## クラウド対応

現時点で .NET Fx を移行するとなれば、動作環境としてオンプレミスだけでなくクラウドも視野に入ってくることでしょう。
クラウドとの親和性という意味では 2002 年に最初のバージョンがリリースされ現在では開発が止まっている .NET Fx に比べると、2024 年現在でも活発に開発が続けられている .NET Core の方に軍配があがるのは当然です。

.NET Fx で作られたアプリはクラウドで全く動かないかといえばそんなことはもちろんないのですが、対応は限定的といえます。
数あるクラウドサービスの中でも同じ Microsoft がサービス提供している Azure が .NET Fx との親和性が高いことを期待したいですが、
.NET Fx は Windows しか対応していないので Linux にも対応する .NET Core に比べると限定的です。

.NET Fx アプリを Azure 上で動作させる際の選択肢は以下のようになります。(全てを網羅できていないと思いますが)

- Azure Windows 仮想マシン
- Azure Container Instance - Windows
- Azure Batch - Windows Compute node
- Azure App Service - Windows / Windows Server Container
- Azure Kubernetes Service - Windows Node Pool
- Azure Funcitons v1.x （2026年9月にサポート切れ）

.NET Core へ移行、さらに Linux 対応まで含めると以下の選択肢が増えてきます。

- Azure Linux 仮想マシン
- Azure Container Instance - Linux
- Azure Batch - Linux Compute Node
- Azure App Service - Linux / Linux Container
- Azure Kubernetes Service - Linux Node Pool
- Azure RedHat OpenShift
- Azure Container Apps
- Azure Funcitons v4.0

上記の Linux 版に加え、ARO、ACA、Funcitons（最新版）といった PaaS のバリエーションが多くなります。

# まとめ

.NET Fx から .NET Core に移行する（しない）という議論の中で良く話題に上がる観点をリストアップしてみました。
残念ながら .NET Fx と .NET Core は完全な互換性があるわけではないので、相応の非互換対応が必要になります。
そしてそれに伴うテストも必要になってくるわけです。

サポート ライフサイクルから読み取れるように現時点では .NET Core への移行が急務であるという状況でもありません。
冒頭に記載したように移行の最適解は既存アプリの特性、現在の運用の状況、移行にかけられるコストと期間、自社あるいはパートナーのポートフォリオ、今後の保守の計画など様々な要因によって異なってきます。
ご自身のアプリケーションと向き合い、今ある選択肢の中から適切な移行方針を（あるいは移行しないという方針を）選び取る一助になれば幸いです。
