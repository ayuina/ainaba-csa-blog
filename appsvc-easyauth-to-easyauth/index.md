---
layout: default
title: App Service (Web アプリ) から App Service（Web API） を呼び出す時の EasyAuth とアクセストークン
---

# はじめに

[以前の記事](../appsvc-easyauth-z/)で Easy Auth 認証が有効になった App Service（Web アプリ）で、ユーザーの認可を行う方法を紹介しましたが、
その Web アプリから、別の App Service（Web API）を呼び出す場合、どのように認証を行うのかを紹介します。
内容的には下記のチュートリアルと全く同じ内容なのですが、ちょっとわかりにくいポイントや、そのままでは動かない箇所があり、ちょっと別のやり方も試してみたかったので、備忘録がてら解説します。

- [チュートリアル:Azure App Service でユーザーをエンド ツー エンドで認証および承認する](https://learn.microsoft.com/ja-jp/azure/app-service/tutorial-auth-aad?pivots=platform-windows)

# 全体像

まず全体像です。
App Service にデプロイされているのが Web アプリだろうが Web API だろうが、どちらも App Service ということで、両方とも Easy Auth によって保護することが可能です。
ただ Web アプリの場合は未認証リクエストが自動的に Entra ID にリダイレクトされ、認証すると必要なトークンが取得可能なので良いのですが、API アクセスはそうはいきません。
Web アプリは API アクセスの前にアクセストークンを取得し、API 呼び出しの際に付与する実装をしてあげる必要があります。
今回は Web アプリがユーザーの代理で API にアクセスする [Authorization Code flow](https://learn.microsoft.com/ja-jp/entra/identity-platform/authentication-flows-app-scenarios#web-app-that-signs-in-a-user-and-calls-a-web-api-on-behalf-of-the-user)
というやつです。

![overview](./images/overview.png)

問題はこのトークンの取得方法や各種の設定方法です。
構成としては Entra ID のドキュメントで紹介されている [API を呼び出す Web アプリ](https://learn.microsoft.com/ja-jp/entra/identity-platform/scenario-web-app-call-api-overview) に該当します。
するのですが、こちらを読んでも App Service 関連の設定がよくわかりません。
最初にあげたチュートリアルがまさにこの手続きを紹介しているのですが、これの補足をする内容として読んでください。

# セットアップ

まずは ２ つの App Service に対して Easy Auth を使用して Entra ID で認証を行うように構成します。
この際、既定では App Service に対して 2 つのアプリが登録されます。

![](./images/easyauth-setting.png)

この 4 つのオブジェクトに対して、それぞれ必要な設定を行います。

||Web アプリ（Frontend）|Web API（Backend）|
|---|---|---|
|Entra ID アプリ|② API アクセスの委任　|① API の公開|
|Azure App Service|③ API アクセスのためのトークンの取得|④ アクセス許可|

## ① Entra ID に登録された Backend アプリで API を公開する

まずは Web API に対して、Entra ID に登録されたアプリで API を公開します。
が、ここではアプリ登録した段階で `api://${CLIENT_ID_OF_BACKEND_API}/user_impersonation` というスコープが自動的に作成されているので、これを使うことにしますので、確認だけしておきます。

![publish web api](./images/publish-webapi.png)

## ② Entra ID に登録された Frontend アプリで API アクセスの委任を構成する

次に Web アプリに対して、Entra ID に登録されたアプリで API アクセスの委任を構成します。
この Web アプリはユーザー認証を行なっていますが、既定では「ユーザーのフリをする」ことは許可されていません。
うっかり怪しいアプリを認証してしまっても、ユーザーのフリをしてさまざまな API にアクセスする権限を与えるには、ユーザーの（あるいは管理者の）明確な同意、すなわち __委任__ が必要ということです。
ここで行っているのは実際の委任の許可ではなく、「このアプリは API アクセスの際にユーザーのフリをする必要があるので委任状を書いてくださいね」という設定をしておくことで、実際に認証が行われる際にユーザーの同意を求める設定をしているわけです。
ややこしい。

![](./images/delegate-apiaccess.png)

ちなみにこの設定は必須ではありません。
フロントエンドの Web アプリの認証が行われる際の初回は Web アプリがユーザーのプロファイル情報にアクセスすることを同意する画面が表示されますが、
その際にバックエンドの Web API に対する委任もまとめて同意を求めることができれば、同意の操作が一回で済みます。
後述のように Web アプリのコードではなく App Service 側の設定だけで委任されたアクセストークンを取得することもできますので実装が楽になります。

## ③ Frontend 側の App Service　で Web API　を操作するためのアクセストークンを取得する

さて Azure Portal の画面を眺めていてもわからないのですが、Easy Auth の設定をカスタマイズすることで、ユーザー認証のために Entra ID にリダイレクトする際にまとめて Backend API のアクセストークンを要求することができます。
チュートリアルではコマンドでごにょごにょしてますが、[Azure Resource Explorer](https://resources.azure.com/) で設定を変更するのがわかりやすいでしょう。

Resource Explorer で Frontend 側の App Service を開き、`config/authsettingsV2` 設定の `properties.identityProviders.azureActiveDirectory.login.loginParameters` に下記のように設定を書き換えます。
おそらく最初は scope が `openid profile email` などとなっていると思いますが、これを `openid` とともにバックエンド側 Web API のスコープを追加しておきます。

![](./images/easyauth-loginparam.png)

これいいかげん Azure Portal で設定できるようになるか Azure CLI の普通の（JSON じゃない）コマンドで設定できるようにならないもんでしょうか・・・。

## ④　Backend 側の App Service で Frontend 側のアクセス許可を設定する

こちらの手順は先ほどのチュートリアルにはありません。
が、これがないと認可は通る（401 Unauthorized は解消される）のにも関わらず、アクセスが拒否される(403 Forbidden が発生する)というエラーが出てしまいかなり悩みました。
以前の記事で紹介した「App Service の設定で認可を行う」ための[組み込み認可ポリシー](https://learn.microsoft.com/ja-jp/azure/app-service/configure-authentication-provider-aad?tabs=workforce-tenant#use-a-built-in-authorization-policy) という設定なのですが、これを使用して Backend 側の App Service で Frontend 側のアプリを許可してあげる必要があります。
たしかにドキュメントには以下のような記載がありました。

> これらの組み込みチェックに失敗した要求には、HTTP 403 Forbidden 応答が渡されます。

というわけで、今度は Backend 側の App Service を Resource Explorer で開いて `config/authsettingsV2` 設定の `properties.identityProviders.azureActiveDirectory.validation.defaultAuthorizationPolicy.allowedApplications` の配列に、Frongend 側のアプリの Client ID を追加します。

![](./images/easyauth-authzpolicy.png)

# 動作確認

セットアップが終わったので動作確認です。
真面目にやるなら 2 つの App Service にアプリケーションをデプロイするのですが、~~実装がだるいので~~ まずは設定が正しいか簡易的に確認できた方が良いでしょう。

まず Frontend 側の App Service に In-Private ブラウザでアクセスしてみます。
そうすると未認証なので Entra ID にリダイレクトされるのですが、すぐに認証を通さずに落ち着いて URL 欄をみてみると、API のスコープを要求していることがわかります。

```
https://login.microsoftonline.com/guid-of-tenant-id/oauth2/v2.0/authorize?response_type=code+id_token&redirect_uri=https%3A%2F%2Fayuina-web-frontend-1206.azurewebsites.net%2F.auth%2Flogin%2Faad%2Fcallback&client_id=ca3e9b1b-8a29-46ad-bff8-745de29bd68a&scope=email+profile+openid+api%3A%2F%2F5c428aab-1151-4ffe-bc77-37b53602fd7a%2Fuser_impersonation&response_mode=form_post&nonce=1414d086d6c84cd2985edbe3ab07ef7f_20231206045722&state=redir%3D%252F
```

ごちゃごちゃしてわかりにくいですが、`scope=email+profile+openid+api%3A%2F%2F5c428aab-1151-4ffe-bc77-37b53602fd7a%2Fuser_impersonation` の部分です。

さて認証を通すと以下のような同意が求められます。
１つめの赤枠の部分が Frontend 側のアプリに、Backend 側のアクセスを委任して（ユーザーのフリをして）も良いか？と同意を求められている部分です。
２つめは Backend 側も初回アクセスなので EasyAuth だけを設定した時と同じ同意画面が出ています。

![](./images/consent-dialog.png)

認証が終わったら App Service の既定のページが表示されていると思いますが、おもむろに URL の後ろに `/.auth/me` を追加してみてください。

```
https://frontend-webapp-name.azurewebsites.net/.auth/me
```
JSON が帰ってくるので、そこで `access_token` を https://jwt.ms でデコードしてやると、Web API のスコープが認可されていることが確認できます。

![](./images/impersonation-token.png)
