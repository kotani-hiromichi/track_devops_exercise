# なぜ roles/iam.serviceAccountUser（ActAs 権限）が必要なのか

GitHub Actions から Cloud Run や Cloud Build を使うとき、**「デフォルトの Compute 用サービスアカウントを“代わりに使ってよい”という権限」**を WIF に付与する必要があります。それが **`roles/iam.serviceAccountUser`**（通称 **ActAs 権限**）です。

---

## 1. 結論（一言で）

| 用語 | 意味 |
|------|------|
| **ActAs** | 「このサービスアカウントの**ふりをして**（として）リクエストを送ってよい」という権限 |
| **なぜ必要か** | Cloud Run のデプロイや Cloud Build の実行は、**サービスアカウントの権限**で動く。WIF は「誰か」を表すだけで、それだけでは「どの SA として動くか」が決まらない。**「この SA として動いてよい」**を明示するために `iam.serviceAccountUser` を付与する。 |

---

## 2. 権限の「二段構え」

GCP では、**「何かをする権限」**と**「誰かの代わり（として動く権限）」**が分かれています。

```
【よくある誤解】
「WIF に roles/run.developer を付けたから、GitHub から Cloud Run にデプロイできる」

【実際に必要なもの】
1. Cloud Run を操作する権限（例: roles/run.developer）  … プロジェクトに付与
2. 「デフォルトの Compute SA として実行してよい」権限（roles/iam.serviceAccountUser） … その SA に付与
```

- **1** だけだと「Cloud Run の操作は許可するが、**どの身份（サービスアカウント）で** Cloud Run が動くか」が決まらない。
- **2** を付けることで、「この WIF（＝GitHub のこのリポジトリ）は、**このサービスアカウントの代わりに（ActAs）** Cloud Run / Cloud Build を動かしてよい」と GCP が判断できる。

---

## 3. 図解：ActAs がない場合とある場合

### 3.1 ActAs を付与していない場合

```
┌─────────────────────────────────────────────────────────────────────────┐
│  GitHub Actions（WIF で認証済み）                                         │
│  「Cloud Run にデプロイしたい」                                            │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ gcloud run deploy ...
                                    │ （内部で「どの SA で動かすか」が必要）
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  GCP IAM                                                                 │
│                                                                          │
│  ✓ この principalSet には roles/run.developer がある                      │
│    → 「Cloud Run の操作は許可」                                            │
│                                                                          │
│  ✗ この principalSet は「デフォルト Compute SA の iam.serviceAccountUser」 │
│    を持っていない                                                         │
│    → 「その SA として（ActAs）実行してよい」と見なされない                  │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                        ❌ エラー（Permission Denied）
                        「サービスアカウントのユーザー権限がありません」
```

- **run.developer だけ**では、「**どのサービスアカウントで** Cloud Run が動くか」を「使ってよい」と許可していないため、デプロイが拒否されます。

### 3.2 ActAs（roles/iam.serviceAccountUser）を付与した場合

```
┌─────────────────────────────────────────────────────────────────────────┐
│  GitHub Actions（WIF で認証済み）                                         │
│  principalSet: .../attribute.repository/kotani-hiromichi%2Ftrack_...    │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 1. 認証（WIF トークン）
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  Workload Identity Federation                                            │
│  「このトークンは kotani-hiromichi/track_devops_exercise の主体だ」と判定   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 2. プロジェクトの IAM で権限チェック
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  プロジェクト ex-ai-training-program の IAM                              │
│                                                                          │
│  principalSet に付与済み:                                                 │
│    • roles/run.developer        → Cloud Run の操作 OK                     │
│    • roles/cloudbuild.builds.editor  → ビルド実行 OK                      │
│    • roles/artifactregistry.writer   → イメージ push OK                  │
│    • ...                                                                │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 3. 「では、どの SA として実行するか？」
                                    │    → 多くの場合「デフォルト Compute SA」
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  デフォルト Compute サービスアカウント                                    │
│  XXXXX-compute@developer.gserviceaccount.com                             │
│                                                                          │
│  この SA の IAM:                                                         │
│    principalSet に roles/iam.serviceAccountUser を付与済み                 │
│    → 「この WIF 主体は、この SA を“使ってよい”（ActAs）」                   │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    │ 4. Cloud Run / Cloud Build が
                                    │    この SA の権限で実際に実行される
                                    ▼
                        ✅ デプロイ・ビルドが成功
```

- **run.developer など**で「Cloud Run を触ってよい」と許可し、
- **デフォルト Compute SA に対する iam.serviceAccountUser**で「その SA の**代わりに**（ActAs）実行してよい」と許可しているため、デプロイが通ります。

---

## 4. なぜ「サービスアカウントのユーザー」なのか

Cloud Run や Cloud Build は、**必ずあるサービスアカウントの権限で**動きます。

- その SA が Artifact Registry に push したり、ログを書いたり、他の GCP API を呼んだりする。
- 「誰がその SA を使うことを許可するか」を決めるのが、**その SA リソースに対する IAM** です。

そこで、

- **「この SA を使う（ActAs）ことを許可する」ロール** ＝ **`roles/iam.serviceAccountUser`**
- 付与先：**WIF の principalSet**（＝GitHub のこのリポジトリから来た主体）
- 付与先リソース：**デフォルト Compute SA**（`PROJECT_NUMBER-compute@developer.gserviceaccount.com`）

とすると、「GitHub のこのリポジトリは、デフォルト Compute SA のふりをして Cloud Run / Cloud Build を実行してよい」と GCP が判断できます。

---

## 5. まとめ（図）

```
                    ┌──────────────────┐
                    │  GitHub Actions   │
                    │  (このリポジトリ)  │
                    └────────┬─────────┘
                             │ WIF で「誰か」を証明
                             ▼
                    ┌──────────────────┐
                    │  principalSet     │  ← プロジェクトに run.developer 等を付与
                    │  (WIF の主体)     │
                    └────────┬─────────┘
                             │
         ┌───────────────────┼───────────────────┐
         │                   │                   │
         ▼                   ▼                   ▼
  run.developer      cloudbuild.editor    artifactregistry.writer
  「Cloud Run を     「ビルドを実行して   「イメージを push して
   操作してよい」     よい」               よい」
         │                   │                   │
         └───────────────────┼───────────────────┘
                             │
                             │  「では、どの SA で動かすか？」
                             ▼
                    ┌──────────────────┐
                    │ デフォルト        │
                    │ Compute SA       │  ← この SA に
                    │ (XXX-compute@...) │     principalSet へ
                    └────────┬─────────┘       iam.serviceAccountUser を付与
                             │
                             │  ActAs「この SA として実行してよい」
                             ▼
                    ┌──────────────────┐
                    │ Cloud Run /      │
                    │ Cloud Build が   │
                    │ この SA で実行   │
                    └──────────────────┘
```

- **左側（run.developer など）**：プロジェクトに対する「何をしてよいか」の権限。
- **右側（iam.serviceAccountUser）**：その「何か」を**どのサービスアカウントとして**実行してよいかの権限（ActAs）。

両方そろうことで、GitHub Actions から安全に Cloud Run デプロイや Cloud Build を実行できます。

---

## 6. 実行コマンドの参照

上記の `roles/iam.serviceAccountUser` をデフォルト Compute SA に対して付与する処理は、  
**`scripts/grant-wif-iam-roles.ps1`** に含まれています。  
プロジェクト番号の取得と `$env:WIF_PRINCIPAL` の設定も同じスクリプト内で行っています。
