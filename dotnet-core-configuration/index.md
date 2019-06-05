---
layout: default
title: .NET Core アプリの構成設定について
---

## はじめに

最近はアプリを作る際に .NET Framework ではなく .NET Core を使用することが多いのですが、
構成設定のやり方を良く忘れてしまうので、備忘録としてここに記します。
.NET Framework の時代は基本的に config ファイルに書いておいてコードから読み取るというのがお作法だったのですが、
.NET Core では構成の仕組みそのものが変わっていて、様々な設定場所から値を引っ張ってくることができるようになっています。

なお以下で紹介する検証環境は .NET Core 2.2 を使用しています。

## コンソールアプリケーションの準備

まずコンソールアプリケーションを用意します。
下記のコマンドを実行して Hello World が表示されれば OK です。

```cmd
> dotnet new console -n "appname"
> cd appname
> dotnet run
```
##　ライブラリの準備

.NET Core アプリケーションにおける構成では `Microsoft.Extensions.Configuration` 名前空間のライブラリを使用します。
このライブラリを利用するには追加パッケージが必要なので NuGet で取得します。

```cmd
> dotnet add package Microsoft.Extensions.Configuration
```

これは構成フレームワークの基本部分だけなので、実際に **値を設定したい場所に対応した構成プロバイダー** のパッケージを追加します。
JSON ファイルに設定したいならば `Microsoft.Extensions.Configuration.Json` パッケージを、
環境変数に設定したいならば `Microsoft.Extensions.Configuration.EnvironmentVariables` パッケージを、
コマンドライン引数に設定したいならば `Microsoft.Extensions.Configuration.CommandLine` パッケージを追加します。

```cmd
> dotnet add package Microsoft.Extensions.Configuration.Json
> dotnet add package Microsoft.Extensions.Configuration.EnvironmentVariables
> dotnet add package Microsoft.Extensions.Configuration.CommandLine
```

パッケージを追加するとプロジェクトファイル csproj に依存するパッケージとして以下のように追記されます。
コマンドラインでの記述ではなく直接プロジェクトファイルを書き換えてしまっても構いません。

```xml
<Project Sdk="Microsoft.NET.Sdk">
  <ItemGroup>
    <PackageReference Include="Microsoft.Extensions.Configuration" Version="2.2.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration.CommandLine" Version="2.2.0" />
    <PackageReference Include="Microsoft.Extensions.Configuration.EnvironmentVariables" Version="2.2.4" />
    <PackageReference Include="Microsoft.Extensions.Configuration.Json" Version="2.2.0" />
  </ItemGroup>
</Project>
```

### JSON ファイルの記載と設定値の列挙

まずプロジェクトルートディレクトリに以下のような JSON 形式のファイルを作成してください。
昔ながらの AppSettings セクション、ConnectionStrings セクションに加えて、
ルートレベルおよびネストしたカスタムセクションを記載しています。

```json
{
    "RootLevelKey" : "RootLevelValue",
    "AppSettings" : {
        "Key1" : "Value1",
        "Key2" : "Value2"
    },
    "ConnectionStrings" : {
        "SqlConnection1" : "server=localhost;database=pubs;userid=sa;pwd=p@ssw0rd!;"
    },
    "CustomSection" : {
        "CustomKey" : "CustomValue",
        "NestedSection" : {
            "ChildLevelKey" : "Child Value of Section1"
        }
    }
}
```

次にこの設定ファイルを読み取るためのコードです。
- 名前空間の using に `Microsoft.Extensions.Configuration` を追加
- ConfigurationBuilder を作成
- `SetBasePath` メソッドを使用して設定ファイルを探索する場所を指定（ここでは実行可能ファイルと同じ場所）
- `AddJsonFile` メソッドを使用して設定値が記載された実際の JSON ファイルの名前を指定
- 最後に `Build` メソッドを使用して IConfiguration インタフェースのオブジェクトが生成

以降ではこのオブジェクトから実際の構成値を取得することができます。
まずは設定値のキーと値を全部列挙してみましょう。

```csharp
using System;
using Microsoft.Extensions.Configuration;

class Program
{
    static void Main(string[] args)
    {
        var config = new ConfigurationBuilder()
            .SetBasePath(AppDomain.CurrentDomain.BaseDirectory)
            .AddJsonFile("setting.json")
            .Build();

        foreach(var ckv in config.AsEnumerable())
        {
            Console.WriteLine($"{ckv.Key} >>> {ckv.Value}");
        }
    }
}
```
このままビルドして実行しても設定ファイル（ここでは setting.json）がビルド出力結果に存在しないため、エラーになってしまいます。
手動で配置しても良いですが、プロジェクトファイルを書き換えてソースコードをビルドするたびに設定ファイルをコピーしたほうが簡単でしょう。

```xml
<ItemGroup>
    <None Update="setting.json">
        <CopyToOutputDirectory>Always</CopyToOutputDirectory>
    </None>
</ItemGroup>
```

この状態でビルドして実行すると以下のような出力が得られると思います。

```cmd
> dotnet run

RootLevelKey >>> RootLevelValue
CustomSection >>>
CustomSection:NestedSection >>>
CustomSection:NestedSection:ChildLevelKey >>> Child Value of Section1
CustomSection:CustomKey >>> CustomValue
ConnectionStrings >>>
ConnectionStrings:SqlConnection1 >>> server=localhost;database=pubs;userid=sa;pwd=p@ssw0rd!;
AppSettings >>>
AppSettings:Key2 >>> Value2
AppSettings:Key1 >>> Value1
```

### キーを指定した設定値の読み取り

実際のアプリケーション実行時に列挙しても仕方ないので、キーを指定してピンポイントに必要な値を取得する必要があります。
前述の出力結果からセクションの区切りはコロン（:）であることがわかりましたので、
`IConfiguration` オブジェクトに対して指定するキー値もセクション構造を意識して指定します。

```csharp
Console.WriteLine( config["RootLevelKey"] );
Console.WriteLine( config["CustomSection:CustomKey"] );
Console.WriteLine( config["CustomSection:NestedSection:ChildLevelKey"] );
```

カスタムセクションを指定して複数の構成値をグループ化しているということは、関連する複数の設定値が記載されているということだと思います。
この場合、いちいちセクション区切りを入れた文字列を記載するのは面倒ですので、`GetSection` メソッドを指定してまとめて取得することができます。

```csharp
var appSettings = config.GetSection("AppSettings");
Console.WriteLine( appSettings["Key1"] );
Console.WriteLine( appSettings["Key2"] );
```

ConnectionStrings セクションに記載された接続文字列も上記と同様に取得することもできますが、
専用メソッド `GetConnectionString` を使用したほうが楽な場合も多いでしょう。
以下の３つはどれも同じ値を出力するはずです。

```csharp
Console.WriteLine( config["ConnectionStrings:SqlConnection1"] );
Console.WriteLine( config.GetSection("ConnectionStrings")["SqlConnection1"] );
Console.WriteLine( config.GetConnectionString("SqlConnection1") );
```

### 環境変数による設定値の上書き

前述のようなファイルベースの管理だと、基本的にはアプリケーションの配置先に合わせて何パターンかのファイルを用意しておくことになります。
ただ接続文字列等には往々にしてパスワード等のシークレット情報が含まれますので、ソースコード管理システムに保存することはもちろん NG ですし、別途管理するにしてもファイルの漏洩が不安です。
また昨今はアプリケーションの配置自体を CI/CD パイプラインで自動化することが主流になっていますので、そうなるとビルドないしはリリースの処理の途中でファイルのすげ替え（あるいは値の書き換え）が必要になります。
あるいは Docker 等のコンテナテクノロジを使用した場合には、コンテナイメージの中に設定ファイルが含まれた状態でコンテナレポジトリに保存されてしまいますので、そもそも実際の配置先が決まっていなかったりもします。

さてどうしましょう。

アプリケーションが配置される本番環境やテスト環境などは厳重なセキュリティで守られているでしょうから、その環境の中に設定値を保存してしまうのがベターだと思います。
つまりアプリケーションとセットで設定値を管理するのではなく、アプリケーションの実行時に実行環境からその環境固有の情報として参照できる方がベターだと思います。
端的に言えば環境変数ですね。

というわけで若干コードを書き換えて、JSON ファイルの設定情報を環境変数から読み込んだ設定値で上書きます。
複数の構成プロバイダーが追加 (AddXXXX) された状態でキー値が重複した場合には、あとから実行したほうが優先されます。
JSONファイルで記載した内容と環境変数でキーがぶつかった場合には、あとから実行された方が優先されます。

```csharp
var config = new ConfigurationBuilder()
    .SetBasePath(AppDomain.CurrentDomain.BaseDirectory)
    .AddJsonFile("setting.json")
    .AddEnvironmentVariables()
    .Build();
```

JSON ファイルで記載した場合にはネスト構造が表現しやすかったですが、環境変数だと一行の文字列で記載しなければなりません。
よって前述と同じようにコロン区切りで環境変数を設定します。
以下のように環境変数を事前に設定しておくことで JSON ファイルの内容に関わらず、環境変数に設定した値が読み取られていることがわかります。

```cmd
> SET ConnectionStrings:SqlConnection1=server=honbanServer;database=pubs;user=sa;password=SECRET!!!
> dotnet run
```

環境変数で設定する際のセクション区切り文字としてコロン（:）ではなくアンダースコア２つ(__)を使用することも可能です。
Linux 上で動作させる場合にはこちらをご利用ください。

```bash
$ export ConnectionStrings__SqlConnection1=server=honbanServer;database=pubs;user=sa;password=SECRET!!!
$ dotnet run
```



## 参考資料など
- [ASP.NET Coreの構成](https://docs.microsoft.com/ja-jp/aspnet/core/fundamentals/configuration/index?tabs=basicconfiguration)
- パッケージ
    - [Microsoft.Extensions.Configuration](https://www.nuget.org/packages/Microsoft.Extensions.Configuration/)
    - [Microsoft.Extensions.Configuration.Json](https://www.nuget.org/packages/Microsoft.Extensions.Configuration.Json/)
    - [Microsoft.Extensions.Configuration.EnvironmentVariables](https://www.nuget.org/packages/Microsoft.Extensions.Configuration.EnvironmentVariables/)
    - [Microsoft.Extensions.Configuration.CommandLine](https://www.nuget.org/packages/Microsoft.Extensions.Configuration.CommandLine/)
    
