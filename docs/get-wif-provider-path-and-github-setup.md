# WIF プロバイダのフルパス取得と GitHub Actions への登録

## 1. プロバイダのフルパスを取得する PowerShell コマンド

### パラメータを変数に設定してから取得する場合

```powershell
$PROJECT_ID   = "ex-ai-training-program"
$WIF_POOL     = "github-pool-kotani"
$WIF_PROVIDER = "github-provider-kotani"

# gcloud でプロバイダの name（フルパス）を取得
$providerPath = gcloud iam workload-identity-pools providers describe $WIF_PROVIDER `
  --workload-identity-pool=$WIF_POOL `
  --location="global" `
  --project=$PROJECT_ID `
  --format="value(name)"

Write-Host $providerPath
```

### 1行で取得する場合（値をそのままコピーしたいとき）

```powershell
gcloud iam workload-identity-pools providers describe github-provider-kotani --workload-identity-pool=github-pool-kotani --location=global --project=ex-ai-training-program --format="value(name)"
```

**出力例:**

```
projects/ex-ai-training-program/locations/global/workloadIdentityPools/github-pool-kotani/providers/github-provider-kotani
```

この 1 行が **WIF プロバイダのフルパス**です。GitHub の **Actions の変数** `WIF_PROVIDER` には、この文字列をそのまま登録します。

---

## 2. GitHub の Settings > Secrets and variables > Actions に登録する手順

ここでは **Variables（変数）** に `WIF_PROVIDER` を登録する手順です。  
（シークレットではなく変数で十分です。フルパスは機密情報ではないため。）

### 手順

1. **リポジトリの GitHub ページを開く**  
   `https://github.com/kotani-hiromichi/track_devops_exercise`

2. **Settings を開く**  
   リポジトリ上部の **Settings** タブをクリック。

3. **Actions の設定を開く**  
   左サイドバーの **Secrets and variables** → **Actions** をクリック。

4. **Variables タブを選ぶ**  
   **Variables** タブをクリック（Secrets ではなく Variables）。

5. **「New repository variable」をクリック**  
   右側の **New repository variable** ボタンをクリック。

6. **名前と値を入力**
   - **Name:** `WIF_PROVIDER`
   - **Value:** 上記 gcloud で取得したフルパス（例）  
     `projects/ex-ai-training-program/locations/global/workloadIdentityPools/github-pool-kotani/providers/github-provider-kotani`

7. **保存**  
   **Add variable** をクリックして保存。

### 補足

- **Secrets と Variables の違い**
  - **Secrets**: 値がマスクされ、ログに出力されない。トークンや鍵向け。
  - **Variables**: 値がそのまま参照される。フルパスなどの設定値向け。  
  WIF プロバイダのフルパスは機密ではないので、**Variables** で `WIF_PROVIDER` を登録する運用で問題ありません。

- ワークフローでの参照例:
  ```yaml
  env:
    WIF_PROVIDER: ${{ vars.WIF_PROVIDER }}
  ```
  または
  ```yaml
  id: auth
  uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ vars.WIF_PROVIDER }}
    service_account: ...
  ```

以上で、WIF プロバイダのフルパス取得と GitHub Actions への登録が完了します。
