# Eclipse MAT Docker

Eclipse Memory Analyzer Tool (MAT) を Docker コンテナで実行するための環境

## 使用方法

GitHub Container Registry から公開されているイメージを使用：

```bash
docker run --rm \
  -v ./input:/input \
  -v ./reports:/reports \
  ghcr.io/tkhr-sait/eclipse-mat-container:latest /input/heap.hprof
```

### 使用例

```bash
# ディレクトリ作成とヒープダンプ配置
mkdir -p input reports
cp /path/to/your/heap.hprof input/

# 解析実行
docker run --rm \
  -v ./input:/input \
  -v ./reports:/reports \
  ghcr.io/tkhr-sait/eclipse-mat-container:latest /input/heap.hprof

# レポート確認
ls -la reports/
```

### パラメータ

- `./input` - ヒープダンプファイル (.hprof) を配置するディレクトリ
- `./reports` - 生成されたレポートの出力先ディレクトリ

## 生成されるレポート

- **Leak Suspects** - メモリリーク疑いの解析
- **Overview** - 概要レポート
- **Top Components** - トップコンポーネント解析

## 動作環境

- Docker
- マルチアーキテクチャ対応 (x86_64 / aarch64)
