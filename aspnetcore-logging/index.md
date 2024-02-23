---
layout: default
title: ASP.NET Core アプリケーションのログ出力
---

# はじめに

私の所属は営業部門なのですが技術者的なロールでもあるので、お客様と会話の中でトラブルシュートになることも多々あります。
多くの場合は PoC や検証段階で「うまく動かないんだけど助けて」ってやつなんですが、たまに本番環境でのご相談も舞い込んできます。
そんなトラシューで重要なのが「ログ」なんですが、このログの出し方がわからない、あるいは確認方法がわからないとなるとやれることが限られてきます。
まあログ出力は割と初歩的な話ではありますし、検索すれば公式ドキュメントがあっさり引っかかりますよね。
ただ昨今のアプリケーション フレームワークは割と高機能になってしまっているせいか、結局のところ自分のアプリケーションではどうすればログが出せるのかわかりにくかったりします。

この手の相談は結構な頻度でいただくのでちょっとまとめてみようかなと思ったんですが、実行環境やフレームワークによってお作法も様々ですので、網羅するのはちょっと辛い。
というわけで、ASP.NET Core で作ったアプリを Azure App Service にデプロイする前提でまとめてみようと思いました。

## 参考情報

- [.NET Core および ASP.NET Core でのログ記録](https://learn.microsoft.com/ja-jp/aspnet/core/fundamentals/logging/?view=aspnetcore-8.0)
- [ASP.NET Core での開発におけるアプリ シークレットの安全な保存](https://learn.microsoft.com/ja-jp/aspnet/core/security/app-secrets?view=aspnetcore-8.0&tabs=windows
)
- [ASP.NET Core での HTTP ログ](https://learn.microsoft.com/ja-jp/aspnet/core/fundamentals/http-logging/?view=aspnetcore-8.0)

# まずはデフォルトで確認できるログについて

ここでは [ASP.NET Core Razor Pages](https://learn.microsoft.com/ja-jp/aspnet/core/razor-pages/?view=aspnetcore-8.0&tabs=visual-studio) を題材にしていきます。
Razor Pages 以外の ASP.NET Core 系のアプリケーション（MVC, API, Blazor, Minimal API, etc...）であれば概ね同じお作法になりますし、
[HostApplicationBuilder](https://learn.microsoft.com/ja-jp/dotnet/api/microsoft.extensions.hosting.hostapplicationbuilder?view=dotnet-plat-ext-8.0)
を使う各種アプリケーション（MAUI とか汎用ホストとか）であれば大体一緒になると思います。
要は Program.cs で `HogeHogeBuilder.Build()` とかやってて、その前後に DependencyInjection したり Midlleware を組み込んでリクエストパイプラインを構築してるアレです。

というわけで、Razor Pages な Web アプリを作ってみます。
もちろん Visual Studio のプロジェクトテンプレートを使っても OK です。
```bash
dotnet new webapp -o aspnet-logging-sample
```

出来上がったら何も書き換えずに徐に実行します。
コンソールで `dotnet run` するか VS や VSCode で F5（デバッグ実行）してください。
そうすると起動したコンソールやデバッガーの出力に以下のような表示が出ると思います。

```log
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: https://localhost:7105
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5202
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
info: Microsoft.Hosting.Lifetime[0]
      Hosting environment: Development
info: Microsoft.Hosting.Lifetime[0]
      Content root path: /Users/username/source/aspnet-logging-sample
```

これがデフォルトで確認できる **ログ** ですね。
ブラウザーで URL を開いてやれば画面は表示されますが、その後もこのログは書きかわりません。
（デバッガをアタッチしてる場合はちょろちょろと出てきますが、そっちは割愛）


> ちなみに出力内容としては以下の項目の繰り返しになっていることがわかります。
> ```log
> loglevel: カテゴリー名[eventid] 
>           ログ出力されたメッセージ（複数行の場合もある）
> ```
> ここでカテゴリー名は「名前空間で修飾されたクラス名」になっており、どこのコードが出力してるログが欲しいか？という観点からとても重要なポイントになってきます。
> まtあここで出力されている表記は Console ログプロバイダーが決めてるフォーマットですので、違うログプロバイダーを使用すれば別のフォーマットになっている場合もあります。
> もちろんカスタムのログプロバイダーを実装して、好みの出力先やフォーマットにすることも可能です。

ではここから、このログ出力をリッチにしていきたいと思いますが、まずはコードをなるべく書き換えずにやれることを探ります。
本番系のトラブルだと「ログ出力コードを書き加えて調査しましょう」とかなかなか難しいものがあります。
デフォルトで取れるログってのは大事ですよね。

# ASP.NET　Core　フレームワークが出力しているログを充実させる

プレーンな Console アプリでもない限り、多くの .NET アプリはなんらかのフレームワークの上で動いています。
ここでは ASP.NET Core Razor Pages がそのフレームワークです。
つまり開発者が書いていないコードも沢山動いているわけですので、そこからログを吐いてることが期待できます。

さてログの設定ですが、プロジェクト作成（`dotnet new`）時に勝手に作成される構成ファイル、`appsettings.json` と `appsettings.Development.json` に記載があります。
ここでは開発環境ということで `appsettings.Development.json` を見てみましょう。

```json
"Logging": {
    "LogLevel": {
        "Default": "Information",
        "Microsoft.AspNetCore": "Warning"
    }
}
```

既定では「Information」ログレベルなんですが、Microsoft.AspNetCore だけは「Warning」以上のログレベルしか出力されません。
つまり ASP.NET Core フレームワークのログは警告が必要だなーという時しかログが出てこないわけですね。
先程の確認ではちゃんとページが表示されて正常稼働していたので、何も出てこないのが正しかったわけです。

このログレベルですが定義としては以下のようになっており、構成ファイルで指定したログレベル「以上」のものが出力されます。

|Trace|Debug|Information|Warning|Error|Critical|None|
|--:|--:|--:|--:|--:|--:|--:|
|0|1|2|3|4|5|6|

というわけで、`appsettings.Development.json` ファイルの `Logging:LogLevel:Microsoft.AspNetCore` の値を `Information` に書き換えます。
改めてアプリを起動してブラウザで表示してみてください。
（ちなみにここで欲張って Trace とか Debug を指定すると、心が折れるほど大量に出力されますのでご注意ください）

```log
info: Microsoft.AspNetCore.Hosting.Diagnostics[1]
      Request starting HTTP/1.1 GET http://localhost:5202/ - - -
warn: Microsoft.AspNetCore.HttpsPolicy.HttpsRedirectionMiddleware[3]
      Failed to determine the https port for redirect.
info: Microsoft.AspNetCore.Routing.EndpointMiddleware[0]
      Executing endpoint '/Index'
info: Microsoft.AspNetCore.Mvc.RazorPages.Infrastructure.PageActionInvoker[103]
      Route matched with {page = "/Index"}. Executing page /Index
info: Microsoft.AspNetCore.Mvc.RazorPages.Infrastructure.PageActionInvoker[105]
      Executing handler method aspnet_logging_sample.Pages.IndexModel.OnGet - ModelState is Valid
info: Microsoft.AspNetCore.Mvc.RazorPages.Infrastructure.PageActionInvoker[108]
      Executed handler method OnGet, returned result .
info: Microsoft.AspNetCore.Mvc.RazorPages.Infrastructure.PageActionInvoker[107]
      Executing an implicit handler method - ModelState is Valid
info: Microsoft.AspNetCore.Mvc.RazorPages.Infrastructure.PageActionInvoker[109]
      Executed an implicit handler method, returned result Microsoft.AspNetCore.Mvc.RazorPages.PageResult.
info: Microsoft.AspNetCore.Mvc.RazorPages.Infrastructure.PageActionInvoker[104]
      Executed page /Index in 260.5577ms
info: Microsoft.AspNetCore.Routing.EndpointMiddleware[1]
      Executed endpoint '/Index'
info: Microsoft.AspNetCore.Hosting.Diagnostics[1]
      Request starting HTTP/1.1 GET http://localhost:5202/aspnet_logging_sample.styles.css - - -
info: Microsoft.AspNetCore.Hosting.Diagnostics[2]
      Request finished HTTP/1.1 GET http://localhost:5202/ - 200 - text/html;+charset=utf-8 399.7447ms
info: Microsoft.AspNetCore.Hosting.Diagnostics[2]
      Request finished HTTP/1.1 GET http://localhost:5202/aspnet_logging_sample.styles.css - 404 0 - 3.1639ms
info: Microsoft.AspNetCore.Hosting.Diagnostics[16]
      Request reached the end of the middleware pipeline without being handled by application code. Request path: GET http://localhost:5202/aspnet_logging_sample.styles.css, Response status code: 404
info: Microsoft.AspNetCore.Hosting.Diagnostics[1]
      Request starting HTTP/1.1 GET http://localhost:5202/css/site.css?v=pAGv4ietcJNk_EwsQZ5BN9-K4MuNYS2a9wl4Jw-q9D0 - - -
info: Microsoft.AspNetCore.Hosting.Diagnostics[1]
      Request starting HTTP/1.1 GET http://localhost:5202/js/site.js?v=hRQyftXiu1lLX2P9Ly9xa4gHJgLeR1uGN5qegUobtGo - - -
info: Microsoft.AspNetCore.Hosting.Diagnostics[1]
      Request starting HTTP/1.1 GET http://localhost:5202/lib/bootstrap/dist/css/bootstrap.min.css - - -
info: Microsoft.AspNetCore.StaticFiles.StaticFileMiddleware[6]
      The file /css/site.css was not modified
info: Microsoft.AspNetCore.StaticFiles.StaticFileMiddleware[6]
      The file /js/site.js was not modified
info: Microsoft.AspNetCore.Hosting.Diagnostics[2]
      Request finished HTTP/1.1 GET http://localhost:5202/js/site.js?v=hRQyftXiu1lLX2P9Ly9xa4gHJgLeR1uGN5qegUobtGo - 304 - text/javascript 3.5195ms
info: Microsoft.AspNetCore.StaticFiles.StaticFileMiddleware[6]
      The file /lib/bootstrap/dist/css/bootstrap.min.css was not modified
info: Microsoft.AspNetCore.Hosting.Diagnostics[2]
      Request finished HTTP/1.1 GET http://localhost:5202/lib/bootstrap/dist/css/bootstrap.min.css - 304 - text/css 8.9015ms
info: Microsoft.AspNetCore.Hosting.Diagnostics[2]
      Request finished HTTP/1.1 GET http://localhost:5202/css/site.css?v=pAGv4ietcJNk_EwsQZ5BN9-K4MuNYS2a9wl4Jw-q9D0 - 304 - text/css 14.9807ms
info: Microsoft.AspNetCore.Hosting.Diagnostics[1]
      Request starting HTTP/1.1 GET http://localhost:5202/lib/bootstrap/dist/js/bootstrap.bundle.min.js - - -
info: Microsoft.AspNetCore.StaticFiles.StaticFileMiddleware[6]
      The file /lib/bootstrap/dist/js/bootstrap.bundle.min.js was not modified
info: Microsoft.AspNetCore.Hosting.Diagnostics[2]
      Request finished HTTP/1.1 GET http://localhost:5202/lib/bootstrap/dist/js/bootstrap.bundle.min.js - 304 - text/javascript 0.4539ms
info: Microsoft.AspNetCore.Hosting.Diagnostics[1]
      Request starting HTTP/1.1 GET http://localhost:5202/lib/jquery/dist/jquery.min.js - - -
info: Microsoft.AspNetCore.StaticFiles.StaticFileMiddleware[6]
      The file /lib/jquery/dist/jquery.min.js was not modified
info: Microsoft.AspNetCore.Hosting.Diagnostics[2]
      Request finished HTTP/1.1 GET http://localhost:5202/lib/jquery/dist/jquery.min.js - 304 - text/javascript 0.3545ms
```

とりあえず出力された中から差分になるものをべたっと貼りましたが、Information でもそれなりに辛いですね。
いくつかピックアップしてみると以下の情報が取れます。

```log
info: Microsoft.AspNetCore.Routing.EndpointMiddleware[0]
      Executing endpoint '/Index'
```
`/Index` へのリクエストが到着して適切な Middleware にルーティングしようとしていることがわかります。

```log
info: Microsoft.AspNetCore.Mvc.RazorPages.Infrastructure.PageActionInvoker[105]
      Executing handler method aspnet_logging_sample.Pages.IndexModel.OnGet - ModelState is Valid
```
テンプレートで生成された `IndexModel（Index.cshtml + Index.cshtml.cs）` クラスの `OnGet` メソッドで処理しています。

```log
info: Microsoft.AspNetCore.StaticFiles.StaticFileMiddleware[6]
      The file /css/site.css was not modified
```
静的ファイルであるスタイルシート `/css/site.css` は RazorPages ではなく `StaticFileMiddleware` が処理していることがわかります。

## 辛いので欲しいところだけ抽出

３度の飯よりログが好きな人でなければ辛いと思いますので、もうちょっと必要な箇所に絞り込んでみましょう。
例えば開発したコードに問題があるならルーティングや実際に処理してるページ周りのログは欲しいと思います。
一方 CSS や JS 等の静的ファイルへのリクエストに対してはただコンテンツを返すだけですから、そこで問題になることは少ないでしょうし、
これらのコンテンツのデバッグはブラウザでやれますので、不要なケースも多いのではないでしょうか。
無駄に数も多いとログが見ずらい原因にもなりますし。

というわけで、`Microsoft.AspNetCore` 配下のカテゴリーは原則として `Warning` レベルに上げて（戻して）しまい、
詳細情報の欲しい `Microsoft.AspNetCore.Routing` と `Microsoft.AspNetCore.Mvc.RazorPages` を追記して `Information` レベルに下げます。

```json
"Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.AspNetCore.Routing": "Information",
      "Microsoft.AspNetCore.Mvc.RazorPages": "Information"
    }
}
```

何度もログを貼っても辛いので割愛しますが、前回よりもかなり絞り込まれた出力になっていると思います。
このカテゴリー名によるフィルターは前方一致し、より詳細な方で上書きできますので、うまく設定して必要な情報を取れるようにしましょう。

> 上記の通り内部的に出力されているログは大量にあるのですが、カテゴリー（＝クラス名）単位でフィルターがかかっていて出力されてない状態なのですが、どんなカテゴリー何が出てるかなんてわからないですよね。開発環境であればとりあえず最低の `Trace` で出してしまってじっくり読んでみるのもいいと思います。
> ただ本番環境ではパフォーマンス的にもストレージ的にも辛いことになりますので、開発環境でなるべく必要なカテゴリを絞り込んでからピンポイントに設定しましょう。

## 構成設定の上書き

ここまでは分かり易さのために `appsettings.Development.json` でログ出力設定を切り替えましたが、このファイルは通常ソースコード管理システムに登録して共有されていることが多いでしょう。
一時的に手元で編集しただけのつもりで、うっかり `git add .` して `git commit` して `git push` して仲間に迷惑をかけてしまう事故を起こしたりしがちです。（しがちですよね？）
つまりあまり個人の開発端末ででごちゃごちゃいじるのには向いていません。

ログ出力設定をを開発端末だけで試したい場合はシークレット マネージャーを使うと良いでしょう。
一般的には外部 API やサービスへ接続する際のパスワードの機微情報を管理するために使いますが、開発端末固有の設定情報をもてるのでこういうケースでも便利です。

Visual Studio の場合はソリューション エクスプローラーでプロジェクトを右クリックして「ユーザーシークレットの管理」とかいうメニュー（うろ覚え）を選ぶだけで良いのですが、コマンドでやる場合は以下のようになります。
詳細はドキュメントを参照してください。

```bash
# まずはユーザーシークレットを初期化
$ dotnet user-secrets init
Set UserSecretsId to 'guid-of-user-secret-id' for MSBuild project '/Users/username/source/projdir/projectName.csproj'.

# 生成された GUID 形式の UserSecretsId をもとに secrets.json を作成
# {guid-of-user-secret-id} の部分は読み替えてください。
$ mkdir ~/.microsoft/usersecrets/guid-of-user-secret-id
$ touch  ~/.microsoft/usersecrets/guid-of-user-secret-id/secrets.json
```

作成した `secrets.json` を適当なエディタで編集して、`appsettigs.json` および `appsettings.Develpment.json` に対する差分の追記ないしは上書きします。
例えば RazorPages 系だけさらにログレベルを下げたい場合は以下のようになります。
```json
{
    "Logging": {
        "LogLevel": {
            "Microsoft.AspNetCore.Mvc.RazorPages": "Trace"
        }
    }
}
```

また動作確認して出力されてるログの情報を確認してみてください。
ここでは割愛します。

> なお `dotnet user-secrets init` で生成したユーザーシークレット ID の GUID 値はプロジェクトファイル（.csproj）に記載されています。
> ターミナルが消えてしまってもそちらで値は確認できますのでご安心を。
> ```xml
> <Project Sdk="Microsoft.NET.Sdk.Web">
>   <PropertyGroup>
>     <UserSecretsId>guid-of-user-secret-id</UserSecretsId>
>   </PropertyGroup>
> </Project>
> ```

なお構成設定の上書きは環境変数で行うことも可能です。
ただこれは開発環境というよりは本番環境向けかなと思いますので後ほど。

# もっとログを増やしたい

ここまではもともとフレームワークが出力しているけれど表示されていなかったログを表示する方法でした。
また設定変更だけですのでソースコードに手を入れにくい（入れらなない）時でも使える方法です。
ここからはコード変更も伴いますが、より詳細な情報が必要になった時のテクニックになってきます。

## HTTP(S)　レベルの通信ログ

ASP.NET のアプリケーションを作ってるわけですから、なんらかのクライアントから HTTP(S) のプロトコルで通信が行われていることでしょう。
通信プロトコルレベルでの処理はフレームワークがやってくれてますので通常はあまり意識することはないんですが、
トラブルシュートとなるとプロトコルレベルまで深掘りしたいこともあるでしょう。
というわけでHTTPのログを増やしたいと思います。

まずは `Program.cs` に記述されたスタートアップ コードをカスタマイズします。

```csharp
// Dependency Injection コンテナに HttpLogging サービスを組み込んでから
builder.Services.AddHttpLogging( c => { 
      /*ここで詳細なカスタマイズを行う*/ 
});

// アプリケーションをビルドして、
var app = builder.Build();

// ミドルウェアの先頭で HttpLogging モジュールを組み込む
app.UseHttpLogging();
```

これで内部的にはログを吐くようになりますので、上記と同様にフィルターを外してやります。
カテゴリとしては `Microsoft.AspNetCore.HttpLogging` 名前空間あたりのフィルターをざっくり `Information` まで下げてやります。
これも大量に出ますので前述の `secrets.json` で設定すると良いでしょう。

```json
"Logging": {
    "LogLevel": {
        "Microsoft.AspNetCore.HttpLogging": "Information"
    }
}
```

そうすると以下のように通信ログが混じってきます。
ログ出力の内容の詳細はスタートアップコードの中で、`AddHttpLogging` に渡しているラムダ式で指定できます。
具体的な方法はドキュメントを参照してください。

```log
info: Microsoft.Hosting.Lifetime[0]
      Content root path: /Users/ainaba/source/aspnet-logging-sample
info: Microsoft.AspNetCore.HttpLogging.HttpLoggingMiddleware[1]
      Request:
      Protocol: HTTP/1.1
      Method: GET
      Scheme: http
      PathBase: 
      Path: /
      Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7
      Connection: keep-alive
      Host: localhost:5202
      User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0
      Accept-Encoding: gzip, deflate, br
      Accept-Language: en-US,en;q=0.9
info: Microsoft.AspNetCore.Routing.EndpointMiddleware[0]
      Executing endpoint '/Index'

      ... 中略 ...

info: Microsoft.AspNetCore.HttpLogging.HttpLoggingMiddleware[1]
      Request:
      Protocol: HTTP/1.1
      Method: GET
      Scheme: http
      PathBase: 
      Path: /aspnet_logging_sample.styles.css
      Accept: text/css,*/*;q=0.1
      Connection: keep-alive
      Host: localhost:5202
      User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36 Edg/121.0.0.0
      Accept-Encoding: gzip, deflate, br
      Accept-Language: en-US,en;q=0.9
info: Microsoft.AspNetCore.Routing.EndpointMiddleware[1]
      Executed endpoint '/Index'
```



## ユーザーコードのインストルメンテーション

ここまでで怪しい箇所が見つからなければ疑うべきは開発したコードの中身ですが、当然ながら明示的にログを出力するコードを記述しない限り勝手にログは吐いてくれません。
というわけでここからはログ出力するための方法ですが、前述のフレームワークと同じ仕組みに則ることをおすすめします。
あっちこっちに出てるログを突き合わせて解析するなんて茨の道を歩かないで済むに越したことはありません。

さて Razor Pages の場合は生成した `cshtml.cs` のコンストラクターで `ILogger<T>` インタフェースなオブジェクトが Injection されてることがわかります。
他のフレームワークやテンプレでは Injection されてないこともありますので、その場合は追加してあげてください。
あとはログを出したい場所で `ILogger` のメソッドを呼び出して、必要な情報を出力してください。

```csharp
public class IndexModel : PageModel {
    // Dependency Injection によって自動挿入されるログモジュール
    private readonly ILogger<IndexModel> _logger;
    public IndexModel(ILogger<IndexModel> logger) {
        _logger = logger;
    }
    
    // Get /Index 時に呼び出されるロジック。各メソッドの第１引数はEventID、第２引数がメッセージ。
    public void OnGet() {
        _logger.LogCritical(999, "Index.cshtml.cs の OnGet が呼ばれました（Crit）");
        _logger.LogError(888,"Index.cshtml.cs の OnGet が呼ばれました（Err）");
        _logger.LogWarning(777, "Index.cshtml.cs の OnGet が呼ばれました（Warn）");
        _logger.LogInformation(666, "Index.cshtml.cs の OnGet が呼ばれました（Info）");
        _logger.LogDebug(555,"Index.cshtml.cs の OnGet が呼ばれました（Debug）");
        _logger.LogTrace(444,"Index.cshtml.cs の OnGet が呼ばれました（Trace）");
    }
}
```

そうすると ASP.NET が自動的に出してるログに混じって、以下のようにログが出力されると思います。


```log
crit: aspnet_logging_sample.Pages.IndexModel[999]
      Index.cshtml.cs の OnGet が呼ばれました（Crit）
fail: aspnet_logging_sample.Pages.IndexModel[888]
      Index.cshtml.cs の OnGet が呼ばれました（Err）
warn: aspnet_logging_sample.Pages.IndexModel[777]
      Index.cshtml.cs の OnGet が呼ばれました（Warn）
info: aspnet_logging_sample.Pages.IndexModel[666]
      Index.cshtml.cs の OnGet が呼ばれました（Info）
```

`Default` カテゴリのログレベルが `Information` になっているのでそれ以上のログレベルしか出力されていませんが、
これまで同様にフィルターの設定を変えてあげることで出力を増減することができます。
例えば各ページの既定のログレベルは `Warning` まで引き上げておき、挙動の怪しい `IndexModel` だけログレベルを `Trace` まで下げて出力を詳細化したい場合の設定は以下のようになります。
これで `Debug`　や `Trace` レベルまで表示されるようになるでしょう。

```json

"Logging": {
    "LogLevel": {
        "aspnet_logging_sample.Pages": "Warning",
        "aspnet_logging_sample.Pages.IndexModel": "Trace",
    }
}
```

さてここで重要なのはカテゴリー（＝名前空間とクラス名）によるフィルターですね。
カテゴリ名は DI フレームワークに挿入してもらう `ILogger<T>` の Generic 型引数 `T` で決ま離ますので、汎用の `ILogger` を使わないようにしましょう。
他のページのコードをコピペして「型引数を書き換え忘れる」とかもってのほかです。
カテゴリが変わってしまうので、どこから出てきたログなのかわからないでログとしての信頼性を失いますし、
フィルター変えても表示されなかったりするのでトラブルシュートの効率が極端に下がります。

皆さんもお気をつけください（反省）

# ライブラリのログ

## HttpClient
## Blob
## OpenAI

# Appserviceでの出方

# ログ出力設定
# Settings による調整