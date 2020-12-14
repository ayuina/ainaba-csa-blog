---
layout: default
title: Azure AD サービスプリンシパルを使用したログインに使用する証明書について
---

## はじめに

最近は [Managed ID](https://docs.microsoft.com/ja-jp/azure/active-directory/managed-identities-azure-resources/overview) が充実してきたのでとっても便利なのですが、
Azure AD 認証が必要なアプリケーションが必ずしも Azure 上で動作するとも限りませんので、相変わらずサービスプリンシパルを使用したサインインも必要なわけです。
サービスプリンシパルでサインインするということは、そのアプリケーションは証明書かクライアントシークレットを保有している必要があります。
この証明書の発行方法や利用方法について微妙に手こずったので整理してみます。

Azure PowerShell や Azure CLI でサービスプリンシパルを作り証明書を使用してサインインする方法については下記をご参照いただければと思いますが、
本記事の執筆の切っ掛けとなったのはこの中で出てくる証明書のフォーマットです。

- [Create an Azure service principal with Azure PowerShell](https://docs.microsoft.com/ja-jp/powershell/azure/create-azure-service-principal-azureps)
- [Sign in with Azure PowerShell](https://docs.microsoft.com/ja-jp/powershell/azure/authenticate-azureps)
- [Create an Azure service principal with the Azure CLI](https://docs.microsoft.com/ja-jp/cli/azure/create-an-azure-service-principal-azure-cli)
- [Sign in with Azure CLI](https://docs.microsoft.com/en-us/cli/azure/authenticate-azure-cli)

まず Azure PowerShell の場合は証明書を拇印(Thumbprint)で指定します。
これは Windows の証明書ストアに秘密鍵を持った証明書がインストールされていることを前提としています。

```powershell
Connect-AzAccount -ServicePrincipal -ApplicationId $APP_ID -Tenant $TENANT_ID -CertificateThumbprint <thumbprint>
```

次に Azure CLI の場合ですが、こちらの場合はシンプルに証明書ファイルに対するパスを指定します。
ただしこの証明書は PEM という形式であり秘密鍵が含まれている必要があります。

```bash
az login --service-principal --username $APP_ID --tenant $TENANT_ID --password $pathToCertFile
```

つまり同じサービスプリンシパルを使用する場合であっても、環境によって使用できる証明書の格納方式や利用できるフォーマットが異なるわけです。
これが切っ掛けでいろいろ調べてみましたが、 Windows と Linux で扱う証明書が異なるという話は昔からあった話なんですね・・・。

## Windows 証明書ストアと Azure PowerShell での利用

Windows 端末で作業されている方は `ファイル名を指定して実行` で `certmgr.msc` を実行するか、
スタートメニューで `certification` を検索して `ユーザー証明書の管理` を選択して、証明書を確認してみましょう。
Azure PowerShell の `Connect-AzAccount -CertificateThumbprint` で指定した拇印に一致する証明書が自動的に選択されていることになります。

![windows certificate](./images/windows-certificate.png)

## 証明書のエクスポートと Azure CLI での利用

では、これを Azure CLI で使用したい場合はどうでしょう。
Azure CLI の場合は証明書ファイルのパスを明示してやる必要がありますので、証明書をエクスポートしてやります。
証明書のエクスポートウィザードでのポイントは以下の 3 点です。

- 秘密キーをエクスポートすること（ 登録している公開キーの対になるもの）
- PKCS #12 形式でエクスポートすること（秘密キーを含められるフォーマットはこれだけ）
- パスワードを指定すること

![export certificate](./images/export-pfx.png)

エクスポートした PFX ファイルを利用して試しに `az login` してみると、証明書が正しくないと、PEM ファイルを使えと怒られます。

```bash
$ az login --service-principal --username $APP_ID --tenant $TENANT_ID --password ./exported-certificate.pfx

ValidationError: Invalid certificate, please use a valid PEM file.
```

というわけで、この PFX 形式のファイルを PEM 形式に変換してみましょう。
証明書の変換には OpenSSL を使用するのが定番みたいですね。
下記のスクリプト内で `$PFXPASS` で指定しているファイルは、エクスポート時に指定したパスワードを記載したテキストファイルです。

```bash
PFXFILE=./exported-certificate.pfx
PFXPASS=./password.txt
PEMFILE=./converted-certificate.pem

openssl pkcs12 -in ${PFXFILE} -password file:${PFXPASS} -nocerts -nodes | openssl pkcs8 -nocrypt >> ${PEMFILE}
openssl pkcs12 -in ${PFXFILE} -password file:${PFXPASS} -clcerts -nokeys | openssl x509 >> ${PEMFILE}
```

出力した PEM 形式のファイルをテキストエディタで開いてみると、以下のようなフォーマットのテキストファイルになっていることが分かります。

```pem
-----BEGIN PRIVATE KEY-----
Base 64 でエンコードされた秘密鍵
-----END PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
Base 64 でエンコードされた証明書
-----END CERTIFICATE-----
```

さてそれでは、この証明書を使って `az login` してみましょう。
以下のような結果が返ってくれば成功です。

```bash
az login --service-principal --allow-no-subscriptions --username $APP_ID --tenant $TENANT_ID --password ./converted-certificate.pem
[
  {
    "cloudName": "AzureCloud",
    "id": "guid-of-tenantid",
    "isDefault": true,
    "name": "N/A(tenant level account)",
    "state": "Enabled",
    "tenantId": "guid-of-tenantid",
    "user": {
      "name": "guid-of-application-id",
      "type": "servicePrincipal"
    }
  }
]
```

ここでは `--allow-no-subscriptions` オプションを指定していますが、これは純粋に AAD ログインに成功するか否かを検証するためです。
Azure RBAC のアクセス権を全く付与されていないサービスプリンシパルで、このオプション抜きでサインインすると下記のようなエラーが帰ってきます。

```
ValidationError: No subscriptions found for application-name-or-guid.
```

そもそも Azure 操作をするための Azure CLI なので、アクセス権を持つサブスクリプションが１つも無い場合にはエラーと判定されますよね。
ですがここでは、サブスクリプションの有無は問題ではないので `--allow-no-subscriptions` としています。

## 別解 : Azure CLI 用に別の証明書を発行する

[与えられた PFX 形式の証明書でどうにかやりくりしなければならない事情](#補足)がある場合には、前述のような証明書変換アプローチは有効でしょう。
ただそもそも Azure AD のアプリケーションに登録する証明書やシークレットは 1 つである必要はありません。
いま持っている証明書が Azure CLI で使用できないならば、新規に発行してしまえば良い、という考え方もあるわけです。
その証明書発行と Azure AD への登録権限があり、証明書の運用が少し増えることを受け入れられるのならば。

![azure ad application secrets and certificates](./images/aad-secret-certificate.png)

### Azure CLI で証明書を発行する

証明書を発行する方法はいくつかありますが、`Azure CLI` を使用するのが最も簡単だと思います。
`az ad sp credential reset` を使用してサービスプリンシパルのシークレットや証明書を変更することができるのですが、
`--create-cert` オプションを付与することで自己署名証明書を発行することができます。
その際に `--append` を指定しないと既存の証明書を上書きしてしまうのでご注意ください。
コマンドオプションの詳細は [こちら](https://docs.microsoft.com/en-us/cli/azure/ad/sp/credential?view=azure-cli-latest#az_ad_sp_credential_reset) をご参照ください。

```bash
# サービスプリンシパルの設定を変更するので、開発に使用しているユーザーアカウントでサインインしなおす
az login

# 既存のサービスプリンシパルに対して証明書を作成して追加する
az ad sp credential reset --append --create-cert --name $APP_ID
{
  "appId": "guid-of-application",
  "fileWithCertAndPrivateKey": "C:\\Users\\username\\tempfilename.pem",
  "name": "name-of-application",
  "password": null,
  "tenant": "guid-of-registered-tenant"
}
```

実行結果の `fileWithCertAndPrivateKey` に記載されたパスに証明書ファイルが出力されているはずです。
これを適当な場所にコピーしてログインしてみましょう。
ちなみに私の環境では証明書を生成してから実際にログインできるようになるまで数分かかっていました。
エラーが出てしまった場合には少し間をおいてみてください。

```bash
az login --service-principal --allow-no-subscriptions -u $APP_ID --tenant $TENANT_ID -p ./created.pem
[
  {
    "cloudName": "AzureCloud",
    "id": "guid-of-tenantid",
    "isDefault": true,
    "name": "N/A(tenant level account)",
    "state": "Enabled",
    "tenantId": "guid-of-tenantid",
    "user": {
      "name": "guid-of-application-id",
      "type": "servicePrincipal"
    }
  }
]
```

余談ですが、この `--create-cert` オプションはサービスプリンシパルの生成時にも利用できます。
```bash
az ad sp create-for-rbac --skip-assignment -n $APP_NAME --create-cert
```

さらに余談ですが、`--keyvault` オプションを指定するとローカルに証明書を生成することなく Key Vault でキーを管理させることができます。
この証明書は Key Vault からダウンロードできますが、`パスワードなしのPFX形式` になるようです。
Key Vault を使って証明書を管理したいtが `PEM` 形式が必要な場合は、後述の手順を利用してください。
```bash
az ad sp create-for-rbac --skip-assignment -n $APP_NAME --create-cert --keyvault $KEYVAULT_NAME --cert $CERTIFICATE_NAME
```

### Azure Key Vault で証明書を発行する

[Azure Key Vault](https://docs.microsoft.com/ja-jp/azure/key-vault/certificates/about-certificates) で自己署名証明書を発行することが出来ます。
Key Vault で自己署名証明書を `生成` する際に PEM 形式を指定しておきます。
生成が完了したら公開キー部分のみの証明書を `cer` 形式で、秘密キーも含む証明書を `pem` 形式でダウンロードすることが出来ます。
Azure Portal でサインインしたい Azure AD アプリケーションの証明書として `cer` 証明書をアップロードしておき、実際にサインインしたい環境には `pem` 証明書を配置して利用します。

![Create certification using key vault](./images/keyvault-create-cert.png)

なお余談ですが前述の`az ad sp create-for-rbac` や `az ad sp credential reset` 等のコマンドで `--create-cert` オプションを指定しない場合、
`--keyvault` や `--cert` オプションは Key Vault で管理された証明書を使用する、という意味合いになります。
このため既存のサービスプリンシパルに Key Vault で管理している証明書（Key Vault で発行したものでなくともよい）を紐付けたい場合には下記のコマンドが利用できます。
```bash
az ad sp credential reset --name $APP_NAME --append --create-cert --keyvault $KEYVAULT_NAME --cert $CERTIFICATE_NAME
```

## まとめ

ここまで自己署名証明書の生成と管理についてつらつらと記載してみましたが一応まとめです。

|最終利用形式|証明書生成方法|インストール|備考|
|---|---|---|---|
|PKCS #12 (PFX)|Azure CLI でサービスプリンシパル作成・更新と同時に証明書を生成しつつ Key Vault に保存する| Key Vault から PFX 形式でダウンロードして実行環境の Windows 証明書ストアにインストール|記事内の余談を参照|
|PKCS #12 (PFX)|Azure Key Vault で PFX 形式で作成| Key Vault から CER 形式でダウンロードしてAzure AD アプリケーションに登録、PFX 形式でダウンロードして実行環境の Windows 証明書ストアにインストール|本記事では未紹介|
|PKCS #12 (PFX)|PowerShell コマンド New-SelfSignedCertificate で生成|証明書ストアから公開キーをエクスポートして Azure AD アプリケーションに登録|[参考情報](https://qiita.com/sat0tabe/items/e6b0a2913eb2cbddb4fd)|
|PKCS #12 (PFX)|Windows SDK に含まれる makecert と pvk2pfx ツールで生成|公開キー部分をAzure AD アプリケーションに登録、PFXファイルを生成して証明書ストアにインストール|[参考情報](https://docs.microsoft.com/ja-jp/azure/batch/credential-access-key-vault)|
|PEM|PFX パターンで生成 | Windows 証明書ストアから秘密キー付きでエクスポートし、OpenSSL で PEM 形式に変換|解説済み|
|PEM|Azure CLI でサービスプリンシパル作成・更新と同時に証明書を生成しつつローカルに保存する|ローカルディレクトリに生成された PEM ファイルを実行環境にコピー|解説済み|
|PEM|Azure Key Vault で PEM 形式で作成| Key Vault から CER 形式でダウンロードしてAzure AD アプリケーションに登録、PEM 形式でダウンロードして実行環境の ローカルディレクトリに配置|解説済み|


### 補足

さて本記事はどういう用途に役立つかというと Azure Batch で証明書を管理し、それを Linux プールで使うケースです。
[公式ドキュメント](https://docs.microsoft.com/ja-jp/azure/batch/batch-certificates) や
[`az batch certificate create`](https://docs.microsoft.com/ja-jp/cli/azure/batch/certificate) のヘルプに記載があるように、
Batch アカウントが管理できる証明書形式で秘密キーも管理できるのは `PFX` だけで `PEM` には対応していません。
`PFX` のままだと Linux 環境では使いにくいので、実行時に OpenSSL を使用して `PEM` に変換するという方式に行きつきました。

Azure Batch が Managed ID に対応してくれれば不要なワークアラウンドなのですが、ノウハウとしては Batch 以外でも有用そうなので整理してみました。
例えば[こちら](https://docs.microsoft.com/ja-jp/azure/container-registry/container-registry-auth-service-principal) にも以下のような記載があるので、
たまによくあるシチュエーションなのでしょう。

> 証明書と共にサービス プリンシパルを使用して Azure CLI にサインインするには、証明書を PEM 形式にして、秘密キーを含める必要があります。 
> 証明書が必要な形式ではない場合は、openssl などのツールを使用して変換します。

参考になれば幸いです。