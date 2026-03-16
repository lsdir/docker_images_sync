#!/bin/bash
set -eux


# 检查参数数量是否正确
if [ "$#" -ne 3 ]; then
    echo "错误：脚本需要3个参数 images_file、docker_registry和docker_namespace"
    echo "用法: $0 <images_file> <docker_registry> <docker_namespace>"
    exit 1
fi


IMAGES_FILE=$1
TARGET_REGISTRY=$2
TARGET_NAMESPACE=$3

# 检查文件是否存在
if [ ! -f "$IMAGES_FILE" ]; then
    echo "错误：文件 $IMAGES_FILE 不存在"
    exit 1
fi

failed_count=0
failed_images=""

resolve_target_name() {
    local image="$1"
    local image_without_digest="${image%%@*}"
    local last_part="${image_without_digest##*/}"
    printf "%s/%s/%s" "$TARGET_REGISTRY" "$TARGET_NAMESPACE" "$last_part"
}

while IFS= read -r image; do
    [ -z "$image" ] && continue

    targetFullName=$(resolve_target_name "$image")

    # 直接复制 manifest list，保留全部架构而不是仅同步 runner 当前架构
    set +e
    docker buildx imagetools create --tag "$targetFullName" "$image"
    sync_status=$?
    set -e
    if [ $sync_status -ne 0 ]; then
        echo "Error: Failed to sync image $image to $targetFullName, continuing..."
        failed_count=$((failed_count + 1))
        failed_images="${failed_images} ${image}"
        continue
    fi
done < "$IMAGES_FILE"

if [ $failed_count -gt 0 ]; then
    echo "Error: Failed to sync $failed_count images: $failed_images"
    exit 1
fi
echo "Successfully synced all images."
