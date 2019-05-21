---
layout: default
title: Azure Artifacts を使用した Nuget パッケージの管理（目次）
---

## はじめに

Azure Artifacts をちゃんと使ったことが無かったので検証した際の備忘録です。
下記は大まかなワークフローというか、やりたいことを整理するための図になります。

![パッケージ管理の全体像](./images/package-management-workflow.png)

組織内での開発資産の共有という観点からは、共有ライブラリや便利ツールなどの「他の人に使ってもらう」ための部品となるパッケージを開発する側と、それらの部品を利用して実際にエンドユーザーに使ってもらうアプリケーション開発側と、大きく２つの立場があります。
これら異なる立場では製品の開発ライフサイクルが大きく異なるため、そのパッケージを受け渡すための中間地点となるリポジトリが必要になってくるわけですが、それをマネージドサービスとして提供するものが Azure Artifacts になります。
以降ではこれらの 2 つの立場から見た Azure Artifacts への関わり方を見ていきたいと思います。

なお Azure Artifacts は様々な種類の言語とパッケージを扱えるのですが、以降ではプログラミング言語は C# (.NET Core)、パッケージ形式は Nuget を題材にしています。

### ちょっと個人的な昔話（組織内における共通部品の管理について）

古来からのやり方ですと、「部品」の基となるソースコードを丸ごとコピーして使ってもらう、あるいはビルド済みバイナリ形式であるアセンブリ（通常は dll）をコピーしてもらうことが多かったかと思います。
前者の方法では部品としての完全性が保てず、利用側で改変しやすいために亜種が発生しやすく、結果的にメンテナンスが困難になりやすいため、後者のバイナリでの配布形式をとられていたことが多いのではないでしょうか。
ただバイナリ形式の場合でも、配布の方式がまちまちであること、利用側へのアップデートの伝達が困難であること、その結果として古代のバージョンが延々と使われ続けてしまう、などといった問題が往々にして発生しました。

なんだかんだいって「共有フォルダに置かれた DLL を勝手に使っていくスタイル」が蔓延っていたなあなどと懐かしく思うわけです。
まあ組織内でのパッケージ管理の仕組みをちゃんと運用すれば良いわけですが、その仕組み自体をだれがサポート・保守・運用するのさ？ ということで誰もやらないパターンでした。
が、Azure DevOps などの SaaS サービスを使ってしまえばその問題は発生しにくくなりますので、改めて勉強してみようと思った次第です。

## 目次

- [その１ - 開発環境における NuGet パッケージの作成と Azure Artifacts への公開](./contents1.md)
- [その２ - 開発環境における Azure Artifacts に格納された NuGet パッケージの利用](./contents2.md)
- [その３ - Azure Pipeline を使用して NuGet パッケージを Azure Artifacts に自動リリースする](./contents3.md)
- [その４ - Azure Artifacts に格納された NuGet パッケージを Azure Pipeline から取得する](./contents4.md)


### 参考情報

- [NuGet パッケージの作成](https://docs.microsoft.com/ja-jp/nuget/what-is-nuget)
- [Azure Artifacts の利用](https://docs.microsoft.com/en-us/azure/devops/artifacts/get-started-nuget?view=azure-devops)
- [Azure Pipeline の利用](https://docs.microsoft.com/en-us/azure/devops/pipelines/get-started/overview?view=azure-devops)
