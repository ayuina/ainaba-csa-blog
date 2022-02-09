---
layout: default
title: Azure Web Apps for WINDOWS Container (.NET Framework) 開発のメモ
---

## はじめに

コンテナーといえば Linux コンテナーを扱うことが多いわけですが、 Azure Web Apps 上で Windows Server Container な .NET Framework アプリケーションを動かす機会に恵まれたので、いろいろ調査やらハマったことやらを記録に残しておこうと思います。

## 目次

1. [Windows Server Container 開発編](./01_wincontainer.md)
1. [Web Apps for Windows Container デプロイ編](./02_webapp.md)


## 参考ドキュメント

本文中でも適宜触れていますが、以下が代表的なリファレンスになりますので、適宜ご参照ください。
おおむね下記に書いてあることばかりではありますが、そこから読み取りにくくてハマりそうな（ハマった）ポイントなどをいくつか記載していこうと思います。

- [Azure でカスタム コンテナーを実行する](https://docs.microsoft.com/ja-jp/azure/app-service/quickstart-custom-container?tabs=dotnet&pivots=container-windows)
- [Azure App Service のカスタム コンテナーを構成する](https://docs.microsoft.com/ja-jp/azure/app-service/configure-custom-container?pivots=container-windows)
- [Azure App Service Team Blob - Windows Containers](https://azure.github.io/AppService/windows-containers/)
- [Windows のコンテナーに関するドキュメント](https://docs.microsoft.com/ja-jp/virtualization/windowscontainers/)
- [Windows コンテナーとして既存の .NET アプリを展開する](https://docs.microsoft.com/ja-jp/dotnet/architecture/modernize-with-azure-containers/modernize-existing-apps-to-cloud-optimized/deploy-existing-net-apps-as-windows-containers)
- [.NET Framework のアプリケーションの互換性](https://docs.microsoft.com/ja-jp/dotnet/framework/migration-guide/application-compatibility)

呼んでいただいた方のご参考になれば幸いです。