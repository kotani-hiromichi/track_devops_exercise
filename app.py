"""
Cloud Run 用 Web アプリケーションエントリポイント.
環境変数 PORT でバインドし、src.main.add を HTTP で公開する。
"""
import os
from flask import Flask, request, jsonify

from src.main import add

app = Flask(__name__)


@app.route("/")
def index():
    return {"status": "ok", "message": "python-microservice-kotani-0213"}


@app.route("/add", methods=["GET", "POST"])
def add_route():
    """クエリまたは JSON で a, b, c を受け取り add() の結果を返す。"""
    if request.method == "GET":
        a = request.args.get("a", 0, type=int)
        b = request.args.get("b", 0, type=int)
        c = request.args.get("c", 0, type=int)
    else:
        data = request.get_json(silent=True) or {}
        a = int(data.get("a", 0))
        b = int(data.get("b", 0))
        c = int(data.get("c", 0))
    result = add(a, b, c)
    return jsonify({"result": result})


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8080))
    app.run(host="0.0.0.0", port=port, debug=False)
