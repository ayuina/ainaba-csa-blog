---
layout: default
title: Azure Static Web Apps の認証とアクセス制御まわりで気になったところ
---

## はじめに

[Azure Static Web Apps](https://docs.microsoft.com/ja-jp/azure/static-web-apps/overview) が GA してしばらくたってしまいましたが、やっとお試しすることができました。
いつものようにまず気になったのは認証やアクセス制御周りなのですが、通常の App Service や Functions とはどうも使い勝手が違うので若干戸惑いました、という記事です。
まあ例によって[ドキュメントに書いてあったこと](https://docs.microsoft.com/ja-jp/azure/static-web-apps/authentication-authorization)ではあるんですが、
試してみないと分からないことも多かったわけです。

（以下では **衝撃** とか書いてますが、個人的にビックリしただけでネガティブな意味合いはありません）

## 何もしなくてもユーザーは認証できる

Azure Static Web Apps では作成時点で 3 つの認証プロバイダーが設定されているので、何も設定しなくてもこれらの ID をもつユーザー認証は可能です。

- Azure Active Directory
- Github
- Twitter

Static Web Apps を作ると ` https://<webapp-domain-name>.azurestaticapps.net `というようなドメインのサイトが稼働するわけですが、
ここで各プロバイダー固有のログインルート `/.auth/login/<provider>` へ誘導してやればユーザーをログインさせることが可能です。
Twitter ID でユーザーを認証したいのであれば Twitter 用の Login URL へリンクを設置しておくなり、リダイレクトするなりすれば良いわけですね。
各プロバイダーに対する**アプリケーションの登録すら必要ない**という 1 つめの衝撃でした。

|Provider Name|Login URL|
|---|---|
|Azure Active Directory|https://_webapp-domain-name_.azurestaticapps.net/.auth/login/aad|
|GitHub|https://_webapp-domain-name_.azurestaticapps.net/.auth/login/github|
|Twitter|https://_webapp-domain-name_.azurestaticapps.net/.auth/login/twitter|

なおこれは「Static Web Apps では匿名アクセスが出来ない」という意味ではありません。
何も設定してない状態ではもちろん匿名アクセスが可能なのですが、上記のログイン URL に誘導してやれば認証（Authentication）、すなわち「ユーザーが誰であるか？」を確認することができる、というだけの話です。
匿名ユーザー（Anonymous）を許可するとかしないとかという話は後述のアクセス制御（Authorization）の話になります。

## ユーザーの同意は隙を生じぬ二段構え

さてログイン URL に画面遷移すると例によってプロバイダー側の同意画面に飛ばされ、「Azure Static Web Apps がアプリがあなたの情報にアクセスしたがってるけど承諾するか？」と確認されることになります。
それに同意すると今度は元々アクセスしていた個々のアプリに対しての同意を求められることになります。

![consent twice](./images/consent-twice.png)

どうもこの Static Web Apps というのはそれ全体で１つのアプリケーションとしてプロバイダーに登録されているようで、Azure Active Directory の管理画面ではエンタープライズアプリケーションを確認できます。
つまり一度 Static Web Apps に対する１つめの同意をすると、別の Static Web Apps にアクセスしても同じプロバイダーを使っている場合には２つ目の同意だけが表示されることになります。

なおこの Static Web Apps への同意後は各ユーザーの [マイアプリ](https://myapps.microsoft.com/) ポータルで確認することができます。
同意を取り消したい場合はこちらから `権限の取り消し` をしてやれば１つめの同意を取り消すことが出来ます。

![consent apps](./images/consent-apps.png)

2つ目の同意を取り消したい場合は

いつも使ってるはずの Azure Active Directory なのに **同意画面や画面遷移がいつもと違うな？** という 2 つ目の衝撃でした。


## アクセストークンは貰えない（クライアントサイド）

さてユーザーが同意してくれればアプリケーションは認証済みのユーザー情報を取得することが出来ます。
クライアントサイドからは直接アクセスエンドポイント `/.auth/me` にアクセスすることで現在ログイン中のユーザ情報を取得できます。
実アプリケーションからの利用では下記のように Fetch API などを呼び出すことで取得可能です。
テスト目的であればブラウザのアドレスバーに直接 `/.auth/me` を入力して画面遷移しても良いでしょう。

```javascript
const ret = await fetch('/.auth/me');
const me = await ret.json();
```

得られる結果は以下のようになります。

```json
// Azure AD 認証をしていた場合の戻り
{
  "clientPrincipal": {
    "identityProvider": "aad",
    "userId": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "userDetails": "username@domainname.com",
    "userRoles": [
      "anonymous",
      "authenticated"
    ]
  }
}
```

ログインしてない状態であれば `clientPrincipal` フィールドが `null` になります。

```json
{
  "clientPrincipal": null
}
```

見ての通り、得られるものはあくまでもユーザー情報だけです。
本家（？） Azure App Service のトークンストアの場合は idトークンやらアクセストークンやらリフレッシュトークンやらが取得出来たのですが、Static Web Apps の場合だと用途が極めて限られそうかなという印象です。
画面初期表示時にまずログイン状態のチェックをするとか、ユーザーロールに応じて画面表示を調整するといった、**ユーザー補助くらいにしか使え無さそう**かな？というのが 3 つ目の衝撃でした。

呼び出しにアクセストークンが必要な API が外部にあるなら、そこは自力実装するしかないかなーというとこでしょうか。

## アクセストークンは貰えない（サーバーサイド）

Static Web Apps では Functions ベースのサーバーサイド API もホストできるわけですが、ユーザーが認証済みであればサーバーサイドでもユーザー情報を取得することが出来ます。
ユーザー情報は `x-ms-client-principal` リクエストヘッダーにセットされてきますので、その値を Base64 でデコードしして ASCII で文字列に戻してやれば、クライアントサイドと全く同じ情報が手に入ります。

```c#
var xmscp = System.Text.UTF8Encoding.UTF8.GetString(Convert.FromBase64String(req.Headers["x-ms-client-principal"]));
dynamic cp = JObject.Parse(xmscp);
var message = $"Hello {cp.userDetails} !!!"
```

つまりクライアントサイドと同様に用途は限られそう、ということですかね。
なのでメトリックやイベントの情報収集時にユーザー情報を紐付けたトラッキング用途が主体になりそうかなあ、といったところでしょうか。
この情報だけだとユーザーのフリをして外部サービスを呼び出すこと Authorization Code Grant Flow 的なことはできなさそうなので、API 側でクレデンシャルを保持する Client Credential Flow にせざるを得ないかなというところです。

## 匿名アクセスはお断り

さて Static Web Apps は既定では匿名アクセスが可能ですので、世界中の誰でも利用可能な状態です。
それがサイトの目的に適っていればいいのですが、ユーザートラッキングなどの目的からアクセスユーザーを特定したいということもあるでしょう。
つまり前述のユーザー認証を強制したい（身元が特定できてないユーザーにはコンテンツにアクセスさせたくない）わけです。

Static Web Apps では[ルート毎にアクセス可能なロールを設定する](https://docs.microsoft.com/ja-jp/azure/static-web-apps/configuration#securing-routes-with-roles)ことが出来るのですが、
このルールを `staticwebapp.config.json` というファイルに記載する必要があります。
また前述の通りユーザーは認証された段階で `authenticated` というロールが与えられています。
いろいろやり口はあると思いますが、サイト全体が保護対象なのであれば例えば下記のように設定することができます。

```json
//staticwebapp.config.json
{
  "routes": [
    {
      "route": "/", "allowedRoles" : ["anonymous"]
    }, 
    {
      "route": "/index.html", "allowedRoles" : ["anonymous"]
    },
    {
      "route": "/*", "allowedRoles" : ["authenticated"]
    }
  ]
}
```

ルート配下全て `/*` に対して匿名アクセス(anonymous)を拒否してしまうと、ログインページへのリンク `/.auth/login/provider` を配置したページにすらアクセスできず不親切極まりないので、そこだけ例外的に許可しています。
本家 Azure App Service のユーザー認証機能のように**自動的にログイン画面にリダイレクトしてくれない**のか・・・、というのが 4 つ目の衝撃でした。

## 一見さんはお断り

前述の方法ですとユーザー認証を強制することはできますが、逆に言えば Azure Active Directory、Twitter、GitHub の ID さえ持っていれば誰でもアクセスできるわけです。
そもそもどの ID も取得は無料かつ容易なので、これを持ってアクセス制御という事は出来ないでしょう。
アクセス制御というからには **特定のユーザーのみにアクセスを許可したい** わけです。

これを実現するためには個々のユーザーに対してカスタムロールを割り当て、そのロールにのみルートへのアクセスを許可すれば良いわけです。
例えばこのアプリケーションには `users` というロールがあるとすると、前述のルート定義は以下のようになります。

```json
//staticwebapp.config.json
{
  "routes": [
    {
      "route": "/", "allowedRoles" : ["anonymous"]
    }, 
    {
      "route": "/index.html", "allowedRoles" : ["anonymous"]
    },
    {
      "route": "/*", "allowedRoles" : ["users"]
    }
  ]
}
```

せっかくログインしていても認証されている `authenticated` だけでは不足するので、`index.html` 以外のコンテンツへのアクセスはすべて `401 : Unauthorized` エラーで拒否されます。

ではどうすれば `users` ロールの仲間に入れてもらえるのでしょうか。
Static Web Apps には「ロール管理」というメニューがありますので、管理者にお願いしてここから `招待` してもらうことになります。

![role management](./images/role-management.png)

この招待操作を実施すると図のように `招待リンク` が生成されますので、このリンクをアクセス許可したいユーザーに何らかの手段で送付します。
招待されたユーザーはこのリンク先を開いてログインを行うと招待を受け入れた事になるので、ロール管理画面にユーザー情報が追加されます。
Azure AD B2B のように **招待メールとか送信してくれない**んだ・・・、 というのが5つ目の衝撃でした。

## バックエンドを守りたい

Staic Web Apps の API は[本家 Azure Functions に比べてかなり制約がある](https://docs.microsoft.com/ja-jp/azure/static-web-apps/apis)のですが、
個人的に最も意外だったのは Functions Key による制御がかからずに、**デフォルトでは API を呼び出し放題** だったというのが 6 つめの衝撃です。

たとえば以下のような C# Function を作っておいても、Static Web Apps のクライアントサイドからはキー無しであっさり呼び出せてしまうわけです。

```c#
// サーバーサイド API
[FunctionName("HelloAuthUser")]
public static async Task<IActionResult> Run(
    [HttpTrigger(AuthorizationLevel.Function, "get", "post", Route = "hello")] HttpRequest req, ILogger log)
{
    var cpstr = System.Text.UTF8Encoding.UTF8.GetString(Convert.FromBase64String(req.Headers["x-ms-client-principal"]));
    dynamic cp = JObject.Parse(cpstr);
    var ret = new
    {
        message = $"Hello {cp.userDetails} !!!" 
    };
    return new OkObjectResult(ret);
}
```
API キーで守っているつもりが・・・・

```javascript
// クライアントサイドからの呼び出し
let payload = await (await fetch('./api/hello')).json();
alert(payload.message);
```

なので、API の呼び出しもルート規則でアクセス制御しましょう。
Static Web App でホストされる API は全て `/api` ルート配下で動作することになっています。

前述の設定だと `users` ロールに招待された全てのユーザーが API 呼び出し出来てしまいますので、さしあたり世界中から無尽蔵に API を呼び出される事故は防ぐことができています。
これを例えば `admin` ロールに招待された一部のユーザーのみに API 呼び出しを許可するのであれば、以下のような設定になるでしょうか。

```json
//staticwebapp.config.json
{
  "routes": [
    {
      "route": "/", "allowedRoles" : ["anonymous"]
    }, 
    {
      "route": "/index.html", "allowedRoles" : ["anonymous"]
    },
    {
      "route": "/api/*", "allowedRoles" : ["admin"]
    },
    {
      "route": "/*", "allowedRoles" : ["users"]
    }
  ]
}
```


## まとめ

これまで　Azure Web Apps や Azure Functions に慣れ親しんた方には違和感があるのではないでしょうか。
Static Web Apps というのはそういうものだ、と割り切ってしまえば別にどうということはないのですが、
その違和感に気が付かずに設計や実装をしてしまうと事故も起こりそうかなというところで記事にしてみました。
皆さんの参考になれば幸いです。
