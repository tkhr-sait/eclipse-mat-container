# Eclipse MAT Docker

[Eclipse Memory Analyzer Tool (MAT)](https://eclipse.dev/mat/) を Docker コンテナで実行するための環境

**GUI モード（Web ブラウザ）** と **CLI モード** の両方に対応しています。

## クイックスタート

### GUI モードで起動（デフォルト）

`docker compose up -d` で GUI モードが自動的に起動します。

```bash
# 起動
docker compose up -d

# 停止
docker compose down
```

起動後、ブラウザで **http://localhost:6901** にアクセス

ヒープダンプファイルは `input/` ディレクトリに配置してください。

### CLI モードで実行（明示起動）

CLI モードは `docker compose run` で明示的に実行します。レポートは入力ファイルと同じディレクトリに生成されます。

```bash
# ディレクトリ作成とヒープダンプ配置
mkdir -p input
cp /path/to/your/heap.hprof input/

# 解析実行（ワンショット）
docker compose run --rm eclipse-mat-cli /home/matuser/input/heap.hprof

# レポート確認（入力ファイルと同じディレクトリに生成される）
ls -la input/
```

#### 生成されるレポート

- **Leak Suspects** - メモリリーク疑いの解析
- **Overview** - 概要レポート
- **Top Components** - トップコンポーネント解析

## メモリ設定

Eclipse MAT が使用するヒープメモリサイズは環境変数 `MAT_MEMORY` で指定できます。デフォルトは **4g**（4GB）です。

### docker-compose.yml で設定

```yaml
environment:
  - MAT_MEMORY=8g # 8GBに変更
```

**推奨メモリサイズ**: 解析するヒープダンプのサイズの 1.5〜2 倍程度
