---
layout: default
title: Azure 仮想マシンから Key Vault 証明書を利用する
---

## はじめに

個人的に Azure Key Vault はどうにも敷居が高く、また証明書ってやつもどうも敷居が高くて、なんとなく遠ざけてきたのですが、
最近どうしても使わざるを得ないシチュエーションにはまりいろいろ調べている次第です。
そんななかで 
[Azure Key Vault 仮想マシン拡張機能](https://azure.microsoft.com/ja-jp/updates/azure-key-vault-virtual-machine-extension-now-generally-available/)
なんてものを教えてもらい、何これ便利じゃないですか、ということで How To 記事を書く気になりました。

そもそも Key Vault にアクセスするには Azure AD 認証が必要です。
仮想マシン上で動作するアプリケーションが Key Vault から証明書などの秘密情報を取得したい場合には、
サービスプリンシパルを使用して認証を受け、アクセストークンを取得してから Key Vault にアクセスし、証明書をダウンロードしてきます。
ところでサービスプリンシパルとして Azure AD 認証を受けるためにはやっぱりクライアントシークレットや証明書が必要ですよね。
この証明書やシークレットはどこで管理しましょう。
まさか Key Vault というわけには行きません。
つまり秘密情報を安全に管理するための仕組みとしての Key Vault 、それにアクセスするための秘密情報は結局仮想マシンローカルに持っておく必要があったわけです。

![using certificate without managed identity](./images/certificate-without-managed-id.png)

この状況を打破するためのソリューションが私の大好きな Managed ID です。
これを使うことで、Azure 仮想マシン上で動作するアプリケーションは **サービスプリンシパルとして認証を受けるための秘密情報を管理することなく** Azure AD 認証が可能な Azure Key Vault などの各種サービスにアクセスできるわけです。
証明書認証が必要なサービスであれば Azure Key Vault に管理させておいて取り寄せればいいわけです。

![using certificate with managed identity](./images/certificate-with-managed-id.png)

とはいえ、これはアプリケーション起動時や外部サービスへのアクセス時に一度 Key Vault を開けにいかなければいけないわけですね。
クライアントシークレットの管理は不要になりましたが、実行時の手数はそれほど変わりないわけで、まだちょっとメンドクサイ。
Key Vault に管理されている証明書が直接仮想マシンからアクセスできれば素敵ですよね。
ということで前置きが長くなりましたが本題の仮想マシン拡張機能が便利です。

![using certificate from key vault](./images/certificate-from-keyvault.png)

なお上記ではクライアント証明書のイメージで記載していますが、TLS サーバー証明書の運用にも利用できますね。

## セットアップ

セットアップ手順は下記に記載されているのですが、私のような証明書初心者には微妙にわかりにくい点もありましたので補足していきます。
- [Windows 用の Key Vault 仮想マシン拡張機能](https://docs.microsoft.com/ja-jp/azure/virtual-machines/extensions/key-vault-windows)
- [Linux 用の Key Vault 仮想マシン拡張機能](https://docs.microsoft.com/ja-jp/azure/virtual-machines/extensions/key-vault-linux)

