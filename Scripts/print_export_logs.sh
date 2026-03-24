#!/usr/bin/env bash

echo "--- Searching for Xcode Export Logs ---"

LOG_FILES=$(find /Volumes/workspace/tmp /Users/runner/work -name "IDEDistribution.standard.log" -o -name "DistributionSummary.plist" 2>/dev/null)

if [ -z "$LOG_FILES" ]; then
    echo "No export logs found in the standard CI directories."
    exit 0
fi

for log in $LOG_FILES; do
    echo "========================================"
    echo "Contents of: $log"
    echo "========================================"
    cat "$log"
    echo ""
done
