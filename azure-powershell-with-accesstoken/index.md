---
layout: default
title: PowerShell で Azure の REST API 呼び出しをするときの Azure Active Directory の Access Token の取得と使い方
---

## はじめに

そもそもは Azure Container Registry に貯めこんだコンテナイメージの脆弱性スキャン結果を、画面ではなくデータで欲しかっただけなんですが、
[こちら](https://docs.microsoft.com/ja-jp/azure/security-center/defender-for-container-registries-introduction#faq-for-azure-container-registry-image-scanning)
を見るとコマンドがあるわけではなく、REST API を叩けということです。
なるほど、めんどくさい。

こういうときは適切な Access Token を取得して、REST API を呼び出すときに Authorization ヘッダーにセットするスクリプトを書かなければいけないわけです。
何度やっても覚えられないので、そろそろちゃんとメモを残そうと思ってブログにしてみました。
Azure Portal も Azure CLI も Azure PowerShell も、しょせんは REST API のラッパーアプリケーションなので、この方法を知っているか知らないか出来ることに差が出ます。

以降では具体的なやり方を紹介していきたいと思いますが、Azure の API には
[コントロールプレーンとデータプレーン](https://docs.microsoft.com/ja-jp/azure/azure-resource-manager/management/control-plane-and-data-plane)
の２つがあり、その呼び出し方も若干異なってきます。

## コントロールプレーン API の場合

さてもともとのきっかけになった [Sub Assesments REST API](https://docs.microsoft.com/ja-jp/rest/api/securitycenter/subassessments/list)
の URL が https://management.azure.com/ になってるということは、これはコントロールプレーンの API なわけです。
つまり [Connect-AzAccount](https://docs.microsoft.com/en-us/powershell/module/az.accounts/connect-azaccount?view=azps-5.1.0)
で接続したアカウントが、Security Center へのアクセスを許可する RBAC 権限を持ってれば良さそうです。
自分が管理しているサブスクリプションであれば必要な権限は持ってるはずなので、`Connect-AzAccount` で素直に自分のユーザーでログインしてしまえば良いことになります。
そのあとは API を呼び出すコードなんですが、`Invoke-RestMethod` の引数とかを調べていたら、
最近は [Invoke-AzRestMethod](https://docs.microsoft.com/en-us/powershell/module/az.accounts/invoke-azrestmethod?view=azps-5.1.0)
なんてものがあったんですねえ。
こちらを使えば認証情報を自動的に使ってくれるので非常に簡単にすみそうです。
（３世代前の 4.8.0 の時点で存在したみたいなので全然最近ではない）

```powershell
# まずはログイン
Connect-AzAccount
# サブスクリプション ID を指定して
$subscriptionid = "your-subscription-guid-here"
# ARM API を呼び出す際のパスを指定して
$path = "/subscriptions/${subscriptionid}/providers/Microsoft.Security/subAssessments?api-version=2019-01-01-preview"
# GETで呼び出し
$response = Invoke-AzRestMethod -Method Get -Path $path

# 帰ってきた JSON から必要なデータを取り出す
$subAssesments = ($response.Content | ConvertFrom-Json).value
$subAssesments | foreach { $_.properties.displayName }

GNU Bash Privilege Escalation Vulnerability for Debian (Zero Day)
Debian Security Update for libidn2 (DSA 4613-1)
Debian Security Update for php7.0 (DSA 4403-1)
Debian Security Update for apache2 (DSA 4422-1)
Debian Security Update for systemd (DSA 4428-1)
Debian Security Update for libpng1.6 (DSA 4435-1)
Debian Security Update for systemd
...
# ひっかかり過ぎてたので以下省略

```

## データプレーン API の場合

`Invoke-AzRestMethod` のドキュメントに `Azure resource management endpoint only` ある通り、
これは https://management.azure.com/ でホストされてる REST API 専用です。
データプレーンの API を呼び出したいときはどうすればいいんでしょうか。
この時点で最初の目的からは脱線しているのですが、最近は
[Get-AzAccessToken](https://docs.microsoft.com/en-us/powershell/module/az.accounts/get-azaccesstoken?view=azps-5.1.0)
なんていう素敵なコマンドレットもあるんですね。
ちなみにこちらは November 2020 に追加されたものらしいので、まさにこのドキュメントを書いている今月リリースだったみたいです。

さてまずはそのまま `Get-AzAccessToken` して取得できるトークンの内容を確認してみましょう。
下記では PowerShell でトークンの中身を確認していますが、[jwt.ms](https://jwt.ms) などのトークンデコードツールを使用したほうが簡単です。

```powershell
# まずはログイン
Connect-AzAccount
# 既定のトークンを取得
$token = (Get-AzAccessToken).Token
# JWT トークンが帰ってくるので、ピリオド区切りの第２要素を Base64 でデコードして JSON を読み取る
$bytes = [System.Convert]::FromBase64String( $token.Split('.')[1] )
$craim = [System.Text.Encoding]::Default.GetString($bytes) | ConvertFrom-Json

# トークンのオーディエンスを確認
$craim.aud

https://management.core.windows.net/
```

ということで ARM 向けのトークンが取れましたが、これを使うのであれば `Invoke-AzRestMethod` を使ったほうが楽ちんです。
`Get-AzAccessToken` が素敵なのはリソースの URL を指定できるので、
コントロールプレーンたる ARM だけではなく、データプレーン（サービスレベル）の API 向けのトークンも取得できるわけです。

ちょうど Azure Batch を触っていたところだったので
[Azure Batch サービス REST API ](https://docs.microsoft.com/en-us/rest/api/batchservice/)
を叩いてみましょう。

```powershell
# まずはログイン
Connect-AzAccount
# Azure Batch 用のトークンを取得
$token = (Get-AzAccessToken -Resource 'https://batch.core.windows.net/').Token
# JWT トークンが帰ってくるので、ピリオド区切りの第２要素を Base64 でデコードして JSON を読み取る
$bytes = [System.Convert]::FromBase64String( $token.Split('.')[1] )
$craim = [System.Text.Encoding]::Default.GetString($bytes) | ConvertFrom-Json

# トークンのオーディエンスを確認
$craim.aud

https://batch.core.windows.net/
```

ということでトークンが取れたので、これをつかって 
[Pool List](https://docs.microsoft.com/en-us/rest/api/batchservice/pool/list) API を呼び出してみましょう。

```powershell
# Pool の List を取得する API
$url = "https://${account}.${region}.batch.azure.com/pools?api-version=2020-09-01.12.0"
# 取得したトークンから認証ヘッダーを構築
$headers = @{ Authorization = "Bearer $token"}
# API を呼び出す
$pools = (Invoke-RestMethod -Method Get -Uri $url -Headers $header ).value
# 結果の表示
$pools | select displayName, vmSize, currentLowPriorityNodes, currentDedicatedNodes

displayName vmSize          currentLowPriorityNodes currentDedicatedNodes
----------- ------          ----------------------- ---------------------
pool0       standard_d8d_v4                       8                     0
```

# まとめ

REST API 呼び出しもだいぶ簡単にはなりましたが、敷居はやっぱり若干高いですし手間もかかります。
まずは Azure PowerShell や Azure CLI に機能が搭載されていないかを確認しましょう。
そのうえでやはりスクリプトからの REST API コールが必要な場合、以下のポイントを確認しましょう。


### コントロールプレーンの API の場合

- [Docs](https://docs.microsoft.com/en-us/rest/api/azure/)で仕様を確認する
    - 実際に API を呼び出す際の URL が https://management.azure.com/ となっているはず
    - HTTP メソッドやパラメータ、戻りのデータなどを確認
- 認証に使用するクレデンシャルを決定する
    - この資料で紹介したようにユーザーログインを使用するのか（対話的に操作する場合）
    - [こちらの記事](../azure-powershell-automation)のようにマネージド ID やサービスプリンシパルを使用するのか
- アクセス権限の付与
    - 認証に使用するクレデンシャルに対して適切な RBAC 権限が付与されているかを確認
- スクリプトの実装
    1. `Connect-AzAccount` でログイン
    1. `Invoke-AzRestMethod` を呼び出す

### データプレーンの API の場合

- [Docs](https://docs.microsoft.com/en-us/rest/api/azure/)で仕様を確認する
    - 実際に API を呼び出す際の URL が対象のリソース名などを含んだ固有の URL になっているはず
    - HTTP メソッドやパラメータ、戻りのデータなどを確認
    - Azure AD 認証に対応しているかを確認し、トークン取得用のリソースエンドポイント URL を控えておく
- 認証に使用するクレデンシャルを決定する
    - この資料で紹介したようにユーザーログインを使用するのか（対話的に操作する場合）
    - [こちらの記事](../azure-powershell-automation)のようにマネージド ID やサービスプリンシパルを使用するのか
- アクセス権限の付与
    - 認証に使用するクレデンシャルに対して適切な RBAC 権限が付与されているかを確認
- スクリプトの実装
    1. `Connect-AzAccount` でログイン
    1. `Get-AzAccessToken` アクセス対象リソース用のトークンを取得
    1. `Invoke-RestMethod` の Authorizaiton ヘッダーにトークンを付与して呼び出す

