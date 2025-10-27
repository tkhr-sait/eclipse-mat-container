#!/bin/bash

# 引数が渡された場合で、かつshellコマンドの場合のみ、その引数を実行してスクリプトを終了
# （例: docker run ... eclipse-mat bash -c "command"）
if [ "$(id -u)" = "0" ] && [ $# -gt 0 ] && [ "$1" != "/entrypoint.sh" ] && [ "$CLI" != "true" ]; then
    # 最初の引数がshellコマンド（bash, sh, など）の場合、matuserとして実行
    case "$1" in
        bash|sh|/bin/bash|/bin/sh)
            exec su - matuser -c "cd $(pwd) && exec $*"
            ;;
    esac
fi

# matuserとして実行するために切り替え（rootで起動された場合のみ）
if [ "$(id -u)" = "0" ] && [ -z "$_REEXEC" ]; then
    # rootの場合、matuserとして再実行（環境変数を保持）
    export _REEXEC=1
    export HOME=/home/matuser
    export CLI="$CLI"
    export PATH="$PATH"
    export JAVA_HOME="$JAVA_HOME"
    exec su matuser -c "export CLI='$CLI' && export PATH='$PATH' && export JAVA_HOME='$JAVA_HOME' && cd /home/matuser && exec $0 $*"
fi

# CLI モードのチェック（環境変数で明示的に指定された場合のみ）
if [ "$CLI" = "true" ]; then
    # CLI モード
    # ヘルプ表示
    if [ $# -eq 0 ]; then
        echo "Usage: docker run --rm -e CLI=true -v <host-dump>:/input.hprof -v <host-report-dir>:/reports eclipse-mat /input.hprof [report-type]"
        echo ""
        echo "Available modes:"
        echo "  GUI mode (default) - Web-based GUI on port 6901"
        echo "  CLI mode          - Run with -e CLI=true for automated analysis"
        echo ""
        echo "CLI mode report types:"
        echo "  leak_suspects (default) - Memory leak suspects report"
        echo "  overview                - Overview report"
        echo "  top_components          - Top components report"
        echo ""
        echo "Example (CLI): docker run --rm -e CLI=true -v \$(pwd)/heap.hprof:/input.hprof -v \$(pwd)/output:/reports eclipse-mat /input.hprof"
        echo "Example (GUI): docker run --rm -p 6901:6901 -v \$(pwd)/input:/input eclipse-mat"
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

    # kasmvnc の起動（非対話的に起動）
    export DISPLAY=:1
    # 非対話モードで起動（kasmvnc.yamlで prompt: false を設定済み）
    echo "Starting VNC server..."
    vncserver $DISPLAY -depth 24 -geometry 1920x1080 \
        -websocketPort 6901 \
        -interface 0.0.0.0 \
        -select-de manual \
        -SecurityTypes None \
        -disableBasicAuth

    VNC_EXIT_CODE=$?
    if [ $VNC_EXIT_CODE -ne 0 ]; then
        echo "VNC server failed to start. Exit code: $VNC_EXIT_CODE"
        echo "Checking VNC log..."
        cat ~/.vnc/*.log 2>/dev/null || echo "No log files found"
        exit 1
    fi

    # VNC サーバーが起動するまで待機
    echo "Waiting for VNC server to be ready..."
    sleep 5

    # Openbox の設定を作成（アプリケーションを最大化）
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

    # Openbox ウィンドウマネージャーを起動
    echo "Starting Openbox window manager..."
    DISPLAY=:1 openbox &

    # さらに待機してウィンドウマネージャーの起動を確実にする
    sleep 2

    # /input ディレクトリの内容を ~/work にコピー（書き込み権限の問題を回避）
    if [ -d /input ] && [ "$(ls -A /input 2>/dev/null)" ]; then
        echo "Copying files from /input to ~/work for analysis..."
        mkdir -p ~/work
        cp -r /input/* ~/work/ 2>/dev/null || true
        echo "Files copied to ~/work (writable directory)"
        echo ""
    fi

    # Eclipse MAT の GUI を起動
    echo "Starting Eclipse Memory Analyzer..."
    DISPLAY=:1 /opt/mat/MemoryAnalyzer "$@" &

    # コンテナを維持
    echo "✅ Eclipse MAT is running. Press Ctrl+C to stop."
    wait
    exit 0
fi

# ここから CLI モードの処理

# 入力ファイル（ヒープダンプ）
INPUT_FILE="$1"
REPORT_TYPE="${2:-leak_suspects}"
OUTPUT_DIR="/reports"

# ファイルが存在しない場合
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file $INPUT_FILE does not exist."
    exit 1
fi

# 作業ディレクトリを/tmpに作成（書き込み権限の問題を回避）
WORK_DIR="/tmp/mat_work_$$"
mkdir -p "$WORK_DIR"

# 入力ファイルを作業ディレクトリにコピー
WORK_FILE="$WORK_DIR/$(basename "$INPUT_FILE")"
echo "Copying input file to writable directory..."
cp "$INPUT_FILE" "$WORK_FILE"
echo "Working on: $WORK_FILE"
echo ""

# MAT CLI のコマンド：レポート生成
echo "Starting heap analysis with Eclipse MAT CLI..."
echo "Input: $INPUT_FILE (copied to $WORK_FILE)"
echo "Report type: $REPORT_TYPE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# ParseHeapDump.sh を使用してヒープダンプを解析しレポート生成
/opt/mat/ParseHeapDump.sh "$WORK_FILE" \
    org.eclipse.mat.api:suspects \
    org.eclipse.mat.api:overview \
    org.eclipse.mat.api:top_components

# レポート生成が成功したか確認
if [ $? -eq 0 ]; then
    # 生成されたレポートを/reportsにコピー
    DUMP_NAME=$(basename "$WORK_FILE" .hprof)

    echo ""
    echo "📦 Copying and organizing reports to $OUTPUT_DIR..."

    # 出力ディレクトリを作成（権限問題対策として親が実行する場合も）
    mkdir -p "$OUTPUT_DIR" 2>/dev/null || true

    # .zip ファイルを探してコピー
    find "$WORK_DIR" -name "${DUMP_NAME}*.zip" -type f | while read zipfile; do
        echo "  Copying $(basename "$zipfile")..."
        cp "$zipfile" "$OUTPUT_DIR/" 2>/dev/null || chmod -R 777 "$OUTPUT_DIR" && cp "$zipfile" "$OUTPUT_DIR/"

        # ZIPファイル名からレポート種類を取得（例: input_Leak_Suspects.zip -> Leak_Suspects）
        REPORT_NAME=$(basename "$zipfile" .zip | sed "s/${DUMP_NAME}_//")
        EXTRACT_DIR="$OUTPUT_DIR/$REPORT_NAME"

        echo "  Extracting to $REPORT_NAME/"
        mkdir -p "$EXTRACT_DIR" 2>/dev/null || true
        unzip -q "$zipfile" -d "$EXTRACT_DIR" 2>/dev/null || true
    done

    # その他のファイル（HTML、indexなど）もコピー
    find "$WORK_DIR" -name "${DUMP_NAME}*" -type f \( -name "*.html" -o -name "*.txt" -o -name "*.index" \) -exec cp {} "$OUTPUT_DIR/" \; 2>/dev/null || true

    echo ""
    echo "✅ Heap analysis completed successfully!"
    echo "📄 Reports generated at: $OUTPUT_DIR"
    echo ""

    # 作業ディレクトリをクリーンアップ
    rm -rf "$WORK_DIR"
else
    echo ""
    echo "❌ Heap analysis failed."
    # 作業ディレクトリをクリーンアップ
    rm -rf "$WORK_DIR"
    exit 1
fi
