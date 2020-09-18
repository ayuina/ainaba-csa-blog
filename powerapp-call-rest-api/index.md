---
layout: default
title: Power Apps キャンバスアプリからカスタム API を呼び出す
---

## はじめに

基本的に Power Apps は **本業のアプリケーション開発者でなくても API の利活用による業務効率の改善ができる** ことを主眼としており、コードを記述することなく GUI アプリケーションを作成することができるようになっているため、ノーコード（No Code）、あるいはローコード（Low Code）と言う面が着目されているかと思います。
とはいえ、実際の現場では要件にばっちりフィットする API があるとも限りませんし、開発者と協力して API 自体を作成しなければならないシーンもあるのではないでしょうか。

ということで[前回](../powerapp-campus-submit-button) は画面項目に設定された式の挙動と、 Power Apps のボタンを押した際の挙動を試しただけですので、今回は REST API を作成しキャンバスアプリから呼び出す一連の流れを紹介したいと思います。

大まかな作業の流れは以下のようになります。

1. Web API を作成する
1. OpenAPI ドキュメントを生成する
1. Web API を実行環境にホストする
1. OpenAPI ドキュメントからカスタムコネクタを作成する
1. キャンバスアプリを作成して接続を追加する
1. キャンバスアプリから API を呼び出して結果を表示する

## アーキテクチャ

![architecture overview](./images/overview.png)

Web API の作成方法、OpenAPI ドキュメントの作成方法、Web API をホストする実行環境の選択肢はいろいろありますが、ここでは下記の技術を採用しています。

|項目|技術|
|---|---|
|API の作成|[ASP.NET Core Web API](https://docs.microsoft.com/ja-jp/aspnet/core/web-api/?view=aspnetcore-3.1)|
|OpenAPI ドキュメントの作成|[Swashbuckle](https://docs.microsoft.com/ja-jp/aspnet/core/tutorials/getting-started-with-swashbuckle?view=aspnetcore-3.1&tabs=visual-studio-code)|
|API のホスト|[Azure WebApp](https://docs.microsoft.com/ja-jp/aspnet/core/host-and-deploy/azure-apps/?view=aspnetcore-3.1)|

## Web API を作成する

まず初めに [.NET Core SDK](https://dotnet.microsoft.com/download) を使用して Web API を作成しましょう。
Web API の実装方法の詳細は本題ではないので、ここではテンプレートで自動生成できる範囲で済ませてしまいます。

```bash
# 利用する SDK のバージョンを固定しておく
dotnet new globaljson --sdk-version 3.1.301
# ASP.NET Core Web API のテンプレートからプロジェクトを自動生成する
dotnet new webapi
```

これで Web API 自体は出来上がってしまうのですが、開発者用の証明書を使用して HTTPS が強制される実装になっているので、
`Startup.cs` を修正してコメントアウトしておきます。

```csharp
public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
{
    //app.UseHttpsRedirection();
}
```

それでは動作確認です。
JSON 形式のレスポンスデータが帰ってくることを確認して下さい。
これが後ほど Power Apps から呼び出す API になります。

```bash
# 開発用 Web サーバーを起動（既定ではポート 5000 で待機しているはず）
dotnet run
# テンプレートで実装済みの WeatherForecast API を呼び出す。
curl http://localhost:5000/weatherforecast
```

ブラウザで動作確認してみれば以下のように表示されるはずです。
リフレッシュするたびに値が変動することもご確認ください。

![Weather Forecast](./images/weatherforecast-result.png)

## OpenAPI ドキュメントを生成する

Web API としては出来上がりなのですが、このままでは外部からこの API の仕様を確認する術がないので、使いにくい状態です。
OpenAPI 形式にのっとった仕様書を生成すると、 Power Apps に限らず各種クライアントアプリから呼び出しやすくなります。
ASP.NET Core では [Swashbuckle.AspNetCore](https://www.nuget.org/packages/Swashbuckle.AspNetCore/) というパッケージを追加することで、
実装済みの API の情報から OpenAPI ドキュメントを自動生成させることが出来ます。

まず下記のコマンドでパッケージをプロジェクトに追加しておきます。

```bash
dotnet add package Swashbuckle.AspNetCore
```

Swashbuclke は C# のソースコードに記載されたドキュメントコメントを元に生成される XML ファイルの情報を利用しますので、
プロジェクトファイル(csproj) を修正して XML 出力を有効にします。
下記のように `GenerateDocumentationFile` 要素を追加するとビルド時に XML ファイルが生成されます。
その時に大量に警告が表示されがちなのですが、それを抑止したい場合は必要に応じて `NoWarn` 要素も追加しておいてください。

```xml
<PropertyGroup>
    <TargetFramework>netcoreapp3.1</TargetFramework>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <NoWarn>$(NoWarn);1591</NoWarn>
</PropertyGroup>
```

`Startup.cs` を書き換えて、Swashbuclke サービスを組み込みます。
ここでは OpenAPI ドキュメントのメタデータを追加するとともに、ビルド時に一緒に出力されているはずのドキュメントコメントファイルを読み込むように指示しています。

```csharp
public void ConfigureServices(IServiceCollection services)
{
    services.AddControllers();
    services.AddSwaggerGen(c => {
        c.SwaggerDoc("v1", new OpenApiInfo() { 
            Version = "v1",
            Title = "My API",
            Description = "This API is the sample of backend service for PowerApps and custom connector."
        });

        var xmlFile = $"{Assembly.GetExecutingAssembly().GetName().Name}.xml";
        var xmlPath = Path.Combine(AppContext.BaseDirectory, xmlFile);
        c.IncludeXmlComments(xmlPath);
    });
}
```

実装した WebAPI と同様に、OpenAPI のユーザーインタフェースだけでなく、ドキュメントを特定のエンドポイントでホストするように指定します。
なおここで V2 を指定している理由は、現在 Power Apps のカスタムコネクタが 
[OpenAPI 2.0 のみをサポートしている](https://docs.microsoft.com/ja-jp/connectors/custom-connectors/faq#other)
からです。

```csharp
app.UseSwagger(c => {
    c.SerializeAsV2 = true;
});
app.UseSwaggerUI(c => {
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "My API v1");
});

```

ここまででミドルウェアとしての準備が終わりましたので、各 WebAPI のメタデータを付与していきます。
テンプレートには API の操作が１つだけ含まれておりますので、Operation の記述を追加しておきます。

```csharp
[HttpGet(Name="Get_WeatherForecast")]
public IEnumerable<WeatherForecast> Get()
{
    //省略
}
```

改めて Web API を動作させて OpenAPI UI とドキュメントを確認してみましょう。
ブラウザーから `http://localhost:5000/swagger` にアクセスします。

![swagger ui](./images/swagger-ui.png)

画面上部に `swagger.json` のリンクがありますので、ここからファイルをダウンロードして保存しておきます。
これがカスタムコネクタの元ネタになります。

## Power Apps のカスタムコネクタを作成する



https://docs.microsoft.com/ja-jp/connectors/custom-connectors/define-openapi-definition