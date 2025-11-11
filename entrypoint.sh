#!/bin/bash

# root起動時のUID/GID自動調整（ホストとの権限問題を解消）
if [ "$(id -u)" = "0" ] && [ -z "$_REEXEC" ]; then
    # UID/GID検出の優先順位:
    # 1. 環境変数 HOST_UID/HOST_GID（明示指定された場合）
    # 2. /home/matuser/input ディレクトリの所有権
    # 3. デフォルト値 1000:1000

    TARGET_UID=${HOST_UID:-$(stat -c '%u' /home/matuser/input 2>/dev/null || echo 1000)}
    TARGET_GID=${HOST_GID:-$(stat -c '%g' /home/matuser/input 2>/dev/null || echo 1000)}

    echo "Adjusting container user to UID:GID = $TARGET_UID:$TARGET_GID"

    # matuserのUID/GIDを動的に変更
    usermod -u "$TARGET_UID" matuser 2>/dev/null
    groupmod -g "$TARGET_GID" matuser 2>/dev/null
    chown -R matuser:matuser /home/matuser /opt/mat 2>/dev/null || true

    # D-Bus システムバスの初期化（GUIモードのみ、root権限が必要なため、ユーザー切り替え前に実行）
    # Windows/WSL2環境でのGTK/GDKアプリケーションのクラッシュ対策
    if [ "$CLI" != "true" ]; then
        if [ ! -d /run/dbus ]; then
            mkdir -p /run/dbus
        fi
        rm -f /var/run/dbus/pid 2>/dev/null || true
        dbus-daemon --system --fork 2>/dev/null || echo "System D-Bus already running or not needed"
    fi

    # matuserとして再実行（環境変数を保持）
    export _REEXEC=1
    export HOME=/home/matuser
    export CLI="$CLI"
    export PATH="$PATH"
    export JAVA_HOME="$JAVA_HOME"
    export MAT_MEMORY="$MAT_MEMORY"
    exec su matuser -c "export CLI='$CLI' && export PATH='$PATH' && export JAVA_HOME='$JAVA_HOME' && export MAT_MEMORY='$MAT_MEMORY' && cd /home/matuser && exec $0 $*"
fi

# MAT メモリ設定（環境変数で指定、デフォルトは4g）
MAT_MEMORY=${MAT_MEMORY:-4g}
echo "Configuring Eclipse MAT with ${MAT_MEMORY} heap memory..."

# MemoryAnalyzer.ini の -Xmx 設定を動的に更新
if [ -f /opt/mat/MemoryAnalyzer.ini ]; then
    # 既存の -Xmx 行を新しい値で置換
    sed -i "s/^-Xmx.*/-Xmx${MAT_MEMORY}/" /opt/mat/MemoryAnalyzer.ini

    # 初期ヒープサイズ（Xmxの50%）を計算して設定
    MAT_MEMORY_NUM=$(echo ${MAT_MEMORY} | sed 's/[^0-9]//g')
    MAT_MEMORY_UNIT=$(echo ${MAT_MEMORY} | sed 's/[0-9]//g')
    MAT_MEMORY_INIT=$((MAT_MEMORY_NUM / 2))${MAT_MEMORY_UNIT}

    # JVM最適化オプションを追加（既存の-Xmsがあれば置換、なければ追加）
    if grep -q "^-Xms" /opt/mat/MemoryAnalyzer.ini; then
        sed -i "s/^-Xms.*/-Xms${MAT_MEMORY_INIT}/" /opt/mat/MemoryAnalyzer.ini
    else
        sed -i "/^-Xmx/a -Xms${MAT_MEMORY_INIT}" /opt/mat/MemoryAnalyzer.ini
    fi

    # その他の最適化オプションを追加（存在しない場合のみ）
    grep -q "^-XX:-UseGCOverheadLimit" /opt/mat/MemoryAnalyzer.ini || \
        echo "-XX:-UseGCOverheadLimit" >> /opt/mat/MemoryAnalyzer.ini

    grep -q "^-XX:+UseG1GC" /opt/mat/MemoryAnalyzer.ini || \
        echo "-XX:+UseG1GC" >> /opt/mat/MemoryAnalyzer.ini

    grep -q "^-XX:MaxGCPauseMillis" /opt/mat/MemoryAnalyzer.ini || \
        echo "-XX:MaxGCPauseMillis=200" >> /opt/mat/MemoryAnalyzer.ini

    grep -q "^-XX:+UseStringDeduplication" /opt/mat/MemoryAnalyzer.ini || \
        echo "-XX:+UseStringDeduplication" >> /opt/mat/MemoryAnalyzer.ini

    grep -q "^-XX:MaxMetaspaceSize" /opt/mat/MemoryAnalyzer.ini || \
        echo "-XX:MaxMetaspaceSize=256m" >> /opt/mat/MemoryAnalyzer.ini

    echo "JVM optimization options applied: G1GC, StringDeduplication, GCOverheadLimit disabled"
fi

# CLI モードのチェック（環境変数で明示的に指定された場合のみ）
if [ "$CLI" = "true" ]; then
    # CLI モード
    # ヘルプ表示
    if [ $# -eq 0 ]; then
        echo "Usage: docker run --rm -e CLI=true -v <host-dir>:/home/matuser/input eclipse-mat /home/matuser/input/<file>.hprof"
        echo ""
        echo "Available modes:"
        echo "  GUI mode (default) - Web-based GUI on port 6901"
        echo "  CLI mode          - Run with -e CLI=true for automated analysis"
        echo ""
        echo "Reports are generated in the same directory as the input file."
        echo ""
        echo "Example (CLI): docker run --rm -e CLI=true -v ./input:/home/matuser/input eclipse-mat /home/matuser/input/heap.hprof"
        echo "Example (GUI): docker run --rm -p 6901:6901 -v ./input:/home/matuser/input eclipse-mat"
        echo ""
        echo "Note: UID/GID is automatically detected from mounted volumes for proper file permissions."
        exit 1
    fi
    # CLI モードの処理は後続のコードで実行
else
    # GUI モード（デフォルト）
    echo "🖥️  Starting Eclipse MAT in GUI mode..."
    echo "🌐 Access via web browser: http://localhost:6901"
    echo ""

    # 日本語環境変数を設定
    export LANG=ja_JP.UTF-8
    export LC_ALL=ja_JP.UTF-8

    # ソフトウェアレンダリング強制（GPU/ハードウェアアクセラレーション無効化）
    # Windows/WSL2環境でのX関連エラー対策
    export LIBGL_ALWAYS_SOFTWARE=1
    export GALLIUM_DRIVER=llvmpipe
    export GDK_RENDERING=image
    export WEBKIT_DISABLE_COMPOSITING_MODE=1
    export WEBKIT_DISABLE_DMABUF_RENDERER=1
    echo "Software rendering mode enabled (GPU disabled for compatibility)"

    # D-Bus セッションバスの初期化（matuser権限で実行）
    # Windows/WSL2環境でのGTK/GDKアプリケーションのクラッシュ対策
    echo "Initializing D-Bus session..."

    # セッションバスの起動
    if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
        eval $(dbus-launch --sh-syntax 2>/dev/null) || echo "D-Bus session launch failed (may not be critical)"
        export DBUS_SESSION_BUS_ADDRESS
    fi

    echo "D-Bus session initialized"
    echo "  User: $(whoami) (UID: $(id -u))"
    echo "  DBUS_SESSION_BUS_ADDRESS=${DBUS_SESSION_BUS_ADDRESS:-<not set>}"

    # Openbox の設定を作成（アプリケーションを最大化）
    # VNC起動前に作成しておく必要がある
    mkdir -p ~/.config/openbox
    cat > ~/.config/openbox/rc.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config xmlns="http://openbox.org/3.4/rc">
  <applications>
    <application class="*">
      <maximized>true</maximized>
      <decor>no</decor>
    </application>
  </applications>
</openbox_config>
EOF

    # VNC用のxstartupスクリプトを作成（VNCがデスクトップ環境を起動するため）
    # Windows/WSL2環境でのDISPLAYエラー対策：VNCセッション内でopenboxを起動
    echo "Creating VNC xstartup script..."
    cat > ~/.vnc/xstartup << 'XSTARTUP'
#!/bin/bash

# ソフトウェアレンダリング環境変数（GPU不要化）
export LIBGL_ALWAYS_SOFTWARE=1
export GALLIUM_DRIVER=llvmpipe
export GDK_RENDERING=image
export WEBKIT_DISABLE_COMPOSITING_MODE=1
export WEBKIT_DISABLE_DMABUF_RENDERER=1

# Openboxをメインプロセスとして起動（VNCセッションと統合）
exec openbox
XSTARTUP
    chmod +x ~/.vnc/xstartup
    echo "VNC xstartup created"

    # kasmvnc の起動（非対話的に起動）
    export DISPLAY=:1
    # 非対話モードで起動（kasmvnc.yamlで prompt: false を設定済み）
    echo "Starting VNC server on $DISPLAY..."
    echo "VNC will be accessible at http://localhost:6901"
    echo "  (xstartup will automatically launch Openbox)"
    vncserver $DISPLAY -depth 24 -geometry 1920x1080 \
        -websocketPort 6901 \
        -interface 0.0.0.0 \
        -select-de manual \
        -SecurityTypes None \
        -disableBasicAuth \
        -httpd /usr/share/kasmvnc/www \
        -sslOnly 0 2>&1 | tee /tmp/vncserver.log

    VNC_EXIT_CODE=$?
    if [ $VNC_EXIT_CODE -ne 0 ]; then
        echo "========================================="
        echo "❌ VNC server failed to start"
        echo "Exit code: $VNC_EXIT_CODE"
        echo "========================================="
        echo ""
        echo "VNC startup log:"
        cat /tmp/vncserver.log 2>/dev/null || echo "No startup log found"
        echo ""
        echo "VNC session log:"
        cat ~/.vnc/*.log 2>/dev/null || echo "No session log files found"
        echo ""
        echo "Environment info:"
        echo "  DISPLAY=$DISPLAY"
        echo "  LIBGL_ALWAYS_SOFTWARE=$LIBGL_ALWAYS_SOFTWARE"
        echo "  User: $(whoami), UID: $(id -u), GID: $(id -g)"
        echo ""
        echo "Troubleshooting tips:"
        echo "  1. Check if port 6901 is already in use"
        echo "  2. Ensure Docker has enough resources (memory/CPU)"
        echo "  3. For WSL2 on Windows: restart Docker Desktop"
        echo "========================================="
        exit 1
    fi

    # VNC サーバーが起動するまで待機（ソケットファイルの存在確認）
    echo "Waiting for VNC server to be ready..."
    X11_SOCKET="/tmp/.X11-unix/X1"
    MAX_WAIT=30
    WAIT_COUNT=0

    while [ ! -S "$X11_SOCKET" ] && [ $WAIT_COUNT -lt $MAX_WAIT ]; do
        sleep 1
        WAIT_COUNT=$((WAIT_COUNT + 1))
        if [ $((WAIT_COUNT % 5)) -eq 0 ]; then
            echo "  Still waiting for X11 socket... ($WAIT_COUNT/$MAX_WAIT)"
        fi
    done

    if [ -S "$X11_SOCKET" ]; then
        echo "✅ VNC server is ready (X11 socket detected)"
        echo "✅ Openbox should now be running (launched by VNC xstartup)"
    else
        echo "⚠️  VNC server may not be fully ready, but continuing anyway"
    fi

    # Eclipse MAT の GUI を起動
    echo "Starting Eclipse Memory Analyzer with software rendering..."
    echo "Environment: LIBGL_ALWAYS_SOFTWARE=$LIBGL_ALWAYS_SOFTWARE"
    DISPLAY=:1 /opt/mat/MemoryAnalyzer "$@" > /tmp/mat.log 2>&1 &
    MAT_PID=$!

    # Eclipse MATの起動を確認（プロセス確認を繰り返す）
    echo "Waiting for Eclipse MAT to initialize..."
    MAT_MAX_WAIT=20
    MAT_WAIT=0
    while [ $MAT_WAIT -lt $MAT_MAX_WAIT ]; do
        if ps -p $MAT_PID > /dev/null 2>&1; then
            # プロセスが生きている場合、もう少し待って安定するか確認
            if [ $MAT_WAIT -ge 6 ]; then
                echo "✅ Eclipse MAT started successfully (PID: $MAT_PID)"
                break
            fi
        else
            # プロセスが死んだ
            echo "⚠️  Eclipse MAT process may have failed. Check logs:"
            cat /tmp/mat.log 2>/dev/null || echo "No MAT log available"
            break
        fi
        sleep 0.5
        MAT_WAIT=$((MAT_WAIT + 1))
    done

    # コンテナを維持
    echo "✅ Eclipse MAT is running. Access at http://localhost:6901"
    echo "Press Ctrl+C to stop."
    wait
    exit 0
fi

# ここから CLI モードの処理

# 入力ファイル（ヒープダンプ）
INPUT_FILE="$1"

# ファイルが存在しない場合
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file $INPUT_FILE does not exist."
    exit 1
fi

# 入力ファイルの絶対パスを取得
INPUT_FILE=$(readlink -f "$INPUT_FILE")
INPUT_DIR=$(dirname "$INPUT_FILE")

# MAT CLI のコマンド：レポート生成
echo "Starting heap analysis with Eclipse MAT CLI..."
echo "Input: $INPUT_FILE"
echo "Output directory: $INPUT_DIR (same as input)"
echo ""

# ParseHeapDump.sh を使用してヒープダンプを解析しレポート生成
# レポートは入力ファイルと同じディレクトリに生成される
/opt/mat/ParseHeapDump.sh "$INPUT_FILE" \
    org.eclipse.mat.api:suspects \
    org.eclipse.mat.api:overview \
    org.eclipse.mat.api:top_components

# レポート生成が成功したか確認
if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Heap analysis completed successfully!"
    echo "📄 Reports generated at: $INPUT_DIR"
    echo ""
else
    echo ""
    echo "❌ Heap analysis failed."
    exit 1
fi
