---
layout: default
title: log-analysis-on-premise-computer
---

# Azure Monitor Log を使用したオンプレ環境のログ収集と解析

従来 Log Analytics と呼ばれていた Azure のサービスですが、
現在は Azure Monitor と呼ばれる監視系ソリューションの一部と位置付けられています。
意外と？誤解されやすいのですが Azure 上で発生するログを分析するためのサービスではなく、 
（Azure に限らず）任意の各種環境で生成されるログを分析するために Azure 上で動作しているサービスです。
端的に言うと、オンプレで動作する物理／仮想の PC やサーバー、Azure 以外で動作する仮想マシンなどを対象とすることが可能です。

## Microsoft Monitoring Agent のインストール

