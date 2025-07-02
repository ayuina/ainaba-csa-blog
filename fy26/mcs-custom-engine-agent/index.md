---
layout: default
title: カスタム エンジン エージェントを Microsoft 365 Copilot に公開する
---

## はじめに

[前回の記事](../mcs2mcp-basic/) では、 Azure 上に構築した MCP サーバーを、 Microsoft Copilot Studio を使用して作成した宣言型エージェントから利用する方法を紹介しました。
エージェントが特定の役割を持つのではなく、ツールを与えることで様々な振る舞いをする、という目的は果たすことができたのですが、
個人的にはいまいち不完全燃焼な部分がありました。

- エージェントの動作確認が Copilot Studio の Web UI からしか出来ないので若干面倒
- オーケストレーターとして使用する LLM が選択できない（GPT-4o）
- 直接 LLM に対してプロンプトを与えた場合と挙動が異なる

だったらエージェントも独自開発しちゃえばいいじゃん、でもフロントエンドに M365 Copilot は使いたいなあ、という悩みがありました。
で、調べていたところ、Microsoft 365 Copilot SDK を使用すると独自作成したエージェントを持ち込むことが出来るようです。

つまりこういうことがしたい。

![alt text](./images/overview.png)

これまで苦労して開発してきた AI アプリやエージェント、なるべくそのまま Copilot のエージェント ストアに出すことができれば皆に使ってもらいやすくなるのでは。

![alt text](./images/cea-in-agent-store.png)

### 参考情報

本記事を書くにあたって参考にした資料群は以下になります。

- [Bring your agents into Microsoft 365 Copilot](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/bring-agents-to-copilot)
- [Adding a Custom Engine Agent to Microsoft 365 Copilot Chat](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/m365-agents-sdk)

## カスタム エージェント作成して Copilot に公開するまで

基本的には上記の参考情報をなぞっていく形になりますが、大まかな流れとしては以下のようになります。

1. 開発環境を準備する
1. プロジェクト テンプレートをカスタマイズ
1. エージェントのローカルでデバッグ
1. Azure Bot Service を作成して連携する
1. M365 Copilot のエージェントストアに公開する

Copilot のエージェント ストアに公開したいわけですが、作るものが Teams アプリなんですねえ・・・

### 開発環境を準備する

[M365 Copilot SDK](https://learn.microsoft.com/en-us/microsoft-365-copilot/extensibility/m365-agents-sdk) 
のドキュメントを見ると、C#、JavaScript、Python に対応しているようです。
ここは私の愛する C# で行きたいと思います。

開発には Agent Toolkit がオススメされていたので素直にそちらをインストールします。
どこかからダウンロードしてくるわけではなく、Visual Studio Installer の中でコンポーネントを追加してやります。

![alt text](./images/setup-agent-toolkit.png)

### プロジェクト テンプレート

プロジェクトの新規作成から `agent` などで検索すると、下図のように Teams アプリが見つかるので、これを使用します。

![alt text](./images/teams-app-project.png)

テンプレートがいくつか選択できますが、`Custom Engine Agent` タグが付いているモノ、ここでは `Weather Agent` を選択します。
このテンプレートは途中で Azure OpenAI のエンドポイントを入力する箇所が出てきますので、新規作成するなり既存のものを流用するなりしてください。
とりあえずは挙動確認がしたいので、無難に GPT-4o あたりがいいでしょうか。

![alt text](./images/weather-agent-project-template.png)

作成すると以下のような２プロジェクト構成のソリューションが出来上がります。

- **M365Agent プロジェクト** : Teams アプリとしてデプロイするためのメタデータや、ローカル デバッグ時のエミュレータのための設定などが入ってます
- **作成時した プロジェクト** : こちらは普通の ASP.NET Core Web API ですが、Azure Bot Service と接続するための構成が出来上がっています

![alt text](./images/weather-agent-solution.png)

ここで簡単にプロジェクト テンプレートで作成されたコードを確認しておきましょう。

#### 利用している nuget パッケージ

まずは参照しているパッケージを確認すると、M365 Agent SDK っぽい名前 `Microsoft.Agents.*` と Semantic Kernal のパッケージ`Microsoft.SemanticKernel` が含まれていることが分かりますね。

- Azure.Identity
- AdaptiveCards
- Microsoft.SemanticKernel.Agents.AzureAI
- Microsoft.SemanticKernel.Agents.Core
- Microsoft.SemanticKernel.Connectors.AzureOpenAI
- Microsoft.SemanticKernel.Connectors.OpenAI
- Microsoft.Agents.Authentication.Msal
- Microsoft.Agents.Hosting.AspNetCore

ドキュメントには以下のようにありました。
つまり、会話は LLM に委ねられていて、その制御には Semantic Kernel が利用されている、ということでしょうか。

> Microsoft 365 Agents SDK は、Azure Bot Framework SDK の進化形です。Azure Bot Framework は、以前は、開発者がトピック、ダイアログ、メッセージに関する会話型 AI に重点を置いたボットを構築する方法でした。現在、業界の標準は、企業全体にある知識に基づいたジェネレーティブAI機能を使用することです。企業は、会話型エクスペリエンス内からアクションを調整し、質問に答えることができる必要があります。Microsoft 365 Agents SDK は、会話型エージェントの作成と会話管理およびオーケストレーションをまとめた、最新のエージェント開発のための機能を提供します。SDK を使用して構築されたエージェントは、Microsoft 以外のソフトウェアまたはテクノロジで作成されたエージェントを含む、多数の AI サービスやクライアントに接続できます。

#### スタートアップ コード

次にスタートアップコード `Program.cs` を見ていきましょう。
かなり長いので、重要そうなところだけ抜き出すと以下のような感じでしょうか。

```csharp
// 通常の ASP.NET Core アプリと同じ
var builder = WebApplication.CreateBuilder(args);

// Semantic Kernel の登録
builder.Services.AddKernel();

// プロジェクト作成時に入力した Azure OpenAI のパラメータを構成ファイル(apsettings.xxxx.json)から読み込んで登録
builder.Services.AddAzureOpenAIChatCompletion(
    deploymentName: config.Azure.OpenAIDeploymentName,
    endpoint: config.Azure.OpenAIEndpoint,
    apiKey: config.Azure.OpenAIApiKey
);

// これが AI Agent の実態になる部分を登録
builder.Services.AddTransient<WeatherForecastAgent>();

// Azure Bot Service からインバウンド通信が入る時の認可処理を登録
builder.Services.AddBotAspNetAuthentication(builder.Configuration);

// Azure Bot Service と通信するシーケンスを司る部分を登録
builder.AddAgentApplicationOptions();
builder.Services.AddTransient<AgentApplicationOptions>();
builder.AddAgent<MyM365Agent0702.Bot.WeatherAgentBot>();

var app = builder.Build();

// Azure Bot Service からインバウンド通信が入る時ルート /api/messages を登録
// IAgentHttpAdapter を使用して IAgent に中継する
app.MapPost("/api/messages", async (HttpRequest request, HttpResponse response, IAgentHttpAdapter adapter, IAgent agent, CancellationToken cancellationToken) =>
{
    await adapter.ProcessAsync(request, response, agent, cancellationToken);
});

app.Run();
```

API としてのルートは１つしか構成されておらず、それは全て `IAgent` に中継されています。 
ここでは `AddAgent` されている `WeatherAgentBot` がその実装になるわけです。 
あとは各種設定ファイルを書き換えてやれば良さそうですね。

#### IAgent インタフェースの実装

では `WeatherAgentBot` クラスを見てみましょう。
ここも全体像が分かるようにかなり抜粋していますので、詳細は実際に生成されるコードを参照してください。

```csharp
// IAgent インタフェースを実装した AgentApplication クラスを継承している
public class WeatherAgentBot : AgentApplication
{
    public WeatherAgentBot(AgentApplicationOptions options) : base(options)
    {
        // イベントを処理するデリゲートを登録しているところ
        OnConversationUpdate(ConversationUpdateEvents.MembersAdded, WelcomeMessageAsync);
        OnActivity(ActivityTypes.Message, MessageActivityAsync, rank: RouteRank.Last);
    }

    // 会話に人が参加されたときの処理
    protected async Task WelcomeMessageAsync(ITurnContext turnContext, ITurnState turnState, CancellationToken cancellationToken)
    {
        // 最初の挨拶を送信する処理
        await turnContext.SendActivityAsync(
            MessageFactory.Text("Hello and Welcome! I'm here to help with all your weather forecast needs!"), cancellationToken);
    }

    // メッセージの着信、つまりユーザーの発話に対する処理を行う
    protected async Task MessageActivityAsync(ITurnContext turnContext, ITurnState turnState, CancellationToken cancellationToken)
    {
        // Azure Bot Service に入力中であることを送信
        await turnContext.StreamingResponse.QueueInformativeUpdateAsync("Working on a response for you");

        // AI エージェントの実態になる WeatherForecastAgent に処理を転送
        _weatherAgent = new WeatherForecastAgent(_kernel, serviceCollection.BuildServiceProvider());
        WeatherForecastAgentResponse forecastResponse = await _weatherAgent.InvokeAgentAsync(turnContext.Activity.Text, chatHistory);

        // Azure Bot Service に Text ないしは Adaptive Card を送信
        switch (forecastResponse.ContentType)
        {
            case WeatherForecastAgentResponseContentType.Text:
                turnContext.StreamingResponse.QueueTextChunk(forecastResponse.Content);
                break;
            case WeatherForecastAgentResponseContentType.AdaptiveCard:
                turnContext.StreamingResponse.FinalMessage = MessageFactory.Attachment(new Attachment()
                {
                    ContentType = "application/vnd.microsoft.card.adaptive",
                    Content = forecastResponse.Content,
                });
                break;
            default:
                break;
        }

        // Streaming の終了を送信
        await turnContext.StreamingResponse.EndStreamAsync(cancellationToken); // End the streaming response
    }
}
```

大まかに言えば以下のようになるのではないでしょうか。

- 初期化時に OnXXXX メソッドを使用してこのエージェントが対応するイベントのハンドラを登録
- `turnContext` に対して処理を行うことで、エージェントの返信を行うことが出来そう
- `StreamingRepons` に対して `Queue` を入れることで非同期的に返信（同期処理でブロックしない）

#### Agent の実態

では Agent 本体になる部分です。

```csharp
// ごく普通のクラス
public class WeatherForecastAgent
{
    // Semantic Kernel の ChatCompletionAgent
    private readonly ChatCompletionAgent _agent;

    // Agent の名前とプロンプト
    private const string AgentName = "WeatherForecastAgent";
    private const string AgentInstructions = """
        You are a friendly assistant that helps people find a weather forecast for a given time and place.
        ...
        """;

    // 前述の WeatherAgentBot から初期化に使用しているコンストラクタ
    public WeatherForecastAgent(Kernel kernel, IServiceProvider service)
    {
        _kernel = kernel;

        // Semantic Kernel の ChatCompletionAgent を作成
        _agent = new() {...}
    }

    // 前述の WeatherAgentBot から呼び出されている部分
    public async Task<WeatherForecastAgentResponse> InvokeAgentAsync(string input, ChatHistory chatHistory)
    {
        // 会話履歴を復元して Semantic Kernel の ChatCompletionAgent を呼び出し
        await foreach (ChatMessageContent response in this._agent.InvokeAsync(chatHistory, thread: thread))
        { 
            ...        
        }
        // 結果を返す
        return result;
    }
}
```

見てみると基本的には [Semantic Kernal ChatCompletionAgent](https://learn.microsoft.com/ja-jp/semantic-kernel/frameworks/agent/agent-types/chat-completion-agent?pivots=programming-language-csharp) に中継しているだけですね。
なので、Bot としてはここは本質ではなく、自由に使って良いところでしょう。
`WeatherAgentBot` に直接実装しても良さそうですが、このように実装を分離しておく方が何かと都合が良いでしょう。
もし既存の AI エージェントのコードがあるなら、`IAgent` の実装で再利用する形になるんだと思います。

### エージェントのローカル デバッグ

さて、そろそろ動かしてみたいところですね。
Visual Studio なので F5 でデバッグ実行するだけなのですが、一応構成を確認しておきましょう。

![alt text](./images/multi-startup-project-config.png)

このソリューションはマルチ スタートアップ プロジェクトになっていて、先ほどソースコードを解説していた ASP.NET Core 部分をデバッグ実行しつつ、
もう１つのプロジェクトの方で Agent Playground を起動してくれるようです。
選択している構成を確認しつつ デバッグ開始です。

![alt text](./images/debug-with-agent-playground.png)

Playground の起動を確認して話しかけると、デバッグ実行されている方の ASP.NET Core プロジェクトの標準出力にログが確認できます。
このログもかなり抜粋していますが、Semantic Kernel に追加したプラグインを使用して現在日付を取得したり、天気予報を取得したり、その結果を LLM でまとめたりしている雰囲気が分かります。

![alt text](./images/chat-with-playground.png)

### Azure Bot Service を作成して連携する

Bot Service つくる
Service Principal の情報を Config に
トンネルを掘る
Bot Service の Web チャットで動作確認

### Copilot のエージェントストアに公開

Azure Bot Service の Teams チャネルを構成する
Teams アプリのマニフェストをアップロード
利用してみる

