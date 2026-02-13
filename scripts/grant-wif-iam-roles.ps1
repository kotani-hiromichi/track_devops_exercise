# =============================================================================
# WIF principalSet に IAM ロールを付与するスクリプト
# プロジェクト: ex-ai-training-program
# リポジトリ: kotani-hiromichi/track_devops_exercise に限定された WIF に権限を付与
# =============================================================================

$PROJECT_ID   = "ex-ai-training-program"
$GITHUB_USER  = "kotani-hiromichi"
$GITHUB_REPO  = "track_devops_exercise"
$WIF_POOL     = "github-pool-kotani"
$REPO_NAME    = "cloud-run-source-deploy-kotani-0213"

# リポジトリ完全名（principalSet の attribute.repository に使用）
$REPO_FULL = "${GITHUB_USER}/${GITHUB_REPO}"

# -----------------------------------------------------------------------------
# プロジェクト番号の取得と WIF 識別子（principalSet）の構築
# -----------------------------------------------------------------------------
Write-Host "`n[0] Getting project number and setting WIF principalSet..." -ForegroundColor Cyan
$PROJECT_NUMBER = gcloud projects describe $PROJECT_ID --format="value(projectNumber)"
if (-not $PROJECT_NUMBER) {
    Write-Error "Failed to get project number. Check PROJECT_ID and gcloud auth."
    exit 1
}
Write-Host "  Project number: $PROJECT_NUMBER" -ForegroundColor Gray

# principalSet: このリポジトリから来た WIF 主体の集合を指す識別子
# attribute.repository の値は "owner/repo" のため、スラッシュは %2F でエンコード
$REPO_ESCAPED = "${GITHUB_USER}%2F${GITHUB_REPO}"
$env:WIF_PRINCIPAL = "principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/$WIF_POOL/attribute.repository/$REPO_ESCAPED"
Write-Host "  WIF_PRINCIPAL = $env:WIF_PRINCIPAL" -ForegroundColor Gray

# -----------------------------------------------------------------------------
# 1. 各種ロールを WIF principalSet に付与（プロジェクトレベル）
# -----------------------------------------------------------------------------
$ROLES = @(
    "roles/artifactregistry.writer",   # Artifact Registry 書き込み
    "roles/run.developer",             # Cloud Run 開発者
    "roles/cloudbuild.builds.editor",  # Cloud Build 編集者
    "roles/storage.admin",             # Storage 管理者
    "roles/serviceusage.serviceUsageConsumer",  # サービス利用
    "roles/logging.viewer",            # ログ閲覧
    "roles/viewer"                     # プロジェクト閲覧
)

$i = 1
foreach ($ROLE in $ROLES) {
    Write-Host "`n[$i/$($ROLES.Count + 1)] Granting $ROLE..." -ForegroundColor Cyan
    gcloud projects add-iam-policy-binding $PROJECT_ID `
        --member="$env:WIF_PRINCIPAL" `
        --role="$ROLE" `
        --condition=None
    if ($LASTEXITCODE -ne 0) { Write-Warning "  Error granting $ROLE" }
    $i++
}

# -----------------------------------------------------------------------------
# 2. デフォルト Compute SA に対する ActAs（roles/iam.serviceAccountUser）
# -----------------------------------------------------------------------------
# Cloud Run / Cloud Build が「このサービスアカウントとして」実行するために必要です。
# 詳細は docs/why-service-account-user-role.md を参照してください。
# -----------------------------------------------------------------------------
$DEFAULT_COMPUTE_SA = "${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"
Write-Host "`n[$i/$($ROLES.Count + 1)] Granting roles/iam.serviceAccountUser on default Compute SA..." -ForegroundColor Cyan
Write-Host "  Target SA: $DEFAULT_COMPUTE_SA" -ForegroundColor Gray
gcloud iam service-accounts add-iam-policy-binding $DEFAULT_COMPUTE_SA `
    --project="$PROJECT_ID" `
    --member="$env:WIF_PRINCIPAL" `
    --role="roles/iam.serviceAccountUser"
if ($LASTEXITCODE -ne 0) { Write-Warning "  Error granting roles/iam.serviceAccountUser" }

Write-Host "`nAll role bindings completed." -ForegroundColor Green
Write-Host "WIF_PRINCIPAL is available in this session: $env:WIF_PRINCIPAL" -ForegroundColor Yellow
