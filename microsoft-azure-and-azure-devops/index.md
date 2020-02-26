---
layout: default
title: Microsoft Azure と Azure DevOps Service
---

## はじめに

Azure と Azure DevOps の関係がよくわからん、と言うご質問をいただくことが多いので、共通点や違いについて私なりに整理してみました。

## ざっくり

Azure と言うブランディングで提供されるサービス群の中の１つに DevOps サービスがあるわけですが、個人的には根本的には独立したサービスであるとご理解いただいた方が良いかなと思っています。
もちろん共通点が全くないわけではありません。

- Microsoft が提供するクラウドサービスであること
- Azure Active Directory を認証基盤としていること
- Azure のデータセンター上で稼働していること

これが意味することは、 Azure と DevOps は連携しやすい、と言うことですね。
開発者むけの SaaS サービスと言う意味では、どちらかと言えば Office 365 に近いと理解いただくと良いかと思います。
以降では Azure と DevOps で区別しておいた方が良い点、と言うかありがちな勘違いをいくつかご紹介していきます。

なお、本記事ではクラウドサービスとして提供される Azure DevOps Service に絞って紹介しています。
インストールベースのサーバー製品である DevOps サーバーをいれるとわけがわからなくなりますので。

## 利用開始

どちらのクラウドサービスも初めて使うときにはサインアップが必要です。

Azure の場合は
[こちら](https://azure.microsoft.com/ja-jp/free/)
のページで「無料で始める」をクリックします。
DevOps の場合は
[こちら](https://azure.microsoft.com/ja-jp/services/devops/)
のページで「無料で始める」をクリックします。



## 管理者

サインアップ（≒利用開始の契約手続き）の流れは若干似ていて、まずは利用者のサインイン（≒本人性の確認）が求められます。
ここではマイクロソフトアカウント、ないしは Azure Active Directory の組織アカウントでサインインします。

Azure の管理者は
[Account Admin](https://docs.microsoft.com/ja-jp/azure/cost-management-billing/manage/account-admin-tasks)
と呼ばれ、支払いの方法（クレジットカードとか）を管理したり、サブスクリプションを作成してその管理者を任命したり、と言う役割を担います。
DevOps の管理者は
[Orgnization Owner](https://docs.microsoft.com/en-us/azure/devops/organizations/accounts/change-organization-ownership)
と呼ばれ、Orgnization 全体に関わる設定を管理したり、Project を作成してその管理者を任命したり、と言う役割を担います。

サインアップに使用したアカウントがその後の利用における管理責任者になりますので重要です（もちろん変更は可能ですが）。

## ユーザー管理

DevOps も Azure も Azure AD を認証基盤としています。
言い換えればユーザー管理は DevOps や Azure の機能ではなく、特定の Azure AD テナントに委任していることになります。
[Azure サブスクリプションが信頼するテナント](https://docs.microsoft.com/ja-jp/azure/active-directory/fundamentals/active-directory-how-subscriptions-associated-directory)
は既定では Account Addmin が所属するホームテナントになります。
[DevOps のテナント設定](https://docs.microsoft.com/ja-jp/azure/devops/organizations/accounts/access-with-azure-ad)
は前述の Orginization Owner が行います。

## 権限制御

Azure や DevOps の管理者は、その認証基盤となる Azure AD テナント上で管理されているユーザーに対して、一定のアクセス権を付与することで各々のサービスにおける利用者を管理するわけです。

Azure では
[RBAC:Role Based Access Control](https://docs.microsoft.com/ja-jp/azure/role-based-access-control/overview)
を使用して、サブスクリプションやその配下にあるリソースグループやリソースに対して、”誰が何をしていいのか” を管理・制御していきます。
DevOps では Orgnization やその配下の Projec、各 Projec 配下の Repos や Boards と言った各種サービスに対する
[Permission](https://docs.microsoft.com/en-us/azure/devops/organizations/security/permissions-access?view=azure-devops)
を設定することで、”誰が何をしていいのか” を管理・制御していきます。

## シングルサインオン

Azure や DevOps が信頼するテナントが同一であり、利用者が双方に対して RBAC および Permision による権限ふよがされている場合には、シングルサインオンで利用できるので便利です。
もちろん別テナントであっても構いませんが、その場合は利用者はアクセスするサービスごとに認証情報を切り替えるか、
[Azure AD B2B](https://docs.microsoft.com/ja-jp/azure/active-directory/b2b/)
の機能を使用することでテナントを横断したシングルサインオンを行います。
特に後者の B2B を利用するパターンは、自信が所属する組織ではない「外部の組織の DevOps Orgnization」にアクセスする際に便利です。

## ライセンス

DevOps にあって Azure にはない概念としてユーザーライセンスがあります。
これは Stake Holder, Basic, Basic+Test Plans, Visual Studio Subscfription の４段階の
[Access Level](https://docs.microsoft.com/en-us/azure/devops/organizations/security/access-levels?view=azure-devops) 
と言う名前で表現されます。
各ユーザーは自分に割り当てられた Access Level の機能で、かつ、Permission で許可された操作しか行うことができません。

## ポータル

利用者が DevOps のポータル
[dev.azure.com](https://dev.azure.com) 
にアクセスするとサインインが求められ、その利用者が Permission を付与された Orgnization や Project にアクセスできます。
Azure のポータル
[portal.azure.com](https://portal.azure.com)
にアクセスするとサインインが求められ、その利用者が RBAC を付与されたサブスクリプションやリソースにアクセスできます。

## コマンドラインツール

ポータルのような GUI だけではなく、コマンドラインツールも用意されています。
Azure の場合は 
[Azure CLI](https://docs.microsoft.com/ja-jp/cli/azure/)
や
[Azure PowerShell](https://docs.microsoft.com/ja-jp/powershell/azure/)
を使用します。
DevOps の場合は前述の
[Azure CLI の Extentision](https://docs.microsoft.com/en-us/azure/devops/cli/?view=azure-devops) 
として実装されています。

## 料金の支払い

Azure の場合、各サブスクリプション内の各種リソースの利用料金がアカウントに集約されますので、
クレジットカードや請求書などの
[支払い方法](https://docs.microsoft.com/ja-jp/azure/cost-management-billing/manage/change-credit-card)
を設定できるのは Account Admin になります。
DevOps では単独で利用料金を支払う手立てがありません。
このため無償枠を超える有償利用をしたい場合には、Orgnization Owner が Orgnization を
[Azure サブスクリプションと紐つけ](https://docs.microsoft.com/ja-jp/azure/devops/organizations/billing/overview?view=azure-devops)
る必要があります。
こうすることで DevOps の有償利用分に関しては Azure の毎月の請求明細の１項目として請求が来ることになります。

逆に言えば、無償枠でおさまる範囲であればこの紐つけは必要ありませんので、DevOps を使うからと言って必ずしも Azure の利用契約が必要になるわけではありません。

## アプリのデプロイ

DevOps で開発したアプリケーションは、当然どこかの実行環境で動作させないと意味がないわけですが、この選択肢の１つが Azure です。
Repos 上で管理されたソースコードを、Pipeline Agent がビルドして（テストして）、その成果物を Azure の API を呼び出してデプロイするわけです。
このパイプラインを構成するのは Azure Pipeline に対して適切な Permission および Access Level を持つユーザーですが、
実際にこの Pipeline が動作して Azure の API を呼び出すときにはユーザーの資格情報を使うことはできません。

Azure Pipeline に限りませんが、このような「Azure を外部のアプリケーション等から無人操作する」ケースでは、
- Azure AD に(ユーザーではなく)[Servic Principal](https://docs.microsoft.com/ja-jp/azure/active-directory/develop/howto-create-service-principal-portal)を作成
- その Service Principal に操作対象となるサブスクリプションやリソース/リソースグループに対して適切な RBAC ロールを割り当てておく
- 外部アプリケーションはその Service Principal のクレデンシャルを使用して Azure AD で認可を受けて Azure の API を操作する
という構成をします。

Azure Pipeline ではこの Service Principal の認証情報を
[Service Connection](https://docs.microsoft.com/en-us/azure/devops/pipelines/library/connect-to-azure?view=azure-devops)
として管理することができます。
この Service Principal は操作対象となる Azure サブスクリプションが信頼するテナント上のオブジェクトである必要がありますが、
これは必ずしも DevOps Orgnization が信頼するテナントと同一である必要はありませんし、前述の支払いで紐つけたサブスクリプションである必要もありません。

