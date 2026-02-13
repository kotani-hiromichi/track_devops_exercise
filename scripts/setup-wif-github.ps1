# =============================================================================
# Workload Identity Federation (WIF) 設定 - GitHub 連携
# プロジェクト: ex-ai-training-program
# リポジトリ: kotani-hiromichi/track_devops_exercise に限定
# =============================================================================

$PROJECT_ID   = "ex-ai-training-program"
$GITHUB_USER  = "kotani-hiromichi"
$GITHUB_REPO  = "track_devops_exercise"
$WIF_POOL     = "github-pool-kotani"
$WIF_PROVIDER = "github-provider-kotani"

# リポジトリ完全名（attribute-condition で使用）
$REPO_FULL = "${GITHUB_USER}/${GITHUB_REPO}"

# -----------------------------------------------------------------------------
# 1. Workload Identity Pool の作成
# -----------------------------------------------------------------------------
# Pool は「外部の認証情報（ここでは GitHub）を信頼する窓口」のまとまりです。
# この中に、GitHub 用の OIDC Provider を登録します。
# -----------------------------------------------------------------------------
Write-Host "`n[1/2] Creating Workload Identity Pool..." -ForegroundColor Cyan
gcloud iam workload-identity-pools create $WIF_POOL `
  --project="$PROJECT_ID" `
  --location="global" `
  --display-name="GitHub Actions Pool" `
  --description="Pool for GitHub Actions OIDC (track_devops_exercise)"

# -----------------------------------------------------------------------------
# 2. GitHub 用 OIDC Provider の作成
# -----------------------------------------------------------------------------
# GitHub Actions が OIDC で発行するトークンを受け入れ、
# どのリポジトリからのリクエストかを判定するために
# attribute-mapping と attribute-condition を設定します。
# -----------------------------------------------------------------------------
Write-Host "`n[2/2] Creating GitHub OIDC Provider..." -ForegroundColor Cyan
$attrCondition = "assertion.repository=='${REPO_FULL}'"
gcloud iam workload-identity-pools providers create-oidc $WIF_PROVIDER `
  --project="$PROJECT_ID" `
  --location="global" `
  --workload-identity-pool="$WIF_POOL" `
  --display-name="GitHub Provider kotani" `
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" `
  --attribute-condition="$attrCondition" `
  --issuer-uri="https://token.actions.githubusercontent.com"

Write-Host "`nWIF setup completed." -ForegroundColor Green
Write-Host 'Workload Identity Pool resource name (for IAM binding):' -ForegroundColor Yellow
$poolPath = 'projects/' + $PROJECT_ID + '/locations/global/workloadIdentityPools/' + $WIF_POOL
Write-Host '  '$poolPath -ForegroundColor White
