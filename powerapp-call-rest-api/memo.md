# setup

```pwsh
dotnet new globaljson --sdk-version 3.1.301
dotnet new webapi
```
おれおれ証明書によるSSLをはずす
```csharp
public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
{
    //app.UseHttpsRedirection();
}
```

動作確認
```pwsh
dotnet run
curl http://localhost:5000/weatherforecast -UseBasicParsing
```

# Swagger対応

Swagger用のパッケージを追加
```pwsh
dotnet add package Swashbuckle.AspNetCore
```

ドキュメントコメントの出力を有効にするが、警告が多くなるので除外
```
<PropertyGroup>
    <TargetFramework>netcoreapp3.1</TargetFramework>
    <GenerateDocumentationFile>true</GenerateDocumentationFile>
    <NoWarn>$(NoWarn);1591</NoWarn>
</PropertyGroup>
```

ドキュメントコメントファイルを読み込んで OpenAPI仕様書を生成するように設定
Startup.cs を書き換えて

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

OpenAPI の仕様書を実行環境で表示、生成するためのエンドポイントを追加
V2指定はPowerAppsの制約

```csharp
app.UseSwagger(c => {
    c.SerializeAsV2 = true;
});
app.UseSwaggerUI(c => {
    c.SwaggerEndpoint("/swagger/v1/swagger.json", "My API v1");
});

```

既存のAPIに対してOperationの記述を追加する
```csharp
[HttpGet(Name="Get_WeatherForecast")]
public IEnumerable<WeatherForecast> Get()
{
    //省略
}
```
ブラウザで開いて動作確認

```bash
dotnet new gitignore
git init 
git add .
git commit -m "1st version"
```

## Public 空間でホストする

### WebAppの作成とホスト

https://docs.microsoft.com/ja-jp/azure/app-service/quickstart-dotnetcore?pivots=platform-linux

```bash
az login 
az account set --subscription guid-of-your-subscription
az group create --name powerapp-customapi-demo-rg --location WestUS2
az appservice plan create --name mypowerapp-customapi-plan --resource-group powerapp-customapi-demo-rg
az webapp create --name mypowerapp-customapi --plan mypowerapp-customapi-plan --resource-group powerapp-customapi-demo-rg --runtime "DOTNETCORE|3.1"

https://docs.microsoft.com/ja-jp/azure/app-service/deploy-zip
dotnet publish -o publish
cd publish
zip -r publish.zip .
az webapp deployment source config-zip --src publish.zip --resource-group powerapp-customapi-demo-rg --name mypowerapp-customapi 
curl http://mypowerapp-customapi.azurewebsites.net/weatherforecast 
curl http://mypowerapp-customapi.azurewebsites.net/swagger/v1/swagger.json
```

###　