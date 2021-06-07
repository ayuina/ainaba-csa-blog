---
layout: default
title: Azure Blob Storage の認証とアクセス制御
---

## はじめに

目新しい話でもなんでもないのですが、それこそ Azure 開始当初から「Azure の Storage を使用したいが何を使用して認証すれば良いか、アクセス制御をどうすればいいのか」というご質問を良く頂きます。
[ストレージアカウント](https://docs.microsoft.com/ja-jp/azure/storage/common/storage-account-overview)は数ある Azure サービスの中では最古参といっていサービスですが、
そこから長い時間をかけて進化し、それに伴い認証や権限管理に関する機能も充実してきています。
長年触っていればともかく、初学の方には分かりにくいことをこの上ないとも思いますので、改めて整理してみました。
全パターン網羅するのは大変なので、最も出番の多い Blob サービスに絞って解説しています。

## 大雑把なパターン分け

ストレージアカウントに限らず Azure は REST API の集合体なのですが、
それらは[コントロールプレーンとデータプレーン](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/management/control-plane-and-data-plane)の 2 つにカテゴライズされます。
これは Azure Blob に限定すると、以下のような区別になります。

- コントロールプレーン
	- Blob コンテナーの作成・削除、ストレージキーの取得・更新といった管理操作を行う
	- 多くの場合 Azure 環境の構築時に構成する内容で、アプリケーションからはあまり操作しないことが多い
	- [API Reference](https://docs.microsoft.com/en-us/rest/api/storagerp/)
- データプレーン
	- Blob コンテナー内の Blob の作成・読み取り・更新・削除などのデータ操作を行う
	- データ操作が必要なアプリケーションでは、多くの場合データプレーンの操作が主体となる
	- [API Reference](https://docs.microsoft.com/ja-jp/rest/api/storageservices/blob-service-rest-api)

これらの操作に対して、認証とアクセス制御の方式が複数用意されています。

- 共有キー（ストレージアカウントキー）を使用した認証
- SAS : Shared Access Signature を使用した認証とアクセス制御
- AAD : Azure Active Directory と RBAC : Role Based Access Control を使用した認証とアクセス制御

つまり理論上は 2 x 3 = 6 パターンの組み合わせがありうるわけですね。
実際にはサポートされていない組み合わせや、言語や SDK の制限から使えないパターンもあるのですが、それぞれの組み合わせと特徴を理解しておくということが大事だと思います。
そのうえで開発する対象サービスの要件や制限事項に合わせて適切な API を、適切な認証方式で呼び出し、適切なアクセス制御で守る、ということになってきます。

なお Files サービスに SMB でアクセスするときはオンプレミス [ADDS : Active Directory Domain Service](https://docs.microsoft.com/ja-jp/azure/storage/files/storage-files-active-directory-overview)を使用した
認証もサポートされていますが、ここでは割愛します。