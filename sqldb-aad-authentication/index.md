---
layout: default
title: Azure SQL Database の Azure Active Directory 認証
---

## はじめに

本記事は .NET Core なアプリケーションから SQL 認証ではなく 
[Azure Active Directory (Azure AD) の ID を使用して Azure SQL Database（SQL DB） にアクセスする](https://docs.microsoft.com/ja-jp/azure/sql-database/sql-database-aad-authentication)
方法を個人的に整理したものです。
[こちら](https://docs.microsoft.com/en-us/azure/sql-database/sql-database-aad-authentication-configure)
のドキュメントなども参考になります。

## Azure SQL Database の作成

まず初めに
[こちらの手順](https://docs.microsoft.com/ja-jp/azure/sql-database/sql-database-single-database-get-started?tabs=azure-portal)
などにしたがって単一データベースの SQL DB を作成します。
この時点でも SQL 認証が有効になっていますので、SQL Server Management Studio や 
[Azure Data Studio](https://docs.microsoft.com/ja-jp/sql/azure-data-studio/what-is?view=azuresqldb-current) 
などを使用してアクセスすることができます。

![sqlauth](./images/sqlauth.png)

もちろん .NET Core を使用したアプリケーションでも SQL 認証を使用したアクセスは可能です。
`dotnet` コマンドを使用してコンソールアプリ用のプロジェクトを作成し、SQL Database にアクセスするためのクラスライブラリとして
[Microsoft.Data.SqlClient](https://www.nuget.org/packages/Microsoft.Data.SqlClient/)
を追加します。

```bash
dotnet new console
dotnet add package Microsoft.Data.SqlClient
```

C# の実装は以下のようになります。

```csharp
using Microsoft.Data.SqlCient

public SqlConnection CreateSqlAuthConnection()
{
    var constr = "Server=tcp:servername.database.windows.net,1433;Initial Catalog=dbname;"
               + "User ID=sqluserName;Password=yourPassword;"
    return new SqlConnection(constr);
}
```

しかし、以降ではこの認証情報および接続方式は使用せず、Azure AD で管理されるセキュリティプリンシパルを使用してアクセスして行きたいと思います。

## 管理ユーザーの作成と登録

まずは SQL DB のユーザー管理に使用する Azure AD ユーザーを登録します。
もし適当なユーザーが存在しない場合には
[こちらの手順](https://docs.microsoft.com/ja-jp/azure/active-directory/fundamentals/add-users-azure-active-directory)
にしたがってユーザーを作成します。
このユーザーは SQL DB を作成したサブスクリプションが信頼する AAD テナントと同一テナント上のユーザーとして作成してください。

例えば以下のようなユーザーを作成したとします。

|ユーザー名|sqladmin@tenantname.onmicrosoft.com|
|パスワード|P@ssw0rd!|

このユーザーに対して SQL DB の管理権限を付与します。

![sqldb-aad-admin](./images/sqldb-aad-admin.png)

まずは Azure Data Studio を使用して、SQL DB に対して Azure AD 認証でアクセスしてみましょう。
接続情報画面で認証の種類として Azure Active Directory を選択します。
接続に使用するアカウント選択のドロップダウンで `Add an account` を追加するとブラウザが起動して認証画面が表示されますので、
先ほど SQL DB の管理者として登録した Azure AD ユーザーでサインインします。
データベースには（master ではなく）SQL DB 作成時のデータベースを選択してください。

![ads-connect-aadauth](./images/ads-connect-aadauth.png)

接続できたら適当な SQL を投げてみましょう。
例えば以下のクエリで現在接続しているユーザーの名前を確認できます。

![ads-query-asadmin](./images/ads-query-asadmin.png)

```sql
select suser_name()
```

以降ではこの管理ユーザーを使用して、ユーザーやアプリケーションの登録をしていきますので、この画面はこのまま維持しておいてください。

## Azure AD ユーザーによる SQL Database へのアクセス

先ほど登録した管理ユーザでは権限が強すぎますので、実際の保守・運用に使用するユーザーは別途登録すると良いでしょう。
例えば先ほどと同様の手順で以下のようなユーザーを Azure AD に作成したとします。

|ユーザー名|sqlapp@tenantname.onmicrosoft.com|
|パスワード|P@ssw0rd!|

この Azure AD ユーザーを SQL DB のユーザーとして登録し、かつ、データベースロールのメンバーに追加することで、実際のアクセスが可能になります。
先ほどの管理ユーザーの Azure Data Studio の画面で以下のクエリを実行します。

```sql
CREATE USER [sqlapp@tenantname.onmicrosoft.com] FROM EXTERNAL PROVIDER;
ALTER ROLE db_owner ADD MEMBER [sqlapp@tenantname.onmicrosoft.com];
```

ポイントは以下のようになります。
- CREATE USER で Azure AD 上のユーザー名を指定する（その際に四角括弧で特殊文字をエスケープ）
- FROM EXTERNAL PROVIDER 句を追加して、外部で管理されているユーザー（この場合 Azure AD）であることを明示する
- 作成したユーザーを必要な権限を持つデータベースロール（ここでは db_owner）のメンバーとして追加する

これで接続できるようになりましたので、Azure Data Studio で接続してみてください。
接続方法は先の管理者ユーザーの場合と同様です。

このユーザーを使用して C# アプリからアクセスするための実装は以下のようになります。
接続文字列で認証種別 `Authentication` として `Active Directory Password` を使用しています。 

```csharp
public SqlConnection CreateAadUserConnection()
{
    var constr = "Server=tcp:servername.database.windows.net,1433;Initial Catalog=dbname;"
               + "Authentication=Active Directory Password;User ID=sqlapp@tenantname.onmicrosoft.com;Password=P@ssw0rd!";
    return new SqlConnection(constr);
}
```

## Azure AD アプリケーションによる SQL Database へのアクセス

前述の方法では GUI はともかくとして、アプリケーションが誰かのユーザー ID を使用して SQL DB にアクセスし続けることになりますので、
パスワードが変更された場合は多要素認証が有効になっている場合には不便でしょう。
せっかく Azure AD 認証を使用しているのでアプリケーションようのアクセストークンを使用したいところです。

### サービスプリンシパルとキーを使用したトークンの取得とアクセス

まずは
[こちらの手順](https://docs.microsoft.com/ja-jp/azure/active-directory/develop/howto-create-service-principal-portal)
にしたがって Azure AD にアプリケーションを登録します。
ただこの手順は本記事で扱う内容に対して若干内容が多く不要な部分が多いので、以下の項目 **だけ** 実施すれば十分です。

- `Azure Active Directory アプリケーションを作成する`を実施しますが、Redirect URL の登録は不要です
- `サインインするための値を取得する` でディレクトリ ID とアプリケーション ID を控える
- `新しいアプリケーション シークレットを作成する` で作成したシークレットを控える

|クライアント名 |sqlapp_sp|
|アプリケーション ID|guid-of-your-application-id|
|ディレクトリ ID|guid-of-your-azuread-directory-id|
|クライアントシークレット|key-secret-generated|

このサービスプリンシパルの情報を用いると Azure AD で認証を受けることはできますが、SQL Database へのアクセス権がありませんので、
先ほどの管理ユーザーの Azure Data Studio の画面で以下のクエリを実行します。

```sql
CREATE USER [sqlapp@tenantname.onmicrosoft.com] FROM EXTERNAL PROVIDER;
ALTER ROLE db_owner ADD MEMBER [sqlapp@tenantname.onmicrosoft.com];
```


アクセストークンを作成し、そのトークンを SqlConnection オブジェクトにセットすれば接続可能です。

```csharp

```


### システムアサイン管理 ID を使用したトークンの取得とアクセス

- MIDの作成
- SQL DB のユーザー作成とアクセス権の付与
- Connection String

### ユーザー割り当て管理 ID を使用したトークンの取得とアクセス

- UAIDの作成
- SQL DB のユーザー作成とアクセス権の付与
- Connection String

## 備考

### 発行されたトークンの確認

### グループ登録によるアクセス権限



## まとめ