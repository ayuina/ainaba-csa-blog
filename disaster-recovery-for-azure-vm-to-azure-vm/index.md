---
layout: default
title: Azure 仮想マシンの災害対策
---

## はじめに

Azure を使用したシステムの設計をする際に、まず間違いなく「広域災害時の災害対策をどうやるのか・どこまでやるのか」が議論になります。
当然の事ながら、システムの特性に応じて必要な RTO/RPO は異なりますし、かけられるコストや手間にも差異がありますので、コレといった唯一絶対の正解はありません。
ただ正解はないとはいえ、クラウドに備わったサービスを利用する事で効率的に災害対策を実現する、というのもクラウドを利用するメリットの１つと言えるでしょう。
このため災害対策を構成する上で「Azure で提供されている選択肢として何があるのか」を把握しておくことが重要です。

本ブログでは「Azure 仮想マシンで構成されたシステムの災害対策」において考えられる方法論について整理していきたいと思います。
端的にいって [Azure Site Recovery](https://docs.microsoft.com/ja-jp/azure/site-recovery/) の話になるわけですが、
なんでもかんでも Site Recovery というのが必ずしも正解ではないと思いますので、その他の選択肢に触れていきたいと思います。

## 前提知識

Azure は必ず東日本リージョンに対して西日本リージョン、北ヨーロッパ (アイルランド)リージョンに対して西ヨーロッパ (オランダ)リージョン、といったように
[必ずペアリージョンが存在](https://docs.microsoft.com/ja-jp/azure/best-practices-availability-paired-regions)します。
たまに勘違いされるケースがあるのですが、「大規模災害が発生して使用しているリージョンが使えなくなったら、**自動的にペアリージョンで復旧してくれる** んでしょ？！」と言われることがあります。
残念ながらそんな素敵なことはなくて、ペアリージョンはあくまでも選択肢として提供されているだけです。
[可用性セットや可用性ゾーン](https://docs.microsoft.com/ja-jp/azure/virtual-machines/windows/manage-availability)と同様に、
ペアリージョンも使う使わないはユーザーが判断し、意図的に構成する必要のあるオプションです。

## Azure Backup と Azure Site Recovery 

災害対策構成の議論において「Azure Backup と Site Recovery どっちを使えばいいの？」と良く聞かれる、というのがこの記事を書く動機の９割くらいを占めています。
超おおざっぱに言ってしまえば、Azure Backup はオペレーションミスやマルウェア等によるデータやシステムの **論理的な破損** に備えておくためのものであって、
広域災害によるリージョンの全面的な停止・喪失のような  **物理的な破損** に備えるならば Site Recovery を使用すべきです。

しかしなぜか「災害対策に Azure Backup を使用したい」お客様というのが一定数いらっしゃって、よくよく聞いてみると以下の理由によるようです。

- オンプレミスデータセンターでは「サーバーのバックアップを記録したテープメディアを遠隔地のデータセンターに保管する」というの災害対策を実施していた
- Azure Backup も [Geo 冗長ストレージ](https://docs.microsoft.com/ja-jp/azure/storage/common/storage-redundancy) を使用できる

そして私の個人的な観測範囲では、以下の差異を認識せず、イメージで混同されているケースが多く見受けられました。

- Azure Backup のサービス内容と、オンプレミスで利用していたバックアップソリューション
- Azure の Geo 冗長ストレージと、オンプレミスで行われていた遠隔地へのメディア保管運用

また Backup も Site Recovery も `Recovery Service コンテナー` と呼ばれる Azure リソースを使用する、という事実が混乱に拍車をかけます。
~~個人的にはこのデザインがかなり問題なんじゃないかと思うのですが、~~ まずはこの誤解を解きましょう。

### 災害対策ソリューションとして Azure Backup を検討する際に気をつけておくべき事

![azure vm backup](./images/azure-vm-backup.png)

まず、Azure Backup で保護できる仮想マシンは[同一リージョンのみ](https://docs.microsoft.com/ja-jp/azure/backup/backup-support-matrix-iaas) です。

- 保護対象の仮想マシンと同じリージョンに Recovery Service コンテナーを配置する必要があり、リージョン障害時には一緒に影響を受ける可能性が極めて高いのでアテにできない
- 別リージョンへのリストアはできない（ GRS によってペアリージョンにデータはコピーされているが、あくまでも喪失防止が目的であって、ユーザーが任意のタイミングで活用できるわけではない）
    - これは[Cross Region Resotre](https://docs.microsoft.com/ja-jp/azure/backup/backup-azure-arm-restore-vms#cross-region-restore) の GA と共に緩和される見込み

次に、大規模災害時にどの程度のタイムラインで Azure Backup がペアリージョンにフェイルオーバーして利用可能になるかがわかりません。

- そもそも [Azure Backup の SLA](https://azure.microsoft.com/ja-jp/support/legal/sla/backup/) として定義されていない
- システムの DR 要件に **RTO が定義されている** 場合には、Backup は災害対策ソリューションとしては成り立たない考えるべき
    - DR 要件として時間制約がなく「いつか復旧できれば良い（データが喪失さえなければ良い、タイミングは Microsoft 任せで良い）」というものであれば検討の余地がある

最後に、Azure Backup による仮想マシンバックアップの頻度は[最大でも 1 日 1 回](https://docs.microsoft.com/ja-jp/azure/backup/backup-support-matrix-iaas#backup-frequency-and-retention)です。

- 前述の Cross Region Restore を使用したとしても、災害発生のタイミングが最悪のケースでは、仮想マシンの状態が最大で 24 時間前まで戻ってしまう
- RPO の要求が 24 時間未満であるシステムでは、要件が満たせない可能性が高い

### 災害対策ソリューションとして Azure Site Recovery を検討すべき理由

![azure to azure site recoveryf](./images/azure-to-azure-siterecovery.png)

前述の Azure Backup における注意事項の逆パターンになるわけですが、Azure Site Recovery には以下のメリットがあります。

まず、Recovery Service コンテナおよび仮想マシンのレプリケート先は、保護対象と[別リージョン](https://docs.microsoft.com/ja-jp/azure/site-recovery/azure-to-azure-support-matrix)です。
- 保護対象の仮想マシンの配置リージョンが停止していても、Recovery Service コンテナおよびレプリケートされた仮想マシンのディスクは別リージョンで利用可能

次に、フェイルオーバーのトリガーは **ユーザー手動** であるため、災害復旧に関して Microsoft の判断を待たずにフェイルオーバーする事が可能です。
- [Azure Site Recovery の SLA](https://azure.microsoft.com/ja-jp/support/legal/sla/site-recovery/)としても仮想マシン単位での目標復旧時間（2時間）が定義されている
- 大規模災害時の運用等も含め、システム全体がフェイルオーバーするための所要時間が計算できるため、目標 RTO が定義できる
- 必ずしも大規模災害時である必要もなく、テストフェイルオーバーによる避難訓練や、メンテナンスの回避などを目的としたフェイルオーバーをしても良い

最後に、保護対象の仮想マシンのディスク I/O に応じて連続的にレプリケーションが行われるため RPO が短く抑えられる。
- [クラッシュ整合性復旧ポイントが５分間隔](https://docs.microsoft.com/ja-jp/azure/site-recovery/azure-to-azure-architecture#snapshots-and-recovery-points)で作成される（理論上の最小 RPO は５分）
- 復旧ポイントは最大で 72 時間まで保持できるため、データの整合性や運用上の適切な状態で復旧することができる





