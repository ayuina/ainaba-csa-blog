---
layout: default
title: Azure の閉域ネットワーク環境における Microsoft Foundry の使い方
---

## はじめに

Microsoft Foundry を使用して AI エージェントを作るというのも相応に普及してきたかなという印象ですが、
そうなってくると本番環境の構築という話になってくるわけです。
特に企業さんだと Azure VNET を使用した閉域ネットワーク環境をどう作るか、ということになりがちです。

もちろん Microsoft Foundry も 
[Private Endpoint に対応していますので](https://learn.microsoft.com/ja-jp/azure/foundry/agents/how-to/virtual-networks?tabs=portal)、
これを使用することでインターネットにアタックサーフェスをさらしたくないということになると思います。
当然パブリック側のエンドポイントは閉じたいでしょうから、そうなってくると 
[Foundry Portal](https://ai.azure.com) の利用が課題になりがちです。

そもそも Azure の PaaS サービスは基本的に API として機能を提供していますが、それを簡易的にお試しできる Web UI もセットで提供されていることがほとんどです。
Foundry なら Foundry Portal がありますし、Cosmos DB や Storage Account のように Azure Portal の中に組み込まれて提供されていることもありますね。

本記事で話題にしたい Foundry Portal は URL のドメインが `ai.azure.com` ですが、Foundry が各種機能を提供する API のドメインは異なります。
つまり Foundry Portal 等からこれらの API を叩くということは、
[CORS : Cross Origin Resource Sharing](https://developer.mozilla.org/ja/docs/Web/HTTP/Guides/CORS) の
問題が発生するわけです。

- _{foundryName}_.services.ai.azure.com
- _{foundryName}_.openai.azure.com
- _{foundryName}_.cognitiveservices.azure.com
- _{regionname}_.stt.speech.microsoft.com
- _{regionname}_.tts.speech.microsoft.com
- api.cognitive.microsofttranslator.com

しかもこれらの、特に最初の３つのドメインを使用する API は Private Endpoint 経由でアクセスすることが強制されているわけですから、
アクセス経路の問題があるわけです。
従来は VNET と VPN や ExpressRoute で閉域接続できるネットワーク環境上のオンプレ端末や、
Azure 仮想マシンおよび Azure Bastion を利用していわゆる「踏み台サーバー」上の Web ブラウザでポータルを開くことで対応してきた方が多いんじゃないでしょうか。

![alt text](./images/private-foundry-overview.png)

つまりこれは新しい話でもなんでもないんですが、久しぶりにハマってしまったのと、従来のような解決策が使えなくなっているということが分かったので改めて整理しておこうと思います。

