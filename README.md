# Eclipse MAT Docker

Eclipse Memory Analyzer Tool (MAT) を Docker コンテナで実行するための環境

**GUI モード（Web ブラウザ）** と **CLI モード** の両方に対応しています。

## GUI モード（デフォルト）

Eclipse MAT を Web ブラウザから GUI で操作できます。

### 基本的な起動方法

```bash
docker run --rm \
  -p 6901:6901 \
  -v ./input:/input \
  ghcr.io/tkhr-sait/eclipse-mat-container:latest
```

起動後、ブラウザで以下の URL にアクセス：
- **http://localhost:6901** （パスワード不要）

### 各 OS での起動方法

#### Linux

```bash
# ディレクトリ作成
mkdir -p input

# ヒープダンプファイルを配置（オプション）
cp /path/to/your/heap.hprof input/

# GUI モードで起動
docker run --rm \
  -p 6901:6901 \
  -v ./input:/input \
  ghcr.io/tkhr-sait/eclipse-mat-container:latest

# ブラウザで http://localhost:6901 を開く
```

#### macOS

```bash
# ディレクトリ作成
mkdir -p input

# ヒープダンプファイルを配置（オプション）
cp /path/to/your/heap.hprof input/

# GUI モードで起動
docker run --rm \
  -p 6901:6901 \
  -v ./input:/input \
  ghcr.io/tkhr-sait/eclipse-mat-container:latest

# ブラウザで http://localhost:6901 を開く
```

#### Windows (WSL2)

```powershell
# PowerShell または WSL2 ターミナルで実行

# ディレクトリ作成
mkdir input

# ヒープダンプファイルを配置（オプション）
cp /path/to/your/heap.hprof input/

# GUI モードで起動
docker run --rm `
  -p 6901:6901 `
  -v ${PWD}/input:/input `
  ghcr.io/tkhr-sait/eclipse-mat-container:latest

# ブラウザで http://localhost:6901 を開く
```

**注意**: WSL2 の場合、Windows のブラウザから `http://localhost:6901` でアクセス可能です。

## CLI モード

自動解析でレポートを生成したい場合は、環境変数 `CLI=true` を指定します。

### 使用例

```bash
# ディレクトリ作成とヒープダンプ配置
mkdir -p input reports
cp /path/to/your/heap.hprof input/

# 解析実行
docker run --rm \
  -e CLI=true \
  -v ./input:/input \
  -v ./reports:/reports \
  ghcr.io/tkhr-sait/eclipse-mat-container:latest /input/heap.hprof

# レポート確認
ls -la reports/
```

### パラメータ

- `./input` - ヒープダンプファイル (.hprof) を配置するディレクトリ
- `./reports` - 生成されたレポートの出力先ディレクトリ

### 生成されるレポート

- **Leak Suspects** - メモリリーク疑いの解析
- **Overview** - 概要レポート
- **Top Components** - トップコンポーネント解析

## 動作環境

- Docker
- マルチアーキテクチャ対応 (x86_64 / aarch64)
