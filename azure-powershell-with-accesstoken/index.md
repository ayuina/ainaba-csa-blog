---
layout: default
title: PowerShell Azure の REST API 呼び出しをするときの Access Token の取得
---

## はじめに

そもそもは Azure Container Registry に貯めこんだコンテナイメージの脆弱性スキャン結果を、画面ではなくデータで欲しかったんですが、
[こちら](https://docs.microsoft.com/ja-jp/azure/security-center/defender-for-container-registries-introduction#faq-for-azure-container-registry-image-scanning)
を見るとコマンドがあるわけではなく、REST API を叩けということです。
なるほど、めんどくさい。
また Access Token を取得して REST API を呼び出すときに Authorization ヘッダーにセットするスクリプトを書かなければいけないわけですね。
何度やっても覚えられないのでそろそろちゃんとメモを残そうと思いました。

## コントロールプレーン API の場合

さて [Sub Assesments REST API](https://docs.microsoft.com/ja-jp/rest/api/securitycenter/subassessments/list)
の URL が https://management.azure.com/ になってるってことはコントロールプレーンの API なので、
[Connect-AzAccount](https://docs.microsoft.com/en-us/powershell/module/az.accounts/connect-azaccount?view=azps-5.1.0)
で接続したアカウントが、Security Center へのアクセスを許可する RBAC 権限を持ってれば良さそうです。
自分が管理しているサブスクリプションであれば必要な権限は持ってるはずなので、`Connect-AzAccount` で素直に自分のユーザーでログインしてしまえば良いことになります。
そのあとは API を呼び出すコードなんですが、`Invoke-RestMethod` の引数とかを調べていたら、
最近は [Invoke-AzRestMethod](https://docs.microsoft.com/en-us/powershell/module/az.accounts/invoke-azrestmethod?view=azps-5.1.0)
なんてものがあったんですねえ。
こちらを使えば認証情報を自動的に使ってくれるので非常に簡単にすみそうです。
（３世代前の 4.8.0 の時点で存在したみたいなので全然最近ではない）

```powershell
# まずはログイン
Connect-AzContext
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
と、脱線していたら 
[Get-AzAccessToken](https://docs.microsoft.com/en-us/powershell/module/az.accounts/get-azaccesstoken?view=azps-5.1.0)
なんていう素敵なコマンドレットもあるんですね。
ちなみにこちらは November 2020 に追加されたものらしいので、まさにこのドキュメントを書いている今月リリースだったみたいです。

さてまずはそのまま `Get-AzAccessToken` して取得できるトークンの内容を確認してみましょう。
下記では PowerShell でトークンの中身を確認していますが、[jwt.ms](https://jwt.ms) などのトークンデコードツールを使用したほうが簡単です。

```powershell
# まずは既定のトークンを取得
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

