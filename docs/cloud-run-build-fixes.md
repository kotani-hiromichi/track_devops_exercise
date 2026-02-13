# Cloud Run ビルドエラー対応メモ

## 原因となっていた点

1. **HTTP サーバーがない**  
   `src/main.py` は `add()` 関数のみで、Cloud Run が要求する「PORT で Listen する HTTP サーバー」がなかった。

2. **requirements.txt がない**  
   依存関係が定義されておらず、ビルドパック／Docker ビルドでパッケージがインストールされなかった。

3. **Dockerfile がない**  
   `gcloud run deploy --source .` は Dockerfile があればそれを使う。なければビルドパックに依存するが、上記の不足でビルドが失敗していた。

4. **PORT の扱い**  
   Cloud Run はコンテナに環境変数 `PORT`（多くの場合 8080）を渡す。アプリはこの PORT で Listen する必要がある。

## 実施した修正

| ファイル | 内容 |
|----------|------|
| **requirements.txt** | `flask`, `gunicorn` を追加。Web サーバーと本番用 WSGI サーバーを用意。 |
| **app.py**（ルート） | Flask アプリ。`/` でヘルスチェック、`/add` で `src.main.add` を公開。`PORT` は gunicorn の CMD で使用。 |
| **Dockerfile** | Python 3.12-slim ベース。`requirements.txt` で依存インストール。`gunicorn app:app --bind 0.0.0.0:${PORT}` で起動。 |
| **.dockerignore** | ビルドに不要な `.git`, `docs`, `scripts` などを除外。 |
| **src/__init__.py** | `from src.main import add` が動くように `src` をパッケージ化。 |

## 動作確認の例（ローカル）

```bash
pip install -r requirements.txt
PORT=8080 python app.py
# または
gunicorn --bind 0.0.0.0:8080 app:app
```

- `GET /` → `{"status":"ok", ...}`
- `GET /add?a=1&b=2&c=3` → `{"result":6}`

## デプロイ

既存の `.github/workflows/deploy.yml` の `gcloud run deploy --source .` のままで、リポジトリルートに Dockerfile があるため Cloud Build が Docker ビルドを行い、正しくデプロイされます。
