---
layout: default
title: Azure OpenAI Service を API Management 経由で呼び出す構成を自動化する
---

# 概要

Azure OpenAI Service の前段に API Management を配置することで様々な価値を追加することが可能です。

- Azure OpenAI Service 単体では出力できないログを出力する
- Azure OpenAI Service へのアクセス EntraID 認証を利用してセキュリティを向上
- クライアントアプリ単位で API キーを払い出しアクセス制御やスロットリングを行う
- 複数の OpenAI Service への負荷分散を行ってクォータ制限を回避する
- etc...

このコンテンツは繰り返しデプロイ可能な Bicep テンプレートなどのサンプルコードとともに [こちらのレポジトリで公開しています。](https://github.com/ayuina/apim-aoai-sample)
