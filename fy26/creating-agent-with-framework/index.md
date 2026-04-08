---
layout: default
title: Microsoft Agent Framework で作成する様々な種類のエージェント
---

## はじめに

Microsoft Agent Framework が正式にリリースされ [Version 1.0 になりました](https://devblogs.microsoft.com/agent-framework/microsoft-agent-framework-version-1-0/)。
とはいえ昨今は Agent を作るためのアレコレが非常に多いですよね。
私自身もかなり混乱してしまっています。
というわけで、ちょっと知識の整理にために簡単なエージェントをいろいろ作ってみようと思います。

### Microsoft Agent Framework の参考情報

さて上記はリリースをアナウンスする記事ですが、公開されている情報は以下から得ることができます。

- [Project Website](https://learn.microsoft.com/ja-jp/agent-framework/)
- [Source Repository](https://github.com/microsoft/agent-framework)
- [Nuget Package](https://www.nuget.org/packages/Microsoft.Agents.AI)


Microsoft Agent Framework（長いので以降は MAF と書くことにします）は他のライブラリと似たような形式になっていて、
様々な[プロバイダー](https://learn.microsoft.com/ja-jp/agent-framework/agents/providers/?pivots=programming-language-csharp)に対応しています。
つまり Microsoft Azure や OpenAI を使わなくても（もちろん使っても）エージェントが作れる、という設計になってます。

しかし全パターンを網羅するのは大変なので、以降では私が気になったところをピックアップして試してみようと思います。

## Step 1 : Foundry Local を使用してローカルで動作するエージェント

まずはクラウドのインフラに頼らず、手元の端末で動かすことのできるエージェントを作ってみたいと思います。
必要なのは .NET SDK と MAF のパッケージ [Microsoft.Agents.AI](https://www.nuget.org/packages/Microsoft.Agents.AI)になります。

ローカルで言語モデルを動かすには [Foundry Local](https://learn.microsoft.com/ja-jp/azure/foundry-local/what-is-foundry-local) を使用したいと思います。
MAF 自体はまだ [Foundry Local には対応してない](https://learn.microsoft.com/ja-jp/agent-framework/agents/providers/foundry-local?pivots=programming-language-csharp)ような記載になっていますが、
Foundry Local 自体は [REST API](https://learn.microsoft.com/ja-jp/azure/foundry-local/reference/reference-rest) を提供しており、Chat Completion で対話することができます。
つまり Agent を作ることができるはずです。

### Foundry Local 環境の準備とお試し

まずは Foundry Local を作業端末にインストールします。
Windows PC なら `winget install Microsoft.FoundryLocal` コマンドでインストールできますね。

インストールが終わったら動作確認してみましょう。
例えば `Phi-4-mini` であれば `foundry model run phi-4-mini` のようにモデル名を指定して実行できます。
初回はモデルのダウンロードが走るので時間がかかりますが、
ダウンロードが終われば以下のようにコンソールから対話することができます。

```powershell
Model Phi-4-mini-instruct-generic-cpu:5 was found in the local cache.

Interactive Chat. Enter /? or /help for help.
Press Ctrl+C to cancel generation. Type /exit to leave the chat.

Interactive mode, please enter your prompt

# 起動してプロンプトを入力することで対話が可能です。
> こんにちわ
🧠 Thinking...
🤖 "こんにちわ" (Konnichiwa) は、日本で一般的な挨拶で、"こんにちは" (Konnichiwa) として英語で知られる言葉です。これは昼間の挨拨で、友人や知人に会ったり、日常的なやり取りの中で使用される一般的な挨拶です。
>
```

### Foundry Local のモデルと Chat Completion API で対話する

さて Chat Completion REST API で呼び出してみましょう。
まずは以下のように `foundry service status` コマンドでポートを確認します。
ここではローカルホストのポート `50076` で待機してくれていることが分かります。

```
🟢 Model management service is running on http://127.0.0.1:50076/openai/status
```

Chat Completion API を呼び出すときにモデル名も必要になるのですが、これは `foundry cache list` コマンドで確認できます。
先ほど `foundry model run` で指定したモデル名 `phi-4-mini` は実はエイリアスで、モデルの実態はもう少し長い名前 `Phi-4-mini-instruct-generic-cpu:5` になっていることがわかります。
CPU 用のモデルをダウンロードして動いてたってことですね。

```
Models cached on device:
   Alias                                             Model ID
💾 phi-4-mini                                        Phi-4-mini-instruct-generic-cpu:5
```

これらをもとに HTTP Request を組み立ててあげます。
PowerShell や CURL とかで頑張ってもいいのですが、私は手っ取り早く [Visual Studio Code の REST Client Extension](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) を使用しています。

```http
@port = 50076
POST http://localhost:{{port}}/v1/chat/completions
Content-Type: application/json

{
  "model": "Phi-4-mini-instruct-generic-cpu:5",
  "messages": [
    {
      "role": "system",
      "content": "関西弁でしゃべって"
    },
    {
      "role": "user",
      "content": "こんにちわ"
    }
  ]
}
```

結果は以下のような感じになります。
システム プロンプトで指定したように関西弁ではしゃべってくれてませんでしたが、これは Phi-4-mini の能力的な限界を超えている気がするので、ここは無視して先に進みましょう。

```http
HTTP/1.1 200 OK
Content-Length: 657
Connection: close
Content-Type: application/json
Date: Wed, 08 Apr 2026 05:57:12 GMT
Server: Kestrel

{
  "model": "Phi-4-mini-instruct-generic-cpu:5",
  "choices": [
    {
      "delta": {
        "role": "assistant",
        "content": "こんにちは！何かお手伝いできることはありますか？",
        "tool_calls": []
      },
      "message": {
        "role": "assistant",
        "content": "こんにちは！何かお手伝いできることはありますか？",
        "tool_calls": []
      },
      "index": 0,
      "finish_reason": "stop"
    }
  ],
  "created": 1775627832,
  "CreatedAt": "2026-04-08T05:57:12+00:00",
  "id": "chat.id.47",
  "IsDelta": false,
  "Successful": true,
  "HttpStatusCode": 0,
  "object": "chat.completion"
}
```

### [補足] REST API を使用したキャッシュ済みモデルの確認

ちなみにこのモデルのエイリアスや ID も REST API で確認できます。
```http
@port = 50076
GET http://localhost:{{port}}/openai/models
```
以下のような結果が得られます。

```http
HTTP/1.1 200 OK
Connection: close
Content-Type: application/json; charset=utf-8
Date: Wed, 08 Apr 2026 05:59:10 GMT
Server: Kestrel
Transfer-Encoding: chunked

[
  "Phi-4-mini-instruct-generic-cpu:5",
]
```

### Foundry Local と Chat Completion API で対話する

次にプログラムで Chat Completion 出来ることを確認しておきます。
Chat Completion を呼び出すのは [OpenAI パッケージ](https://www.nuget.org/packages/OpenAI) を使用するのが手っ取り早いです。
ただ、そもそも MAF が OpenAI ベースのエージェントを作成するには [Microsoft.Agents.AI.OpenAI パッケージ](https://www.nuget.org/packages/Microsoft.Agents.AI.OpenAI) が必要なのですが、このパッケージ自体が [OpenAI パッケージ](https://www.nuget.org/packages/OpenAI/) に依存しています。

つまり、[Microsoft.Agents.AI.OpenAI パッケージ](https://www.nuget.org/packages/Microsoft.Agents.AI.OpenAI) を参照しておけば一式そろいそうですね。

というわけで、以下のような [.NET 10 で導入された ファイルベースのアプリ](https://learn.microsoft.com/ja-jp/dotnet/core/sdk/file-based-apps) として作成します。
適当な `.cs` ファイルを用意してあげて、 `dotnet run filename.cs` コマンドで起動できます。

```csharp
#:package Microsoft.Agents.AI.OpenAI@1.0.0

using System.ClientModel;
using OpenAI;

var chatClient = GetChatClient();
var result = await chatClient.CompleteChatAsync("こんにちわ");

Console.WriteLine(result.GetRawResponse().Content.ToString());   

OpenAI.Chat.ChatClient GetChatClient()
{
    var credential = new ApiKeyCredential("dont-need-api-key");
    var option = new OpenAIClientOptions()
    {
        Endpoint = new Uri("http://localhost:50076/v1")
    };
    var openaiClient = new OpenAIClient(credential, option);
    var chatClient = openaiClient.GetChatClient("Phi-4-mini-instruct-generic-cpu:5");

    return chatClient;
}

```

### Microsoft Agent Framework を使用して Foundry Local モデルを使用したエージェントを作成する

準備が長くなりましたが、ここまでくればエージェント作るのはもう一息です。
MAF には `AsAIAgent` という素敵なメソッドが用意されています。
ソースコード リポジトリ で[このメソッド名を検索](https://github.com/search?q=repo%3Amicrosoft%2Fagent-framework+path%3A%2F%5Edotnet%5C%2Fsrc%5C%2F%2F++asaiagent&type=code)
してみてほしいのですが、
様々なプロバイダー向けに拡張メソッドが用意されていることが分かります。

上記のような `OpenAIClient` クラスであれば、`Microsoft.Agents.AI.OpenAI` パッケージに含まれる [OpenAIChatClientExtensions](https://github.com/microsoft/agent-framework/blob/main/dotnet/src/Microsoft.Agents.AI.OpenAI/Extensions/OpenAIChatClientExtensions.cs) クラスに定義されています。

```csharp
// AsAIAgent() のシグネチャ
public static ChatClientAgent AsAIAgent(
        this ChatClient client,
        string? instructions = null, string? name = null, string? description = null, ...
```

ではエージェントを作成して呼び出すアプリを作ってみます。

```csharp
#:package Microsoft.Agents.AI.OpenAI@1.0.0


using System.ClientModel;
using OpenAI;
using OpenAI.Chat;

var chatClient = GetChatClient();
var agent = CreateAgent(chatClient);
Console.WriteLine(await agent.RunAsync("今何時？"));

// OpenAI Chat Completion のクライアントからエージェントを作成する
Microsoft.Agents.AI.AIAgent CreateAgent(ChatClient chatClient)
{
    var agentName = "agent-with-foundry-local-model";
    var instructions = "関西弁でしゃべって";
    return chatClient.AsAIAgent(name: agentName, instructions: instructions);
}

// Fouondry Local を使用して PC 内でホストされている REST API を呼び出すためのクライアントを作成する
OpenAI.Chat.ChatClient GetChatClient()
{
    var credential = new ApiKeyCredential("dont-need-api-key");
    var option = new OpenAIClientOptions()
    {
        Endpoint = new Uri("http://localhost:50076/v1")
    };
    var openaiClient = new OpenAIClient(credential, option);
    var chatClient = openaiClient.GetChatClient("Phi-4-mini-instruct-generic-cpu:5");

    return chatClient;
}
```

結果は以下のようになります。
私は関西にいませんし、Webページでもないのでリンクもありません。
めっちゃハルシネーションを起こしてますが、まあ「エージェントは作れた」ということで・・・
（ちなみに何度も実行してみると、適当な時間を答えてみたり、分からないと答えたりもします）

```
もちろん、関西の時間は現在の時刻に依存します。時刻を知りたい場合は、アラームを鳴らしてください！[時刻を確認するために][時刻の情報を取得するためのリンクをクリックしてください]。今、何をお手伝いしましょうか？
```


## Step 2 : Foundry Models を使用してローカルで動作するエージェントを作成する

前述のようにローカルで動作する SLM では限界があるようであれば、クラウドで動作する LLM を使いたくなることもあるでしょう。
ここでは Microsoft Foundry の Models サービスを機能してホストされている LLM を使用する方法を試してみます。

### Microsoft Foundry Model を使用したエージェントの基本的な作り方

まずは Azure で Foundry リソースとプロジェクトを用意し、モデルをデプロイしておきます。

そしてプログラミングを行うのですが、「最終的に AsAIAgent を使用する」という点は一緒です。
Micorosoft Foundry プロジェクトで作成しているなら 
[AIProjectClientに対する拡張メソッド](https://github.com/microsoft/agent-framework/blob/main/dotnet/src/Microsoft.Agents.AI.Foundry/AzureAIProjectChatClientExtensions.cs) 
を使用するのが手っ取り早いです。
つまり MAF の Foundry プロバイダーを実装している [Microsoft.Agents.AI.Foundry パッケージ](https://www.nuget.org/packages/Microsoft.Agents.AI.Foundry) を追加します。

ソースコードは以下のようになります。
Foundry リソースとの接続には Entra ID 認証を使用して RBAC アクセス制御も有効なので
[Azure.Identity パッケージ](https://www.nuget.org/packages/Azure.Identity)
も追加しておきます。

```csharp
#:package Microsoft.Agents.AI.Foundry@1.0.0
#:package Azure.Identity@1.20.0

using Azure.Identity;
using Azure.AI.Projects;

var projClient = GetFoundryProjectClient();
var agent = CreateAgent(projClient);
Console.WriteLine(await agent.RunAsync("今何時？"));

// ホストされているモデルをベースにエージェントを作成する
Microsoft.Agents.AI.AIAgent CreateAgent(Azure.AI.Projects.AIProjectClient projClient)
{
    var agentName = "agent-with-msfoundry-model";
    var modelDeploymentName = "model-router";
    var instructions = "関西弁でしゃべって";
    return projClient.AsAIAgent( model: modelDeploymentName, name: agentName, instructions: instructions);
}

// Foundry プロジェクトのエンドポイントに接続するクライアントを作成する
Azure.AI.Projects.AIProjectClient GetFoundryProjectClient()
{
    var endpoint = $"https://{foundry}.services.ai.azure.com/api/projects/{project}";
    var credential = new AzureCliCredential();
    var projClient = new AIProjectClient(new Uri(endpoint), credential);

    return projClient;
}
```

実行すると以下のようになります。
流石に LLM だと関西弁では喋ってくれるのですが、まだハルシネーションを起こしてますね・・・

```
今は…ちょっと待ってや、スマホ見たるわ。
（画面を見ながら）あと5分で3時やで。
```

### [補足] Microsoft Foundry に登録されていない野良エージェント

先ほど作ったエージェントなのですが、Foundry Portal (https://ai.azure.com) を参照するとエージェントとしては管理されていないことがわかります。
クラウド上の Microsoft Foundry を使用していますが、あくまでもそこでホストされているモデルを使用しているだけの「野良エージェント」という位置づけになります。

![alt text](./images/no-agent-in-msfoundry.png)

### [補足] AI Foundry SDK を使用しないパターン

先ほどは Azure AI Foundry SDK の一部である [Azure.AI.Projects パッケージ](https://www.nuget.org/packages/Azure.AI.Projects/) に含まれる
`AIProjectClient` クラスを使用していました。
これはアプリケーションが Microsoft Foundry 用の MAF 拡張である [Microsoft.Agents.AI.Foundry パッケージ](https://www.nuget.org/packages/Microsoft.Agents.AI.Foundry) を使用していたため、その依存関係として使えるようになっていたものです。

とはいえ、Foundry に強く依存したくない（別のサービスと切り替えたい）というケースもあるでしょう。
その場合は以下の2方針が考えられます。

- OpenAI ライブラリを使用して互換サービスを利用する
  - 先ほど Foundry Local の例で見た通り、Chat Completion のような OpenAI プロトコルであれば OpenAI のライブラリが利用できます。
  - 先ほどの例であれば接続先の URL や認証情報を書き換えてあげればよいでしょう。
  - Microsoft Foundry モデルも OpenAI 用のエンドポイント https://{foundry}.openai.azure.com を利用可能です。
- [Microsoft.Extensions.AI](https://www.nuget.org/packages/Microsoft.Extensions.AI) を使用してサービスを抽象化する
  - MAF は内部的にこの `Microsoft.Extensions.AI` パッケージを使用しており、抽象インタフェースとして [IChatClient](https://github.com/dotnet/extensions/blob/main/src/Libraries/Microsoft.Extensions.AI.Abstractions/ChatCompletion/IChatClient.cs) が定義されています。
  - MAF ではその `IChatClient` の拡張メソッド [AsAiAgent](https://github.com/microsoft/agent-framework/blob/main/dotnet/src/Microsoft.Agents.AI/ChatClient/ChatClientExtensions.cs) が提供されていますので、こちらを使用してエージェントを作成します。

### ローカルで動作するツールを追加する

いい加減ハルシネーションを起こされても困るので、時間を確認するためのツールを追加してみましょう。
ツールの定義およびエージェントへの組み込みは以下のようになります。

```csharp
// エージェントへのツールの組み込み
Microsoft.Agents.AI.AIAgent CreateAgent(Azure.AI.Projects.AIProjectClient projClient)
{
    var agentName = "agent-with-msfoundry-model";
    var modelDeploymentName = "model-router";
    var instructions = "関西弁でしゃべって";
    return projClient.AsAIAgent( 
        model: modelDeploymentName, name: agentName, instructions: instructions,
        tools: [
            AIFunctionFactory.Create(GetCurrentTime)
        ]);
}

// ツールの定義
[Description("Get the current time in a specific format.")]
string GetCurrentTime()
{
    Console.WriteLine("-- calling my tool --");
    return string.Format("現在時刻は {0:yyyy-MM-dd HH:mm:ss} です", DateTime.Now);
}
```

同じように「今何時？」と聞いてみると、以下のように正しく時間を返してくれるようになります。
また外部から呼ぶことのできないツールが動作していることからも、エージェントはローカルで動いていることがわかりますね。

```csharp
-- calling my tool --
おおきに！今の時刻は2026年4月8日18時10分49秒やで。何か他に手伝えることある？
```


## Step 3 : ASP.NET でエージェントを提供する

ここまでは Console アプリケーションとしてエージェントを作ってきましたが、折角なので作成したエージェントを広く使ってもらいたくもなるでしょう。
このような状況では Web アプリケーションで UI を提供するか、API を提供して他のサービスやツールに組み込んでもらうことになります。

### ASP.NET Core WebAPI にエージェントを組み込む

先ほど作成した Microsoft Foundry モデルを使用したエージェントを ASP.NET Core WebAPI に組み込んでみましょう。

```csharp
#:sdk Microsoft.NET.Sdk.Web
#:package Azure.Identity@1.20.0
#:package Microsoft.Agents.AI.Foundry@1.0.0
#:property PublishAot=false

using System.ComponentModel;
using Azure.AI.Projects;
using Azure.Identity;
using Microsoft.Agents.AI;
using Microsoft.Extensions.AI;

// ASP.NET のホストを作成
var builder = WebApplication.CreateBuilder(args);

// AIProjectClient を DI サービスに追加
builder.Services.AddSingleton<AIProjectClient>(sp => {
    var endpoint = $"https://{foundry}.services.ai.azure.com/api/projects/{project}";
    var credential = new AzureCliCredential();
    var projClient = new AIProjectClient(new Uri(endpoint), credential);
    return projClient;  
});

// AIProjectClient から作った Agent を DI サービスに追加
builder.Services.AddSingleton<AIAgent>(sp => {
    var projClient = sp.GetRequiredService<AIProjectClient>();
    var agentName = "agent-run-on-local-aspnet";
    var modelname = "model-router";
    var inst = "関西弁でしゃべって";
    var agent = projClient.AsAIAgent(
        name: agentName,
        model: modelname,
        instructions: inst,
        tools: [
            AIFunctionFactory.Create(GetCurrentTime),
        ]);

    return agent;
});

var app = builder.Build();

// 特定のエンドポイント上で Agent を使用するロジックを実装
app.MapGet("/", async (AIAgent agent) => {
    return await agent.RunAsync("今何時？");
});

await app.RunAsync();

[Description("Get the current time in a specific format.")]
static string GetCurrentTime()
{
    return DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss.fff");
}
```

これを実行してホストされた http://localhost:5000 をブラウザ等で開くと以下のような回答が返ってきます。

```json
{
  "messages": [
    {
      "authorName": "agent-run-on-local-aspnet",
      "createdAt": "2026-04-08T09:21:14+00:00",
      "role": "assistant",
      "contents": [
        {
          "$type": "functionCall",
          "name": "_Main_g_GetCurrentTime_0_3",
          "arguments": {},
          "informationalOnly": true,
          "callId": "call_55auLbyVN012HS6U8WGD4JQ6",
          "annotations": null,
          "additionalProperties": null
        }
      ],
      "messageId": null,
      "additionalProperties": null
    },
    {
      "authorName": "agent-run-on-local-aspnet",
      "createdAt": null,
      "role": "tool",
      "contents": [
        {
          "$type": "functionResult",
          "result": "2026-04-08 18:21:16.805",
          "callId": "call_55auLbyVN012HS6U8WGD4JQ6",
          "annotations": null,
          "additionalProperties": null
        }
      ],
      "messageId": null,
      "additionalProperties": null
    },
    {
      "authorName": "agent-run-on-local-aspnet",
      "createdAt": "2026-04-08T09:21:19+00:00",
      "role": "assistant",
      "contents": [
        {
          "$type": "text",
          "text": "今は18時21分16秒やで～。",
          "annotations": null,
          "additionalProperties": null
        }
      ],
      "messageId": "msg_02d85509547fde290069d61e12bfe48194801b10a0575de30c",
      "additionalProperties": null
    }
  ],
  "agentId": "39e47771d22444b18db2b12b543af7b9",
  "responseId": "resp_02d85509547fde290069d61e0f831081949d466844393cb073",
  "continuationToken": null,
  "createdAt": "2026-04-08T09:21:19+00:00",
  "finishReason": null,
  "usage": {
    "inputTokenCount": 192,
    "outputTokenCount": 696,
    "totalTokenCount": 888,
    "cachedInputTokenCount": 0,
    "reasoningTokenCount": 320,
    "additionalCounts": null
  },
  "additionalProperties": null
}
```

先ほどまでは標準出力に最終メッセージだけが表示されていましたが、Agent の `RunAsync` の戻り値のオブジェクトは `ToString` がオーバーライドされていて最終メッセージだけになっていたものと考えられます。
今回のコードでは ASP.NET Core Web API で返すと JSON にシリアライズされて、エージェントの応答全てが確認できている、ということですね。
