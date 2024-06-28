---
layout: default
title: Azure API Management 経由で Azure OpenAI Service を呼び出すパターン
---

# 概要

以前に [Azure OpenAI Service を API Management 経由で呼び出す構成を自動化する](../landing-pages/apim-aoai-sample/) という記事を書いたのですが、
Microsoft Build 2024 およびその前後の機能アップデートで API Management も大分機能強化が行われました。
現在でも OpenAI を呼び出す際に前段に API Management を挟みたいユースケースというのは変わらずあるのですが、
出来ることが増え、同じことを実現するにも大分楽になってきた印象ですので、ここで新しい記事として書き起こすことにしました。

# APIM が AOAI を呼び出すだけのシンプルなパターン

この先でいくつかのパターンを紹介していくのですが、その際には以下のアーキテクチャを拡張していく形をとります。
API Management の Managed ID を有効にして、Azure OpenAI へはキーを使用せずにアクセスできるようにしつつ、動作確認のためのログ設定をしたものになります。

![architecture basis](./images/architecture-basis.png)

まずは Log Analytics, Application Insights, API Management を作成してログ周りを設定しておきます。
API Management のログ設定まわりは下記をご参照ください。

- [Azure API Management の監視](https://learn.microsoft.com/ja-jp/azure/api-management/observability)
- [Azure API Management のログや監視にまつわるアレコレ](../monitoring-api-management/)

Managed ID + RBAC の設定周りは下記を参考にしてください。

- [Azure API Management でマネージド ID を使用する](https://learn.microsoft.com/ja-jp/azure/api-management/api-management-howto-use-managed-service-identity)
- [Azure OpenAI Service のロールベースのアクセス制御](https://learn.microsoft.com/ja-jp/azure/ai-services/openai/how-to/role-based-access-control)
- [API Management ID を使用してバックエンドに対する認証を行う](https://learn.microsoft.com/ja-jp/azure/api-management/authentication-managed-identity-policy)


## API Management を Azure OpenAI 互換の API に仕立て上げる

API Management の API 定義は OpenAPI 仕様が利用できますので、
従来は [Azure OpenAI Rest API 仕様](https://learn.microsoft.com/ja-jp/azure/ai-services/openai/reference) をダウンロードして若干のカスタマイズを行って登録していたのですが、
現在は [Azure Portal から簡単に登録することができる](https://learn.microsoft.com/ja-jp/azure/api-management/azure-openai-api-from-specification)
ようになりました。
適当な Azure OpenAI サービスアカウントとモデルをデプロイして、Azure Portal からインポートしていきます。

![create-api-from-aoai](./images/create-api-from-aoai.png)

|インポート画面|インポート結果|
|---|---|
|![alt text](./images/import-aoai-config.png)|![alt text](./images/apim-aoai-imported.png)
|

ドキュメントにも説明がありますが、上図の通りデプロイ済みの Azure OpenAI サービスを指定してインポートする場合には下記の設定が行われます。

- 各 Azure OpenAI REST API エンドポイントの操作が登録される
- Azure OpenAI リソースにアクセスするために必要なアクセス許可が与えられたシステム割り当て ID が設定される
- API 要求を Azure OpenAI Service エンドポイントに送信するバックエンド リソースと set-backend-service ポリシーが設定される
- インスタンスのシステム割り当て ID を使用して Azure OpenAI リソースに対して認証できる authentication-managed-identity ポリシーが設定される


なのですが、ここでいきなりいくつか問題が見えてきます。
問題というか、どこまで気にする必要があるか？というレベルではあるのですが・・・

### 選択できる api-version が非常に限定的

本記事執筆段階では `2022-12-01`, `2023-05-15`, `2024-0201`, `2024-02-01`, `2024-03-01-preview` の 4つしか選択できませんでした。
これ以外のバージョンを登録したい場合は上記の REST API リファレンスから OpenAI 定義をダウンロードしてきて登録してください。
前述のドキュメントにも詳細な手順の説明が記載されています。

> 既定の設定では API Management は api-version やペイロードとなる JSON のフォーマットをチェックしているわけではありません。
> このため単に呼び出すだけならクライアントから別バージョンを呼び出してしまっても動作します。
> ちょっと気持ち悪いですけど・・・

### 全てのオペレーションがインポートされてしまう

インポートされた API 定義を見ていくと、指定した OpenAI および モデルのデプロイメントなどは全く考慮せずに、全ての Operation が定義されていることがわかります。
例えば Azure OpenAI に `gpt-4` モデルの `turbo-2024-04-09` バージョンのみをデプロイしていたとしても、
対応している `Chat Completion` のみならず、 `Completion` や `Embedding` なども API Management に登録されてしまうということです。
当然ながら API Management に対してこれらの操作を呼び出したとしても、転送されたバックエンド側モデルはそんな操作に対応していないのでエラーになります。

このためクライアントに提供する予定のない Operation は削除してしまうか、
以下のように [return-response ポリシー](https://learn.microsoft.com/ja-jp/azure/api-management/return-response-policy)
を使用することで、バックエンドに転送することなく API Management の段階で折り返してしまうとよいでしょう。

まず `All operations` レベルの `inbound` ポリシーでエラー応答を返すように設定し、これを既定の挙動とします。

```xml
<!-- Import 直後の状態 -->
<inbound>
    <set-backend-service id="apim-generated-policy" backend-id="openai-wrapper-openai-endpoint" />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com/" />
    <base />
</inbound>
<!-- 既定ではエラーで折り返す -->
<inbound>
    <inbound>
        <return-response>
            <set-status code="400" reason="Bad Request" />
            <set-body>{
            "error": {
                "code": "OperationNotSupported",
                "message": "Your request operation is not supported"
            }
        }</set-body>
        </return-response>
    </inbound>
</inbound>
```

次にバックエンドに転送してよい Operation、例えば GPT 3.5 Turbo モデルがデプロイされているようであれば Chat Completion Operation のみの `inbound` ポリシーで以下のように設定します。

```xml
<!-- Import 直後の状態 -->
<inbound>
    <base />
</inbound>
<!-- この Operation のみを転送する -->
<inbound>
    <set-backend-service id="apim-generated-policy" backend-id="openai-wrapper-openai-endpoint" />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com/" />
</inbound>
```

## API Management ログの確認

さて Application Insights のログを設定して動作確認をしてみましょう。
All operations レベルの設定で Applicaiton Insights ロガーを設定しておくと、全ての Opearation に対するリクエストおよびバックエンドの転送を監視できます

前述のような設定（デフォルトはエラーで、Chat Completion のみ転送）をしておくと、Application Insights のアプリケーション マップ（あるいは dependency テーブルのログ）ではエラーが確認できませんが、requests テーブルを参照するとどの Operation リクエストが成功（失敗）したのかがわかります。
Chat Completion 以外はバックエンドに転送されておらず、API Management でエラーとして折り返すように設定できていそうです。

|アプリケーション マップ|request テーブル|
|---|---|
|![alt text](./images/only-success-chat-completion.png)|![alt text](./images/success-chat-completion-error-completion.png)|


# 様々なリージョンにデプロイされたモデル呼び出しのエンドポイントを集約する

バックエンドの Open AI が 1 つだけでは寂しいので、複数の OpenAI をデプロイして API Management に集約したいのですが、これにはいくつかのパターンが考えられます。

## 様々なリージョンにデプロイされたモデルを呼び分ける（ファサード）

[Azure OpenAI Service モデル](https://learn.microsoft.com/ja-jp/azure/ai-services/openai/concepts/models)
は提供されているリージョンによってバラツキが多く、
利用したい機能（API Operation）に応じて様々なリージョンに Azure OpenAI アカウントとモデルをデプロイしていく必要があります。
アカウントごとにエンドポイントと API キーが異なりますので、大変なのはそれを管理するクライアントアプリとセキュリティの管理者です。
Azure OpenAI の API キーに関しては前述のとおり Managed ID を使用することでキー管理の問題を回避することが可能です。
ただエンドポイント URL だけはどうしようもありませんので、ここを API Management に集約できないでしょうか。

![facade pattern](./images/facade-pattern.png)

これは API Management に登録された各々の Operation ごとにバックエンドとなる Azure OpenAI のエンドポイントを切り替えてあげればよいわけです。
一番初めに All Opeartion レベルの `inbound` ポリシーでエラーを返すように設定し、Chat Completion Operation のみ `set-backend` ポリシーと `authentication-managed-identity` で認証設定を行いましたので、同じように構成していきます。

- Completion
    - Instruct モデルが利用可能な Azure OpenAI サービスアカウントを作成、モデルをデプロイする
    - API Management の Managed ID に対して Azure Cognitive Service OpenAI Contributor 等の必要なロールを割り当てる
    - そのエンドポイント URL (https://_accountName_.openai.azure.com/openai) を API Management のバックエンドに登録する
    - Completion Operation の inbound ポリシーで set-backend ポリシーで切り替える
- Image Generation
    - DALL-E モデルが利用可能な Azure OpenAI サービスアカウントを作成、モデルをデプロイする
    - API Management の Managed ID に対して Azure Cognitive Service OpenAI Contributor 等の必要なロールを割り当てる
    - そのエンドポイント URL (https://_accountName_.openai.azure.com/openai) を API Management のバックエンドに登録する
    - Image Generation の Operation の inbound ポリシーで set-backend ポリシーで切り替える

API Management の System Assingned Managed ID に対して各 OpenAI アカウントに対してロールを割り当てると以下のようになります。

![alt text](./images/assign-apim-as-aoaicontributor.png)

API Management では以下のように各 Azure OpenAI サービス アカウントの URL を登録してきます。

![alt text](./images/apim-backends.png)

各 Operation の inbound ポリシーの例は以下のようになります。
利用するバックエンドが異なるだけで、`authentication-managed-identity` ポリシーの設定値は変わりません。

```xml
<!-- Image Generation Operation の場合 -->
<inbound>
    <set-backend-service id="imggen-backend-policy" backend-id="imggen-backend" />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com/" />
</inbound>
<!-- Image Generation Operation の場合 -->
<inbound>
    <set-backend-service id="completion-backend-policy" backend-id="completion-backend" />
    <authentication-managed-identity resource="https://cognitiveservices.azure.com/" />
</inbound>

```

ログを確認すると API Management に登録された Operation 毎にバックエンドの Azure OpenAI エンドポイントが切り替わっていますので、ちゃんとファサードの役割を果たせていそうです。

|Application Map|request - dependency|
|---|---|
|![alt text](./images/facade-aoai-appmap.png)|![alt text](./images/facade-aoai-log.png)|


## 複数のリージョンのクォータを束ねてスロットリングを回避する（負荷分散）

## メインのデプロイでクォータが不足したら別のリージョンも使う（バースト）



# memo
負荷分散
    - Single Endpoint
        ○ いろんなリージョンのモデル呼び出し
        ○ モデル名の固定
    - Shared Quota
        ○ トークンベースのスロットリング
        ○ キーの払い出し
        ○ ユーザー認証のログ取得、トークン数も取りたい
    - Load Balancing
        ○ マルチリージョン
        ○ GPT4o なら
Burst