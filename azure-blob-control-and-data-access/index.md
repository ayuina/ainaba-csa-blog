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
	- ストレージアカウントを作成・削除する、ストレージキーの取得・更新、ネットワーク制御設定といった管理操作を行う
	- 多くの場合 Azure 環境の構築時に構成する内容で、アプリケーションからはあまり操作しないことが多い
	- クライアントがアクセスする API Endpoint としては Azure Resource Manager 全体で共通(https://management.azure.com) 
	- 各サービスはリソースプロバイダと呼ばれる ARM に対する拡張機能のような形で提供されている
	- ストレージリソースプロバイダの操作に関しては [API Reference](https://docs.microsoft.com/en-us/rest/api/storagerp/) を参照
	- 認証方式とアクセス制御には AAD : Azure Active Directory と RBAC : Role Based Access Control を使用する
- データプレーン
	- Blob コンテナー内の Blob の作成・読み取り・更新・削除などのデータ操作を行う
	- データ操作が必要なアプリケーションでは、多くの場合データプレーンの操作が主体となる
	- 実際のリソースにつけられた名前を元にした FQDN ベースの API Endpoint を個々にもっている
	- Blob サービスの操作に関しては [API Reference](https://docs.microsoft.com/ja-jp/rest/api/storageservices/blob-service-rest-api) を参照
	- 認証方式とアクセス制御には AAD と RBAC 以外に、共有キー（ストレージアカウントキー）、SAS : Shared Access Signature を使用することができる

つまり Azure 環境の構築時にストレージアカウントを作成する、あるいはそのアカウントを保守する際には、AAD 認証しか使えません。
これは Azure Portal、Azure PowerShell、Azure CLI といった代表的なツールを使うときに、最初に必ず AAD 認証が要求されることからもわかります。
一方で、データプレーンの操作に対しては AAD 認証に加えて共有キーや SAS を利用した認証とアクセス制御が可能です。
このためストレージアカウントの Blob 機能を利用したいアプリケーションには 3 つの選択肢が提供されているわけですので、
要件や制約に合わせて適切なものを選択、あるいは組み合わせる必要があるわけです。

## Azure AD 認証 + RBAC 方式

まず AAD でユーザーないしはアプリケーションを認証し、そこで得られたアクセストークンを REST API に提示、操作可否を RBAC で制御する方式になります。
なおココではコントロールプレーンとデータプレーンの両方に対して AAD 認証を元にしたアクセス制御をしている図にしていますが、これは必ずしもセットである必要はありません。
データプレーン操作には後述の共有キーや SAS を用いることも可能です。

![control-and-data-access-with-aad](./images/control-and-data-access-with-aad.png)

なお、コントロールプレーンとデータプレーンで同じ方式を使っていますので、呼び出しのコードは似通っていますが、実際にはいろいろと差異が発生します。

- コントロールプレーン
	- 呼び出す際のエンドポイントとして ```https://management.azure.com``` を使用する（ARM 全てで共通、ストレージはリソースプロバイダーの１つ）
	- アクセストークン必要時に Resource Id として ```https://management.azure.com/``` を指定する
	- アクセス時に必要な代表的な RBAC ロール（所有者、閲覧者、共同作成者、など）
- データプレーン
	- 呼び出す際のエンドポイントとして ```https://account.blob.core.windows.net``` を使用する（各ストレージアカウント固有）
	- アクセストークン必要時に Resource Id として ```https://storage.azure.com/``` ないしは ```https://account.blob.core.windows.net``` を指定する
	- アクセス時に必要な代表的な RBAC ロール（ストレージ Blob データ所有者、ストレージ Blob データ閲覧者、ストレージ Blob データ共同作成者、など）

また勘違いされがちですが、ストレージアカウントを作成したり管理の権限を持っている所有者や共同作成者であっても、データプレーンに対するアクセス権を持っているわけではないので、そのままではデータアクセスができません。
同じユーザー（ないしはアプリケーション）からコントロールプレーンとデータプレーンの操作を両方行いたい場合には、下図のようにそれぞれのロールを割り当ててやる必要があります。

![rbac-for-data-contributor](./images/rbac-for-data-contributor.png)

### ストレージアカウントや Blob に対する RBAC アクセス制御

もう少し RBAC 部分を深堀すると、上記で VM の Managed ID に割り当てられている共同作成者ロールの定義は下記のようになっています（抜粋）。
```actions``` として広範囲な操作(```*```)が許可されている反面、```dataActions``` は空っぽです。

```json
{
  "roleName": "Contributor",
  "description": "Grants full access to manage all resources, but does not allow you to assign roles in Azure RBAC, manage assignments in Azure Blueprints, or share image galleries.",
  "permissions": [
    {
      "actions": [
        "*"
      ],
      "notActions": [
        "Microsoft.Authorization/*/Delete",
        "Microsoft.Authorization/*/Write",
        "Microsoft.Authorization/elevateAccess/Action",
        "Microsoft.Blueprint/blueprintAssignments/write",
        "Microsoft.Blueprint/blueprintAssignments/delete",
        "Microsoft.Compute/galleries/share/action"
      ],
      "dataActions": [],
      "notDataActions": []
    }
  ],
}
```

一方でストレージ Blob データ共同作成者のロール定義は下記のようになります（抜粋）。
```actions``` で許可されている操作はコンテナの作成削除といった一部のみで、```dataActions```には blob に対する read / write などが許可されていることが分かります。

```json
{
  "roleName": "Storage Blob Data Contributor",
  "description": "Allows for read, write and delete access to Azure Storage blob containers and data",
  "permissions": [
    {
      "actions": [
        "Microsoft.Storage/storageAccounts/blobServices/containers/delete",
        "Microsoft.Storage/storageAccounts/blobServices/containers/read",
        "Microsoft.Storage/storageAccounts/blobServices/containers/write",
        "Microsoft.Storage/storageAccounts/blobServices/generateUserDelegationKey/action"
      ],
      "notActions": [],
      "dataActions": [
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/delete",
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/read",
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/write",
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/move/action",
        "Microsoft.Storage/storageAccounts/blobServices/containers/blobs/add/action"
      ],
      "notDataActions": []
    }
  ],
 ```

この ```actions``` が ARM （コントロールプレーン）に対して許可される操作、```dataActions``` がデータプレーンに対して許可される操作を表します。
データプレーン操作である Blob の読み書き等に必要なのはこの ```dataActions``` なので、
共同作成者や所有者であってもこれらの ```dataActions``` が設定されてないためそのままではデータアクセスが出来ないわけです。


## ストレージアカウントキー認証方式

ストレージアカウントのキーはストレージアカウントが作成されて初めて払い出されます。
つまり少なくともストレージアカウントを作成し、共有キーを払い出す操作に関しては Azure AD 認証を使用する必要があります。
このことからも「データプレーンの操作しか出来なさそうだな」ということが分かるかと思います。

なおストレージアカウントキー方式は最も古くから提供されている認証方式なのですが、現在では積極的な利用をあまりおススメしていません。
このキーを知っていればストレージアカウントのデータプレーンに対する任意の操作が可能ですので、権限が強すぎるというのが問題です。
アプリケーション設計時に認証方式に迷った場合は、原則として前述の AAD 認証か後述の SAS をご検討ください。

![access-with-shared-key](./images/access-with-shared-key.png)

何らかの事情で共有キー認証方式を選ばざるを得ない場合には、キーの管理と漏洩対策には十分ご注意ください。

## SAS 方式

SAS : Shared Access Signature 方式も事前にクライアントにキー（のようなもの）を共有する方式なのですが、
Blob やコンテナといった限定的なスコープに対して、Read のみとか、IP アドレス制限、時間制限 といったきめ細かなアクセス制御が可能です。
AAD 認証を使ったデータアクセスが難しいなどの制約がある場合は、ストレージアカウントキーではなくこちらの SAS キーを使用すると良いでしょう。

![access-with-sas-key](./images/access-with-sas-key.png)

SAS 方式での認証とアクセス制御を使いたいときには、まず SAS トークンの発行が必要なわけですが、その SAS トークンの発行にはストレージアカウントキーや AAD 認証が必要になるわけです。
発行された SAS トークンを Blob の URL のクエリ文字列として追加して Blob ストレージにリクエストしてやれば、
そこに記載されたアクセス許可にしたがって Blob 操作が可能なわけです。

例えば下記のような Blob に対して発行された SAS トークンと URL 見てみましょう。

|||
|---|---|
|Blob URL|https://accountName.blob.core.windows.net/containerName/blobName|
|Blob SAS Token|sp=r&st=2021-06-08T06:14:55Z&se=2021-06-15T14:14:55Z&sip=xxx.yyy.zzz.www&spr=https&sv=2020-02-10&sr=b&sig=yCJ5CD%2BpedfYFz%2BQyr2idaDc3gQLdk5dgY2BcSPW380%3D|
|Blob SAS URL|https://ainabahogestr.blob.core.windows.net/hoge/myblockblob?sp=r&st=2021-06-08T06:14:55Z&se=2021-06-15T14:14:55Z&sip=153.203.101.155&spr=https&sv=2020-02-10&sr=b&sig=yCJ5CD%2BpedfYFz%2BQyr2idaDc3gQLdk5dgY2BcSPW380%3D|

前述の通りSAS トークンはクエリ文字列形式になりますので、SAS トークンを ```&``` で分解していけばその内容が読み取れます。

|Key|Value|意味|
|---|---|---|
|sp|r|このトークンに付与された権限 (Permission) を表し、r は読み取り (Read) なので書き込みは出来ない|
|st|2021-06-08T06:14:55Z|このトークンの有効期間の開始日時 (Start Time) を表し、この日時より前にはアクセスできない|
|se|2021-06-15T14:14:55Z|このトークンの有効期間の終了日時 (Expiry Time) を表しこの日時より後にはアクセスできない|
|sip|xxx.yyy.zzz.www|このトークンを利用できる IP アドレスレンジ、この IP アドレス以外からはアクセスできない|
|spr|https|許可されるプロトコル (Protocol)、HTTPS のｍにが許可されているため、HTTP ではアクセス出来ない|
|sv|2020-02-10|ストレージサービスのバージョン (version)、署名を作成するときに使われたバージョンで、署名の内容をチェックする際のロジックをすり合わせる |
|sr|b|このトークンが発行された対象のリソース、ここでは Blob に対して発行されたものであることがわかる（コンテナアクセスなどは出来ない）|
|sig|yCJ5CD%2BpedfYFz%2BQyr2idaDc3gQLdk5dgY2BcSPW380%3D|上記のアクセス許可に対する署名(Signature)、発行時から上記の内容が改ざんされていないことを保障する|

アクセス許可の内容が URL に記載されているため、書き換えてしまえばなんでもアリなように一瞬思ってしまいますが、ちゃんと署名が付いています。
ストレージアカウント側はこの署名をチェックすることで、この署名の発行者が共有キーを保有しているないしは RBAC などで権限が許可されていることを確認できます。
共有キーを使用して署名された SAS をサービス SAS や アカウント SAS 、AAD 認証されたユーザー固有のキーを用いて署名されたものを ユーザー委任 SAS と呼びます。
SAS の種類や制限などの詳細は[こちら](https://docs.microsoft.com/ja-jp/azure/storage/common/storage-sas-overview)。

### 注意事項

SAS はストレージアカウントキーと同様に事前にキーを共有する方式です。
つまり SAS を知っていれば誰でも同じ操作が可能であることを意味しますので、アクセス元が誰か（どのアプリか）を確認することは出来ません。
ストレージアカウントキーに





## Sample Code

以下では認証方式の区別のために PowerShell から生の REST API を書くサンプルを紹介しています。
が、実際にはこんないばらの道を歩く必要はなく、Azure PowerShell や Azure CLI といったコマンドラインツール、
ないしは各言語向けに提供されている SDK を利用してください。

### コントロールプレーンのアクセス（Azure AD 認証）

まず API アクセスする主体となるユーザーないしはアプリケーションを特定し、その主体を表す Azure Active Directory 上のプリンシパルを作成します。
これらのプリンシパルに対して RBAC ロールを割り当てます。

例えば下記では仮想マシンの Managed ID に対して、とあるリソースグループに対する **共同作成者** ロールを割り当てています。
以降ではこの Managed ID を使用するアプリケーションがコントロールプレーンの API を操作して、ストレージアカウントを作成する例を紹介します。

![rbac-for-contributor](./images/rbac-for-contributor.png)

では次に、ARM を介してストレージリソースプロバイダーにアクセスするためのアクセストークンを取得する必要があります。
その際「接続先のターゲットリソース」は Azure Resource Manager になりますので、リソースとして ```https://management.azure.com/``` を指定します。
詳細は[こちら](https://docs.microsoft.com/ja-jp/rest/api/azure/#create-the-request)。

先ほどの例で言うと、仮想マシン内部で動作するアプリケーションであれば Managed ID を利用して、アクセストークンを取得できます。
例えば以下は PowerShell を使用したサンプルコードになります。

```powershell
# Get Access Token from Managed ID
$resourceURI = "https://management.azure.com/"
$tokenAuthURI = "http://169.254.169.254/metadata/identity/oauth2/token?resource=$resourceURI&api-version=2019-08-01"
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"Metadata"="True"} -Uri $tokenAuthURI
$accessToken = $tokenResponse.access_token
```

次に得られたアクセストークン付きの HTTPS Request を ARM の API エンドポイントに送信すればよいわけです。
今回のケースではストレージアカウントリソースプロバイダーの操作になるように、URL を組み立ててやります。
詳細は[こちら](https://docs.microsoft.com/en-us/rest/api/storagerp/)。

先ほど取得したアクセストークンを用いてストレージアカウントを作成してみましょう。

```powershell
# Create Storage Account via Control Plane api
# https://docs.microsoft.com/en-us/rest/api/storagerp/storage-sample-create-account

$subscriptionId = "your-subscription-guid-goes-here"
$resourceGroupName = "test-deploy-rg"
$storageProvider = "Microsoft.Storage"
$storageAccountName = "your-storage-account-name"
$restEndpoint = "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/${storageProvider}/storageAccounts/${storageAccountName}?api-version=2018-02-01"

$header = @{
    "Authorization" = "Bearer ${accessToken}";
	"Content-Type" = "application/json"
}
$body = @{
	"sku" = @{"name" = "Standard_LRS"};
	"kind" = "StorageV2";
	"location" = "eastus2"
} | ConvertTo-Json

$res = Invoke-WebRequest -UseBasicParsing -Method Put -Uri $restEndpoint  -Headers $header -Body $body
Write-Output $res.Content

```

引き続きコントロールプレーンの操作で Blob コンテナを作成しましょう。

```powershell
# Create Blob Container via Control plane api
# https://docs.microsoft.com/en-us/rest/api/storagerp/blob-containers/create

$containerName = "hoge"
$restEndpoint = "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/${storageProvider}/storageAccounts/${storageAccountName}/blobServices/default/containers/${containerName}?api-version=2021-04-01"

$header = @{
    "Authorization" = "Bearer ${accessToken}";
	"Content-Type" = "application/json"
}
$body = @{} | ConvertTo-Json
$res = Invoke-WebRequest -UseBasicParsing -Method Put -Uri $restEndpoint  -Headers $header -Body $body
Write-Output $res.Content

```

引き続きコントロールプレーンの操作でストレージアカウントの共有キーも取得しておきましょう。
これは後で使用します。

```powershell
# Get Shared Key via Control Plane api
# https://docs.microsoft.com/en-us/rest/api/storagerp/storage-accounts/list-keys
$restEndpoint = "https://management.azure.com/subscriptions/${subscriptionId}/resourceGroups/${resourceGroupName}/providers/${storageProvider}/storageAccounts/${storageAccountName}/listKeys?api-version=2021-04-01"

$header = @{
    "Authorization" = "Bearer ${accessToken}";
}
$body = @{} | ConvertTo-Json
$res = Invoke-WebRequest -UseBasicParsing -Method Post -Uri $restEndpoint  -Headers $header 
Write-Output $res.Content
```

### AAD 認証でデータプレーンにアクセスする

次はデータプレーン用の操作ですので、先ほどとは別の RBAC ロール割り当てが必要になります。

例えば下記では仮想マシンの Managed ID に対して、とあるリソースグループに対する **ストレージ Blob データ共同作成者** ロールを割り当てています。
以降ではこの Managed ID を使用するアプリケーションが、データプレーンの API を操作して Blob の書き込みや読み取りをする例を紹介していきます.


![rbac-for-data-contributor](./images/rbac-for-data-contributor.png)

まずデータプレーン用のアクセストークンを取得する必要があります。
先ほどの例とコードは似ていますが、ターゲットとするリソースＩＤが ARM ではなくストレージサービスになっています。

```powershell
# Get Access Token from Managed ID
$resourceURI = "https://storage.azure.com/"
$tokenAuthURI = "http://169.254.169.254/metadata/identity/oauth2/token?resource=$resourceURI&api-version=2019-08-01"
$tokenResponse = Invoke-RestMethod -Method Get -Headers @{"Metadata"="True"} -Uri $tokenAuthURI
$accessToken = $tokenResponse.access_token
```

次に得られたアクセストークン付きの HTTPS Request を Blob サービスの API エンドポイントに送信すればよいわけです。

```powershell
# Write data to blob service
$blobname = "hoge.txt"
$blobcontent = "hogehogehogehogehogehogehoge"
$restEndpoint = "https://${storageAccountName}.blob.core.windows.net/${containerName}/myblockblob"

$header = @{
    "Authorization" = "Bearer ${accessToken}";
	"x-ms-date" = [System.DateTime]::UtcNow.ToString("R");
	"x-ms-version" = "2019-02-02";
	"x-ms-blob-type" = "BlockBlob"
}

$res = Invoke-WebRequest -UseBasicParsing -Method Put -Uri $restEndpoint -Headers $header -Body $blobcontent
Write-Output $res.Content

```