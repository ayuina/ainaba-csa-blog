---
layout: default
title: Windows Subsytem for Linux で Azure CLI を動作させる話
---

## はじめに

結論から言えばソフトウェアのインストール要件はちゃんと守りましょうという、すごく当たり前の話なのですが、
これで二日くらい溶かした挙句、同僚にもいろいろ協力してもらったので、その感謝もこめてここに記します。
そしてドキュメントはちゃんと読もうと思いました。

## Windows で Azure CLI を動かす場合

最終的に Linux マシンで動作するシェルスクリプトを開発する場合にも、手元にある開発環境は Windows だったりするので、
[WSL : Windows Subsystem for Linux](https://docs.microsoft.com/ja-jp/windows/wsl/) の出番なわけです。
今回私は Azure 上に環境構築するためのスクリプトを作っていたので、[Azure CLI](https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli-windows?tabs=azure-cli) が必要です。

では WSL を起動して Azure CLI のバージョンを確認しましょう。

```bash
$ az --version

azure-cli                         2.27.1

core                              2.27.1
telemetry                          1.0.6

Extensions:
application-insights              0.1.13
azure-firewall                     0.9.0
storage-blob-preview               0.5.0

Python location 'C:\Program Files (x86)\Microsoft SDKs\Azure\CLI2\python.exe'
Extensions directory 'C:\Users\ainaba\.azure\cliextensions'

Python (Windows) 3.8.9 (tags/v3.8.9:a743f81, Apr  6 2021, 13:22:56) [MSC v.1928 32 bit (Intel)]

Your CLI is up-to-date.
```

うんうん、ちゃんと最新版がうｇ　
あれ、そもそも Azure CLI インストールしたっけ・・・。
ていうか、Windows にインストールしている Python が動いてるなコレ？？？

確かに Windows コマンドプロンプトや PowerShell で Azure CLI 自体は使用していたのでインストールはしてありましたが、動くとは思ってなかったなあ・・・。
これは [WSL の相互運用機能](https://docs.microsoft.com/ja-jp/windows/wsl/interop)のおかげで、WSL から直接 Windows 向けのバイナリも実行することが出来るんですね。
なるほど便利じゃないか、ということでそのまま開発作業を続行したところ、地味なトラブルに見舞われて二日くらい無駄にしました・・・。
（最初はこのトラブルの内容を注意喚起しようかと思ったのですが、結局はソフトウェアのインストールの問題だったのでトラブルの方は割愛します）

同僚にもいろいろ手伝ってもらって調査していったところ、
最終的に [Windows での Azure CLI のインストール](https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli-windows?tabs=azure-cli)にたどり着きました。 

> Windows Subsystem for Linux (WSL) 用にインストールする場合は、お使いの Linux ディストリビューションで使用できるパッケージがあります。 
> サポートされているパッケージ マネージャーの一覧または WSL での手動インストール方法については、メインのインストール ページを参照してください。

なるほど、つまり WSL で使う場合には [Linux マシンの場合と同様にインストールしろ](https://docs.microsoft.com/ja-jp/cli/azure/install-azure-cli-linux?pivots=apt)ってことですな。
インストールした後に WSL を再起動してバージョンを確認します。

```bash
$ az --version

azure-cli                         2.27.1

core                              2.27.1
telemetry                          1.0.6

Extensions:
application-insights              0.1.13
azure-firewall                     0.9.0
storage-blob-preview               0.5.0

Python location '/opt/az/bin/python3'
Extensions directory '/home/ayumu/.azure/cliextensions'

Python (Linux) 3.6.10 (default, Aug 11 2021, 02:41:08)
[GCC 9.3.0]

Your CLI is up-to-date.
```

これで無事に Linux 側の Python で動作してますので、問題なさそうです。
実際にこれでトラブルも解消して、無事にスクリプトを動作させることができました。

## 相互運用的な話をすこしだけ

Windows 版と Linux 版の両方がインストールされている環境だと、どちらが動作しているのかが分かりにくくてちょっと不安です。
前述の通り ```--version``` オプションで確認すれば az コマンドというかそのランタイムとなる Python が Windows と Linux のどちらで動いているかは確認できますが、
念のためパスが通っている場所も確認してみましょう。（以下の結果は見やすさのために改行を入れて結果もかなり削ってあります。）

```bash
$ echo $PATH

/usr/local/sbin:
/usr/local/bin:
/usr/sbin:
/usr/bin:
/sbin:
/bin:
/mnt/c/Program Files (x86)/Microsoft SDKs/Azure/CLI2/wbin:
/mnt/c/WINDOWS/system32:
/mnt/c/WINDOWS:
```

上記の通り Linux っぽいパスが先に入っていて、Linux 版の Azure CLI も ```/usr/bin/az``` にインストールされていました。
その後で Windows っぽいパスが入っていて、Windows 版の Azure CLI は ```/mnt/c/Program Files (x86)/Microsoft SDKs/Azure/CLI2/wbin/az``` にインストールされていました。
つまり Linux 版がインストールされていればそちらが優先され、Linux 版がインストールされていない場合には Windows 版が動作する、という順番になりそうですね。

Linux 版をインストールしてるか否かで挙動が変るわけですから、私のように普段 Windows でたまに Linux という人間には罠の予感がします。
一応 WSL は[相互運用性を無効にする](https://docs.microsoft.com/ja-jp/windows/wsl/interop#disable-interoperability)ことで、Windows のバイナリがうっかり動かないようにすることも可能です。
実際 Windows 版の Azure CLI のみがインストールされている環境で、WSL の相互運用性を無効化した状態で az コマンドを叩いてみると、下記のようになります。

```bash
$ az --version
/mnt/c/Program Files (x86)/Microsoft SDKs/Azure/CLI2/wbin/az: line 3: /mnt/c/Program Files (x86)/Microsoft SDKs/Azure/CLI2/wbin/../python.exe: cannot execute binary file: Exec format error
```

パスは通ってしまっているので az コマンド（中身は実際にはシェルスクリプト）は起動されてしまいます。
ただそこから Windows 向けのバイナリである python.exe を実行するのですが、相互運用性が無効化されていればここでエラーで落ちることになります。
人によってはこの相互運用機能は不要な場合もあると思うので、こちらを無効化しておくというのも手段としてはアリかなと思います。

## Docker コンテナもいいですよね

Linux で動作するスクリプトなんだから Linux 環境で開発すればそもそも発生しなかった問題でもあった、という身も蓋もない考え方もあります。
わざわざ仮想マシンを作らずとも、コンテナを使ってしまえば環境を整えるのも簡単です。
Microsoft から [Azure CLI インストール済みのコンテナイメージ](https://hub.docker.com/_/microsoft-azure-cli)が提供されているので、こいつを使って開発すれば良かったんですな。

```bash
$ docker run -it mcr.microsoft.com/azure-cli /bin/bash
```

まあ今回の件は WSL に問題があったわけではなく、 Azure CLI のインストール方法を真面目に確認せず、 WSL のおかげで動作出来てたのを見過ごしていた私が悪いのですが。

## まとめ

- Windows 版と Linux 版の両方が提供されているソフトウェアは、WSL 側にもちゃんと Linux 版をインストールしたほうが無難
- ソフトウェアの動作要件やインストール手順などはちゃんと確認しましょう

