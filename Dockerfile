# docker build -t eclipse-mat:1.16.1 .
# CLI
# docker run --rm -e CLI=true -e MAT_MEMORY=4g -v ./input:/home/matuser/input eclipse-mat:1.16.1 /home/matuser/input/sun_jdk6_18_x64.hprof
# GUI
# docker run --rm -e MAT_MEMORY=4g -v ./input:/home/matuser/input -p 6901:6901 eclipse-mat:1.16.1
FROM eclipse-temurin:21-jre

# MAT のダウンロードURL（最新版は公式サイトから確認）
ARG MAT_VERSION=1.16.1
ARG MAT_VERSION_DETAIL=${MAT_VERSION}.20250109

# ワークディレクトリ設定
WORKDIR /opt/mat

# MAT をダウンロード・展開
RUN apt-get update && \
    apt-get install -y unzip wget curl \
    # GUI 実行に必要なライブラリ
    libx11-6 libxrender1 libxtst6 libxi6 \
    libgtk-3-0 \
    dbus-x11 xauth \
    # WebKit GTK for Eclipse SWT browser
    libwebkit2gtk-4.1-0 \
    # Mesa ソフトウェアレンダラー (llvmpipe) - GPU非使用でのレンダリング用
    libgl1-mesa-dri libgl1 libglx-mesa0 \
    mesa-utils \
    # kasmvnc 用
    openbox \
    xterm \
    ssl-cert \
    # 日本語ロケール用
    locales && \
    # 日本語ロケール生成
    locale-gen ja_JP.UTF-8 && \
    # kasmvnc のインストール
    ARCH=$(uname -m) && \
    if [ "$ARCH" = "x86_64" ]; then \
        KASM_ARCH="amd64"; \
    elif [ "$ARCH" = "aarch64" ]; then \
        KASM_ARCH="arm64"; \
    fi && \
    wget "https://github.com/kasmtech/KasmVNC/releases/download/v1.4.0/kasmvncserver_noble_1.4.0_${KASM_ARCH}.deb" -O /tmp/kasmvnc.deb && \
    apt-get install -y /tmp/kasmvnc.deb && \
    rm /tmp/kasmvnc.deb && \
    # MAT のダウンロード
    echo "Detected architecture: ${ARCH}" && \
    MAT_URL="https://www.eclipse.org/downloads/download.php?file=/mat/${MAT_VERSION}/rcp/MemoryAnalyzer-${MAT_VERSION_DETAIL}-linux.gtk.${ARCH}.zip&r=1" && \
    echo "Downloading MAT from: ${MAT_URL}" && \
    wget -O mat.zip "${MAT_URL}" && \
    unzip mat.zip -d /opt && \
    rm -f mat.zip && \
    # Pleiades プラグインのダウンロード・展開
    echo "Downloading Pleiades plugin..." && \
    wget https://ftp.jaist.ac.jp/pub/mergedoc/pleiades/build/stable/pleiades.zip -O /tmp/pleiades.zip && \
    unzip -q /tmp/pleiades.zip -d /tmp/pleiades && \
    echo "Installing Pleiades plugin to MAT..." && \
    cp -r /tmp/pleiades/plugins/* /opt/mat/plugins/ && \
    cp -r /tmp/pleiades/features/* /opt/mat/features/ && \
    rm -rf /tmp/pleiades* && \
    # MemoryAnalyzer.ini に Pleiades 設定を追加（絶対パス）
    echo "-javaagent:/opt/mat/plugins/jp.sourceforge.mergedoc.pleiades/pleiades.jar" >> /opt/mat/MemoryAnalyzer.ini && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# kasmvnc 用のユーザー作成と設定
RUN useradd -m -s /bin/bash matuser && \
    mkdir -p /home/matuser/.vnc && \
    chown -R matuser:matuser /home/matuser

# SSL証明書を生成し、matuserがアクセスできるようにする
RUN make-ssl-cert generate-default-snakeoil && \
    usermod -a -G ssl-cert matuser

# kasmvnc の設定ファイルを作成（非対話モード、HTTP通信）
# SecurityTypes None により VNC/HTTP 認証は不要
RUN mkdir -p /home/matuser/.vnc && \
    echo "command_line:" > /home/matuser/.vnc/kasmvnc.yaml && \
    echo "  prompt: false" >> /home/matuser/.vnc/kasmvnc.yaml && \
    echo "network:" >> /home/matuser/.vnc/kasmvnc.yaml && \
    echo "  ssl:" >> /home/matuser/.vnc/kasmvnc.yaml && \
    echo "    require_ssl: false" >> /home/matuser/.vnc/kasmvnc.yaml && \
    echo "  protocol: http" >> /home/matuser/.vnc/kasmvnc.yaml && \
    chown -R matuser:matuser /home/matuser/.vnc && \
    # VNCユーザーを作成（SecurityTypes Noneでも内部的に必要）
    su - matuser -c "mkdir -p ~/.vnc && echo -e 'kasmvnc\nkasmvnc' | vncpasswd -u matuser -w -r"

# MAT ディレクトリの所有権設定
RUN chown -R matuser:matuser /opt/mat

# PATH と JAVA_HOME を設定
ENV PATH=/opt/mat:${PATH}
ENV JAVA_HOME=/opt/java/openjdk

# ヒープダンプとレポート出力用のエントリーポイント
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# rootユーザーのままにして、entrypoint.shでmatuserに切り替える
WORKDIR /home/matuser

# デフォルトコマンド：ヘルプ表示
ENTRYPOINT ["/entrypoint.sh"]
