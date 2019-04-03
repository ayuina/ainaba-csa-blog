---
layout: default
title: Azure Monitor Log を使用したオンプレ環境のログ収集と解析
---

## はじめに

従来 Log Analytics と呼ばれていた Azure のサービスですが、
現在は Azure Monitor と呼ばれる監視系ソリューションの
[一部](https://docs.microsoft.com/ja-jp/azure/azure-monitor/azure-monitor-log-hub)
と位置付けられています。

意外と？誤解されやすいのですが Azure 上で発生するログを分析するためのサービスではなく、 
（Azure に限らず）任意の各種環境で生成されるログを分析するために Azure 上で動作しているサービスです。
端的に言うと、オンプレで動作する物理／仮想の PC やサーバー、Azure 以外で動作する仮想マシンなどを対象とすることが可能です。

## アーキテクチャ

Azure Monitor は各種ノード（PC やサーバー）にインストールされたエージェントがログを収集、インターネット経由で Azure にログを送信します。
つまり理論上は以下の 2 点がクリアできれば任意の環境を対象としたログの収集が可能です。

- エージェントが [動作するプラットフォーム](https://docs.microsoft.com/ja-jp/azure/azure-monitor/platform/log-analytics-agent#supported-windows-operating-systems) であること
- インターネットへの HTTPS 接続経路（Port 443）があること

また各ノードが直接送信せずとも、System Cener Operations Manager が既に導入されている環境であれば、
SCOM を中継地点としてログをかき集めることも可能です。
ログがデータベースに格納されれば、あとはクエリをかけたり、可視化したり、といったような形で分析をすればよいだけです。

![Log Analyticsのアーキテクチャ](./images/architecture-of-log-analytics.png)

本記事ではオンプレミス Windows 環境を対象としたログの収集・解析の一連の流れを紹介したいと思います。
（単に私が Windows PC しか持ってないからという話でもあります）

## エージェントのインストール

Azure 上に Log Analytics ワークスペースを作成したら、次はエージェントのインストールです。詳細設定の画面から Windows 用、Linux 用のエージェントをダウンロードすることが可能ですので、こちらをインストールします。

![エージェントの取得](./images/download-agent.png)

Windows 上にインストールを行うとコントロールパネルから Microsoft Monitoring Agent の状態が確認することができます。
この後、実際に分析を行うわけですが、ある程度ログが貯まっていないと面白くありませんので、
試せる PC やサーバーを何台か選んでエージェントを仕込んだ後、数日様子を見ることをお勧めします。

![インストールされたエージェント](./images/installed-agent.png)

私は ~~嫁と子供に内緒で~~ 自宅で管理している PC が 4 台ほどあったので、それらにインストールして数日様子を見ました。

## 蓄積されたログの分析

蓄積されたログは Azure ポータルからクエリをかけることが出来るようになります。
エージェントは Windows サービスとして常駐し、起動中には Log Analytics ワークスペースに対して定期的に通信を行います。 
これは Heartbeat と呼ばれ、この通信が受信できているということは、少なくともそのマシンが起動してログが収集できていることが確認できます。
下記がその Heartbeat を特に加工せずクエリした例になります。
![ポータルでログをクエリ](./images/la-query-heartbeat.png)



