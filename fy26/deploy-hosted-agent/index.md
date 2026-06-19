---
layout: default
title: Microsoft Foundry に Hosted Agent だけをデプロイする
---

## はじめに

Microsoft Build 2026 前後で Microsoft Foundry の [Hosted Agent](https://learn.microsoft.com/ja-jp/azure/foundry/agents/concepts/hosted-agents) が新しくなりましたね。
実際にこれを利用する方法としては [クイックスタート](https://learn.microsoft.com/ja-jp/azure/foundry/agents/quickstarts/quickstart-hosted-agent?pivots=azd) を辿っていけばいいのですが、
試していていくつか違和感というかやりにくさを感じました。
端的に言えば `Azure Developer CLI` や `Visual Studio Code Foundry Toolkit Extension` がかなりスキャフォールドしてくれたり自動化してくれたりするので、「楽ではあるけど何やってるか良くわからないし、実際の開発に組み込むときに工夫がいるのでは？」と感じました。

というわけで、自分なりに [Microsoft Agent Framework](https://learn.microsoft.com/ja-jp/agent-framework/overview/?pivots=programming-language-csharp) を使用して C# でエージェントを開発し、
Microsoft Foundry にコンテナとしてデプロイする一連の流れを整理してみようと思ったといいます。
リリースされたとはいえ Preview なものも多々含まれるので、まだまだ変わりそうだなあとも思うのですが・・・

## エージェント開発からデプロイまでの一連の流れ

### 前提条件

まず、作業開始の前に以下を前提条件として考えています。
実プロジェクトではインフラ側とアプリ側は割と役割が分離していることが多く、`azd up` で一発デプロイとか無いんじゃないかなと思うんですよね。

- Microsoft Foundry や Project はすでに作成されている
- Azure Container Registry はすでに作成されている
- この環境に Hosted Agent をデプロイしたい
- エージェント開発には .NET 10 と Microsoft Agent Framework を使用する

### まずはエージェントを作ろう

早速エージェントを開発していくのですが、エージェントの中身は本題ではないので、ここでは簡単に作っていきます。

```pwsh
# 開発のルートを作って移動（ GitHub 等でソース管理するワークスペースのルート）
mkdir hosted-agent-sample && cd hosted-agent-sample

# ソースコードを配置するディレクトリを作って移動
mkdir src && cd src

# Console プロジェクトを作成して
dotnet new console -o agent001 && cd agent001

# 必要なパッケージを追加
dotnet add package Azure.AI.Projects --prerelease
dotnet add package Microsoft.Agents.AI.Foundry.Hosting --prerelease
```

C# のプロジェクトができるので、エージェントのコードを作成していきます。
基本的には通常のエージェント開発ではあるのですが、後々に Hosted Agent にデプロイすることを考慮したコードにしておきます。

- Foundry プロジェクトのエンドポイントやモデルデプロイ名は `Microsoft.Extensions.Configuration` を使用して取得する
    - 開発時には `appsettings.json` 等の **構成ファイル** から取得する
    - テストや本番展開では **環境変数** から取得して構成ファイルの値を上書きする
- Hosted Agent の環境では既定で挿入される環境変数に名前をそろえる
    - ここでは プロジェクト エンドポイント `FOUNDRY_PROJECT_ENDPOINT` や Application Insights の接続文字列 `APPLICATIONINSIGHTS_CONNECTION_STRING` が該当する
    - それ以外の [プラットフォームによって挿入される環境変数](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/deploy-hosted-agent#platform-injected-environment-variables) は公式ドキュメントを参照
- Foundry Models サービスと通信する際のクレデンシャルを設定しておく
    - 開発環境では Azure CLI を使用して `az login` した際のクレデンシャル（＝自分のユーザー ID） を使用する
    - テストや本番環境では Managed ID を使用する（＝ Foundry プロジェクトに割り当てられる Managed ID）
    - どちらのクレデンシャルにも [`Foundry User` RBAC ロールが割り当てられている](https://learn.microsoft.com/ja-jp/azure/foundry/concepts/rbac-foundry?tabs=owner) ものとする

```csharp
using Microsoft.Extensions.Configuration;
using Azure.Identity;
using Azure.AI.Projects;
using Microsoft.Agents.AI;
using Microsoft.Agents.AI.Foundry.Hosting;

// 構成を取得する
var config = new ConfigurationBuilder()
    .SetBasePath(AppDomain.CurrentDomain.BaseDirectory)
    .AddJsonFile("appsettings.json", optional: false)   // 開発用の設定値を構成ファイルから取得
    .AddEnvironmentVariables()                          // テストや本番環境では環境変数で上書き
    .Build();

// Foundry Hosted Agent 環境でプラットフォームから挿入される環境変数と名前を合わせておく
var projectEndpoint = new Uri(config["FOUNDRY_PROJECT_ENDPOINT"]!);
var appInsightConstr = config["APPLICATIONINSIGHTS_CONNECTION_STRING"]!;

// その他の設定値も構成から取得（テストや本番環境では明示的に設定する必要がある）
var agentModelName = config["MY_MODEL_DEPLOYMENT_NAME"]!;

// モデルと通信するためのクレデンシャル
var credential = new ChainedTokenCredential(
    new AzureCliCredential(),                                           // 開発環境では自分のユーザーアカウント
    new ManagedIdentityCredential(ManagedIdentityId.SystemAssigned));   // テストや本番環境ではプロジェクトの Managed ID

var projClient = new AIProjectClient(projectEndpoint, credential);
var agent = projClient.AsAIAgent(
    model: agentModelName, instructions: "You are a helpful assistant.");

// エージェントが正しく動くか動作確認しておく
var response = await agent.RunAsync("Hello");
Console.WriteLine(response.Text);
```

開発環境での動作に必要なパラメタを構成ファイルに切り出しておきます。
これらの値はテスト環境や本番環境では **環境変数** の値で上書きされますので、あくまでもローカル開発で使用できる値を使用します。
```json
// appsettings.json ファイルを追加
{
    "FOUNDRY_PROJECT_ENDPOINT": "https://foundryName.services.ai.azure.com/api/projects/projectName",
    "APPLICATIONINSIGHTS_CONNECTION_STRING": "InstrumentationKey=xxxx;IngestionEndpoint=https://yyyy.in.applicationinsights.azure.com/;LiveEndpoint=https://zzzz.livediagnostics.monitor.azure.com/;ApplicationId=wwww",
    "MY_MODEL_DEPLOYMENT_NAME": "gpt-4.1-mini"
}
```

構成ファイルをアプリケーションのビルドと同時に実行ディレクトリにコピーしてあげます。

```xml
<!-- xxxx.csproj ファイルで構成ファイルを実行ディレクトリにコピーする設定を行う-->
<Project>
  <ItemGroup>
      <None Update="appsettings.json">
          <CopyToOutputDirectory>Always</CopyToOutputDirectory>
      </None>
  </ItemGroup>
</Project>
```

この状態で `dotnet run` してエージェントが動くことを確認しておきましょう。

### Hosted Agent 環境にデプロイするための準備

Microsoft Agent Framework で作成したエージェントを、Foundry の Hosted Agent としてデプロイするためのホストを作成していきます。
最初の準備段階で [`Microsoft.Agents.AI.Foundry.Hosting` パッケージ](https://www.nuget.org/packages/Microsoft.Agents.AI.Foundry.Hosting/1.10.0-preview.260610.1) を参照していますので、ここはサクッと終わります。

```csharp
// 動作確認用のコードを削除して
// var response = await agent.RunAsync("Hello");
// Console.WriteLine(response.Text);

// エージェントをホストして実行
var builder = AgentHost.CreateBuilder(args);
builder.Services.AddFoundryResponses(agent);
builder.RegisterProtocol("responses", endpoints => endpoints.MapFoundryResponses());

var agentHost = builder.Build();
await agentHost.RunAsync();
```

このコードを `dotnet run` で実行すると、開発したエージェントと `Responses API` で対話することが可能ですので、動作確認しておきましょう。

```http
POST http://localhost:8088/responses
Content-Type: application/json
x-agent-user-isolation-key: local-dev-user
x-agent-chat-isolation-key: local-dev-chat

{
    "input" : "hello"
}
```

通常の Responses API だと必須ではなさそうなのですが、今回使用したバージョンのライブラリ `Microsoft.Agents.AI.Foundry.Hosting, 1.10.0-preview.260610.1` では `x-agent-user-isolation-key` や `x-agent-chat-isolation-key` ヘッダーをつけてやらないとエラーになります。


### コンテナ化する準備

Hosted Agent にはコンテナとしてデプロイするので、以下のような Dockerfile を作成しておきます。

```Dockerfile
FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine AS build
WORKDIR /src
COPY . .
RUN dotnet restore
RUN dotnet build -c Release --no-restore
RUN dotnet publish -c Release --no-build -o /app

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine AS final
WORKDIR /app
COPY --from=build /app .
EXPOSE 8088
ENTRYPOINT ["dotnet", "agent001.dll"]
```

ちなみに Dockerfile の作成を飛ばして、[ソースやアプリを zip で固めてデプロイする](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/deploy-hosted-agent-code?tabs=csharp) ことも出来ます。


### Azure Developer CLI でデプロイする

さて準備が整ったので、ここでは `azd` を使用してエージェントを Foundry にデプロイしていきましょう。

まず azd 環境を作成します（ここで作成される azure.yaml はほぼ空の状態です）

```pwsh
# azd init --environment environmentName `
    --location azure-location `
    --subscription your-subscription-guid `
    --minimal

```
```
# 次に エージェント用に
azd ai agent init --agent-name agent001 `
    --deploy-mode container `
    --project-id /subscriptions/4aa14492-4d02-4830-81b9-df159fa056db/resourceGroups/rg-demo0615a/providers/Microsoft.CognitiveServices/accounts/msfdr-demo0615a/projects/proj-default `
    --protocol responses `
    --src ./src/agent001 
```

