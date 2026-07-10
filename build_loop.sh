#!/bin/bash
set -o pipefail
cd ~/immortalwrt-mt798x-rebase

MAX_CORES=$(nproc)
CORES=$MAX_CORES
SUCCESS_COUNT=0

while true; do
    echo "=== [$(date +%H:%M:%S)] Build with -j$CORES (success streak: $SUCCESS_COUNT) ==="

    make -j$CORES V=s 2>&1 | tee -a build.log
    RC=${PIPESTATUS[0]}  # make's exit code, not tee's

    if [ $RC -eq 0 ]; then
        echo "=== BUILD SUCCESS! ==="
        exit 0
    fi

    # --- Analyze failure ---
    LAST_ERR=$(grep -n 'make\[.*Error\|ERROR:' build.log | tail -3)

    # 1) Kernel config interactive prompt
    if grep -q 'syncconfig.*Error\|Restart config\|(NEW).*make\[.*Error' build.log; then
        echo ">>> Kernel config prompt detected, fixing..."
        KD=build_dir/target-aarch64_cortex-a53_musl/linux-mediatek_filogic/linux-6.12.94
        cd "$KD" && yes '' | make ARCH=arm64 oldconfig 2>/dev/null
        cp .config .config.prev; cd ~/immortalwrt-mt798x-rebase
        CORES=1; SUCCESS_COUNT=0
        continue
    fi

    # 2) Parallel download failure (curl 404 / TLS error)
    if grep -q 'curl.*error:' build.log && [ $CORES -gt 1 ]; then
        echo ">>> Download errors with -j$CORES, switching to -j1 for downloads..."
        CORES=1; SUCCESS_COUNT=0
        continue
    fi

    # 3) Random race condition with multi-core
    if [ $CORES -gt 1 ]; then
        echo ">>> Failed with -j$CORES, falling back to -j1..."
        CORES=1; SUCCESS_COUNT=0
        continue
    fi

    # 4) Single-core failed — real error, report and exit
    echo ">>> Single-core build failed with real error:"
    echo "$LAST_ERR"
    echo ">>> Check build.log for details. Exiting."
    exit $RC
done
