# デプロイ変更を GitHub に反映する Git コマンド

`.github/workflows/deploy.yml` を追加したあと、以下でリモートに反映しデプロイを開始します。

## 1. 変更をステージング

```bash
git add .github/workflows/deploy.yml
```

## 2. コミット

```bash
git commit -m "Add Cloud Run deploy workflow (WIF auth)"
```

## 3. リモートにプッシュ（main に反映してワークフロー実行）

```bash
git push origin main
```

---

## 別ブランチで作業している場合

現在のブランチが `main` でないときは、main にマージしてからプッシュするか、ワークフローが `main` への push でトリガーされるため main にプッシュする必要があります。

```bash
# 現在のブランチを確認
git branch

# main に切り替えてマージしてからプッシュ
git checkout main
git merge <あなたのブランチ名>
git push origin main
```

または、現在のブランチの内容を main に反映してプッシュ:

```bash
git push origin <現在のブランチ名>:main
```

---

## 補足

- **Secrets の確認**: GitHub の **Settings > Secrets and variables > Actions** で `WIF_PROVIDER` が登録されていることを確認してください。Variables に登録した場合は、ワークフロー内を `vars.WIF_PROVIDER` に変更する必要があります。
- **実行確認**: プッシュ後は **Actions** タブで「Deploy to Cloud Run」ワークフローの実行状況を確認できます。
