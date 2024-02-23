
# デフォルトで何が出るか

```bash
dotnet new webapp
```

F5実行

デバッグコンソールやターミナルに出る
```
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: https://localhost:7105
info: Microsoft.Hosting.Lifetime[14]
      Now listening on: http://localhost:5202
info: Microsoft.Hosting.Lifetime[0]
      Application started. Press Ctrl+C to shut down.
info: Microsoft.Hosting.Lifetime[0]
      Hosting environment: Development
info: Microsoft.Hosting.Lifetime[0]
      Content root path: /Users/ainaba/source/aspnet-logging-sample
```

## フレームワークのログを充実

Default が Informationだから、Microsoftを WarnからInfoに落とす
appsettings.Development.json
```json
"Logging": {
    "LogLevel": {
        "Default": "Information",
        "Microsoft.AspNetCore": "Information"
    }
}
```

めっちゃ増えるけど、アクセスログとかは出ない。期待通り Microsoft.AspNetCore 系が増える。
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

最初のあたりで /Index にルーティングされ、OnGet が呼び出されて、正常に完了してることがわかります。

## 辛いので欲しいところだけ抽出

また HTML がダウンロードされると CSS JSが呼び出されてStaticFilesあたりが大量に呼ばれてることがわかる。
ピンポイントに抜き出したい

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

## 構成の上書き
appsettigs.json を Development .jsonで上書きしている
これはデプロイされちゃう
secret.json や環境変数で上掛ける




ここまではコード修正なく設定変更だけでできてるので、きぞんにも入れられる

## HTTP のログ

```csharp
//Program.cs

// Dependency Injection コンテナに HttpLogging サービスを組み込んでから
builder.Services.AddHttpLogging( c => {});

// アプリケーションをビルドして、
var app = builder.Build();

// ミドルウェアの先頭で HttpLogging モジュールを組み込む
app.UseHttpLogging();
```

```json
"Logging": {
    "LogLevel": {
        "Default": "Information",
        "Microsoft.AspNetCore": "Warning",
        "Microsoft.AspNetCore.Routing": "Information",
        "Microsoft.AspNetCore.Mvc.RazorPages": "Information",
        "Microsoft.AspNetCore.HttpLogging": "Information"
    }
}
```

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


# ユーザーコードのログ

ここまでエラーが出てなければユーザーコードの中でおかしい

```csharp
public class IndexModel : PageModel {
    // Dependency Injection によって自動挿入されるログモジュール
    private readonly ILogger<IndexModel> _logger;
    public IndexModel(ILogger<IndexModel> logger) {
        _logger = logger;
    }
    
    // Get /Index 時に呼び出されるロジック。各メソッドの第１引数はEventID
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

以下が追加される。
Injection時に型パラメータとして IndexModel のがカテゴリとして追加される
```log
crit: aspnet_logging_sample.Pages.IndexModel[999]
      Index.cshtml.cs の OnGet が呼ばれました（Crit）
fail: aspnet_logging_sample.Pages.IndexModel[888]
      Index.cshtml.cs の OnGet が呼ばれました（Err）
warn: aspnet_logging_sample.Pages.IndexModel[777]
      Index.cshtml.cs の OnGet が呼ばれました（Warn）
info: aspnet_logging_sample.Pages.IndexModel[666]
      Index.cshtml.cs の OnGet が呼ばれました（Info）
dbug: aspnet_logging_sample.Pages.IndexModel[555]
      Index.cshtml.cs の OnGet が呼ばれました（Debug）
trce: aspnet_logging_sample.Pages.IndexModel[444]
      Index.cshtml.cs の OnGet が呼ばれました（Trace）
```

出力を絞り込みたい場合はプロバイダー側で絞り込む
```json
"Logging": {
    "LogLevel": {
        "Default": "Trace",
        "aspnet_logging_sample.Pages": "Warning"
    }
}
```

https://learn.microsoft.com/ja-jp/aspnet/core/fundamentals/logging/?view=aspnetcore-8.0







# ライブラリのログ

## HttpClient
## Blob
## OpenAI

# Appserviceでの出方

# ログ出力設定
# Settings による調整