# docker build -t eclipse-mat:1.16.1 .
# docker run --rm -v ./input:/input -v ./reports:/reports eclipse-mat:1.16.1 /input/sun_jdk6_18_x64.hprof

      FROM eclipse-temurin:21-jdk

# MAT のダウンロードURL（最新版は公式サイトから確認）
ARG MAT_VERSION=1.16.1
ARG MAT_VERSION_DETAIL=${MAT_VERSION}.20250109

# ワークディレクトリ設定
WORKDIR /opt/mat

# MAT をダウンロード・展開
RUN apt-get update && \
    apt-get install -y unzip wget && \
    # アーキテクチャを動的に取得（aarch64 または x86_64）
    ARCH=$(uname -m) && \
    echo "Detected architecture: ${ARCH}" && \
    MAT_URL="https://www.eclipse.org/downloads/download.php?file=/mat/${MAT_VERSION}/rcp/MemoryAnalyzer-${MAT_VERSION_DETAIL}-linux.gtk.${ARCH}.zip&r=1" && \
    echo "Downloading MAT from: ${MAT_URL}" && \
    wget -O mat.zip "${MAT_URL}" && \
    unzip mat.zip -d /opt && \
    rm -f mat.zip && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# レポート出力用ディレクトリ
RUN mkdir -p /reports

# PATH に追加（任意）
ENV PATH=/opt/mat:${PATH}

# ヒープダンプとレポート出力用のエントリーポイント
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# デフォルトコマンド：ヘルプ表示
ENTRYPOINT ["/entrypoint.sh"]
