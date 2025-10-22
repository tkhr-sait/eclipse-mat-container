#!/bin/bash

# ヘルプ表示
if [ $# -eq 0 ]; then
    echo "Usage: docker run --rm -v <host-dump>:/input.hprof -v <host-report-dir>:/reports eclipse-mat /input.hprof [report-type]"
    echo ""
    echo "Available report types:"
    echo "  leak_suspects (default) - Memory leak suspects report"
    echo "  overview                - Overview report"
    echo "  top_components          - Top components report"
    echo ""
    echo "Example: docker run --rm -v \$(pwd)/heap.hprof:/input.hprof -v \$(pwd)/output:/reports eclipse-mat /input.hprof leak_suspects"
    exit 1
fi

# 入力ファイル（ヒープダンプ）
INPUT_FILE="$1"
REPORT_TYPE="${2:-leak_suspects}"
OUTPUT_DIR="/reports"

# ファイルが存在しない場合
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file $INPUT_FILE does not exist."
    exit 1
fi

# 出力ディレクトリが存在しない場合は作成
mkdir -p "$OUTPUT_DIR"

# MAT CLI のコマンド：レポート生成
echo "Starting heap analysis with Eclipse MAT CLI..."
echo "Input: $INPUT_FILE"
echo "Report type: $REPORT_TYPE"
echo "Output directory: $OUTPUT_DIR"
echo ""

# ParseHeapDump.sh を使用してヒープダンプを解析しレポート生成
/opt/mat/ParseHeapDump.sh "$INPUT_FILE" \
    org.eclipse.mat.api:suspects \
    org.eclipse.mat.api:overview \
    org.eclipse.mat.api:top_components

# レポート生成が成功したか確認
if [ $? -eq 0 ]; then
    # 生成されたレポートを /reports にコピー
    DUMP_DIR=$(dirname "$INPUT_FILE")
    DUMP_NAME=$(basename "$INPUT_FILE" .hprof)

    echo ""
    echo "📦 Extracting and organizing reports..."

    # .zip ファイルを探して解凍
    find "$DUMP_DIR" -name "${DUMP_NAME}*.zip" -type f | while read zipfile; do
        # ZIPファイル名からレポート種類を取得（例: input_Leak_Suspects.zip -> Leak_Suspects）
        REPORT_NAME=$(basename "$zipfile" .zip | sed "s/${DUMP_NAME}_//")
        EXTRACT_DIR="$OUTPUT_DIR/$REPORT_NAME"

        echo "  Extracting $(basename "$zipfile") to $REPORT_NAME/"
        mkdir -p "$EXTRACT_DIR"
        unzip -q "$zipfile" -d "$EXTRACT_DIR"

        # 元のZIPファイルも保存（オプション）
        cp "$zipfile" "$OUTPUT_DIR/"
    done

    # その他のファイル（HTML、TXTなど）もコピー
    find "$DUMP_DIR" -name "${DUMP_NAME}*" -type f \( -name "*.html" -o -name "*.txt" \) -exec cp {} "$OUTPUT_DIR/" \; 2>/dev/null || true

    echo ""
    echo "✅ Heap analysis completed successfully!"
    echo "📄 Reports generated at: $OUTPUT_DIR"
    echo ""
    echo "Generated reports:"
    ls -lh "$OUTPUT_DIR"
    echo ""
    echo "Extracted report directories:"
    ls -d "$OUTPUT_DIR"/*/ 2>/dev/null || echo "  (none)"
else
    echo ""
    echo "❌ Heap analysis failed."
    exit 1
fi
