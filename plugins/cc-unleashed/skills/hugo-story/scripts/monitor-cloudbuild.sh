#!/bin/bash
# Monitor Cloud Build for rlg-hugo deployment
# Usage: ./monitor-cloudbuild.sh [optional-build-id]

set -e

PROJECT_ID="${GCP_PROJECT:-rlg-gcp-sandbox}"
REPO_NAME="rlg-hugo"
POLL_INTERVAL=30
MAX_WAIT=600  # 10 minutes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get build ID - either from argument or find latest
if [ -n "$1" ]; then
    BUILD_ID="$1"
    log_info "Monitoring specified build: $BUILD_ID"
else
    log_info "Finding latest build for $REPO_NAME..."

    # Wait a moment for trigger to fire
    sleep 5

    BUILD_ID=$(gcloud builds list \
        --project="$PROJECT_ID" \
        --filter="source.repoSource.repoName='$REPO_NAME'" \
        --limit=1 \
        --format="value(id)" 2>/dev/null)

    if [ -z "$BUILD_ID" ]; then
        log_error "No builds found for $REPO_NAME"
        exit 1
    fi

    log_info "Found build: $BUILD_ID"
fi

# Monitor build
ELAPSED=0
while true; do
    # Get build status
    BUILD_INFO=$(gcloud builds describe "$BUILD_ID" \
        --project="$PROJECT_ID" \
        --format="value(status,startTime,finishTime)" 2>/dev/null)

    STATUS=$(echo "$BUILD_INFO" | cut -f1)
    START_TIME=$(echo "$BUILD_INFO" | cut -f2)
    FINISH_TIME=$(echo "$BUILD_INFO" | cut -f3)

    case $STATUS in
        SUCCESS)
            echo ""
            log_info "Build completed successfully!"
            log_info "Build ID: $BUILD_ID"
            log_info "Started: $START_TIME"
            log_info "Finished: $FINISH_TIME"
            echo ""
            echo "View build: https://console.cloud.google.com/cloud-build/builds/$BUILD_ID?project=$PROJECT_ID"
            exit 0
            ;;
        FAILURE)
            echo ""
            log_error "Build FAILED!"
            log_error "Build ID: $BUILD_ID"
            echo ""
            echo "Build logs:"
            echo "----------------------------------------"
            gcloud builds log "$BUILD_ID" --project="$PROJECT_ID" 2>/dev/null | tail -50
            echo "----------------------------------------"
            echo ""
            echo "Full logs: https://console.cloud.google.com/cloud-build/builds/$BUILD_ID?project=$PROJECT_ID"
            exit 1
            ;;
        TIMEOUT)
            echo ""
            log_error "Build TIMED OUT!"
            exit 1
            ;;
        CANCELLED)
            echo ""
            log_warn "Build was CANCELLED"
            exit 1
            ;;
        QUEUED|PENDING|WORKING)
            printf "\r[%ds] Build status: %-10s" "$ELAPSED" "$STATUS"
            ;;
        *)
            log_warn "Unknown status: $STATUS"
            ;;
    esac

    # Check if we've waited too long
    if [ "$ELAPSED" -ge "$MAX_WAIT" ]; then
        echo ""
        log_error "Timeout waiting for build after ${MAX_WAIT}s"
        log_info "Build may still be running. Check console:"
        echo "https://console.cloud.google.com/cloud-build/builds/$BUILD_ID?project=$PROJECT_ID"
        exit 1
    fi

    sleep "$POLL_INTERVAL"
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done
