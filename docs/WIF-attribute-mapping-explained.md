# Workload Identity Federation：attribute-mapping と attribute-condition の解説

このドキュメントでは、**なぜこのリポジトリに限定するために `--attribute-mapping` と `--attribute-condition` が必要なのか**を、初心者向けに説明します。

---

## 全体の流れ（イメージ）

```
[GitHub Actions]  →  「このワークフローは kotani-hiromichi/track_devops_exercise の main から動いています」
                    →  [Google Cloud] が「その情報」を見て「このリポジトリだけ OK」と判断
                    →  一時的な GCP の権限を付与
```

- **attribute-mapping**：GitHub が渡す「情報（クレーム）」を、GCP が使える形に**写し取る**設定  
- **attribute-condition**：写し取った情報を使って「**このリポジトリのときだけ許可する**」という**条件**を書く設定  

この 2 つがあるから、「このリポジトリに限定」できます。

---

## 1. GitHub が渡す「トークン」の中身（OIDC クレーム）

GitHub Actions で `id-token: write` を有効にすると、GitHub が **OIDC トークン**を発行します。  
このトークンには、例えば次のような**クレーム（属性）**が入っています。

| クレーム名 | 例（意味） |
|------------|------------|
| `sub` | `repo:kotani-hiromichi/track_devops_exercise:ref:refs/heads/main`（どのリポジトリ・どの ref か） |
| `repository` | `kotani-hiromichi/track_devops_exercise`（リポジトリの完全名） |
| `repository_owner` | `kotani-hiromichi`（オーナー） |
| `actor` | ワークフローを動かした GitHub ユーザー名 |

このままでは GCP は「どのリポジトリか」を判定できないので、  
**「このトークンの中のどのクレームを、GCP のどの属性名に写し取るか」**を決める必要があります。それが **attribute-mapping** です。

---

## 2. attribute-mapping（属性の写し取り）とは

**「GitHub のトークンに含まれるクレーム（assertion.〇〇）を、GCP 側の属性（attribute.〇〇 や google.subject）に写し取る」**設定です。

### 今回の設定の意味

```text
google.subject=assertion.sub
attribute.actor=assertion.actor
attribute.repository=assertion.repository
attribute.repository_owner=assertion.repository_owner
```

| 左辺（GCP 側） | 右辺（GitHub トークン） | 役割 |
|----------------|-------------------------|------|
| `google.subject` | `assertion.sub` | 「誰か」を一意に表す ID。IAM の主体として使う。 |
| `attribute.repository` | `assertion.repository` | **どのリポジトリか**（例: `kotani-hiromichi/track_devops_exercise`）。ここを条件に使う。 |
| `attribute.actor` | `assertion.actor` | どの GitHub ユーザーがトリガーしたか（必要なら条件に使える）。 |
| `attribute.repository_owner` | `assertion.repository_owner` | オーナー（必要なら条件に使える）。 |

- **なぜ必要か**  
  GCP は「トークンの中の `repository` が何か」をそのままでは知りません。  
  **mapping で `attribute.repository` に写し取る**ことで、  
  次のステップの「条件（attribute-condition）」で「このリポジトリだけ」と判定できるようになります。  
  → **「このリポジトリに限定する」ために、まず mapping で `repository` を GCP の属性として取り込む必要があります。**

---

## 3. attribute-condition（許可する条件）とは

**「写し取った属性を使って、いつこの Provider を信頼するか」**を決める条件式です。  
条件を満たすトークンだけが「この WIF 経由で GCP にアクセスしてよい」とみなされます。

### 今回の設定の意味

```text
assertion.repository=='kotani-hiromichi/track_devops_exercise'
```

- **assertion.repository**  
  GitHub トークンの中の `repository` クレーム（まだ mapping 前の「元の値」を条件で参照するときは `assertion.〇〇` を使います）。  
- **== 'kotani-hiromichi/track_devops_exercise'**  
  その値が、指定したリポジトリの完全名と**完全一致**するときだけ OK、という意味です。

つまり、

- **このリポジトリ（kotani-hiromichi/track_devops_exercise）から来たトークン** → 条件を満たす → この WIF で GCP にアクセス可能  
- **他のリポジトリや他人のフォークから来たトークン** → 条件を満たさない → この WIF ではアクセス不可  

となるため、**「このリポジトリに限定する」ために attribute-condition が必要**です。

---

## 4. まとめ：なぜこのリポジトリに限定するために両方必要か

| 設定 | 役割 | リポジトリ限定との関係 |
|------|------|------------------------|
| **attribute-mapping** | GitHub のトークン内の `repository` などを、GCP が使える属性（および `google.subject`）に写し取る | 「どのリポジトリか」を GCP が判定できるようにする**土台**。これがないと条件を書けない。 |
| **attribute-condition** | 写し取った（または assertion の）値を使って「許可する／しない」を決める | **「このリポジトリのときだけ許可」**というルールを書く部分。 |

- **mapping だけ**だと、「どのリポジトリか」は分かっても「そのリポジトリだけ許可」という制限がかからない。  
- **condition だけ**だと、GCP 側に「リポジトリ名」が渡っていないので、条件で判定できない。  

そのため、**「このリポジトリに限定する」ためには、attribute-mapping で `repository` を取り込み、attribute-condition で `assertion.repository=='kotani-hiromichi/track_devops_exercise'` のように書く、という両方が必要**です。

---

## 5. 実行コマンド（PowerShell）の参照

実際の作成コマンドは `scripts/setup-wif-github.ps1` にまとめてあります。  
パラメータ（PROJECT_ID, GITHUB_USER, GITHUB_REPO, WIF_POOL, WIF_PROVIDER）はスクリプト先頭で変更できます。
