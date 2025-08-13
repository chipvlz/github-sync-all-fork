#!/bin/bash

# Lấy tên người dùng GitHub của bạn
GITHUB_USERNAME=$(gh api user -q .login)

# Lấy danh sách tất cả các repo đã fork của bạn
# -q .name: chỉ lấy tên repo
FORKED_REPOS=$(gh repo list "$GITHUB_USERNAME" --fork --json name -q ".[].name")

# Lặp qua từng repo và đồng bộ
for REPO_NAME in $FORKED_REPOS; do
    echo "--- Bắt đầu đồng bộ repo: $REPO_NAME ---"
    
    # Clone repo xuống máy nếu chưa có
    if [ ! -d "$REPO_NAME" ]; then
        echo "Cloning $REPO_NAME..."
        gh repo clone "$GITHUB_USERNAME/$REPO_NAME"
    fi
    
    # Chuyển vào thư mục của repo
    cd "$REPO_NAME" || { echo "Không thể vào thư mục $REPO_NAME. Bỏ qua..."; continue; }
    
    # Kiểm tra xem đã có remote upstream (repo gốc) chưa
    if ! git remote -v | grep -q 'upstream'; then
        # Lấy thông tin repo gốc từ GitHub CLI
        UPSTREAM_REPO=$(gh repo view "$GITHUB_USERNAME/$REPO_NAME" --json parent -q ".parent.url")
        
        # Nếu tìm thấy, thêm remote upstream
        if [ -n "$UPSTREAM_REPO" ]; then
            echo "Thêm remote 'upstream' tới $UPSTREAM_REPO"
            git remote add upstream "$UPSTREAM_REPO"
        else
            echo "Không tìm thấy repo gốc (parent) cho $REPO_NAME. Bỏ qua..."
            cd ..
            continue
        fi
    fi
    
    # Lấy các thay đổi mới nhất từ repo gốc
    echo "Fetching từ 'upstream'..."
    git fetch upstream
    
    # Đồng bộ nhánh chính (có thể là main hoặc master)
    # Lấy tên nhánh mặc định
    DEFAULT_BRANCH=$(git remote show origin | grep "HEAD branch" | cut -d' ' -f5)
    
    if [ -n "$DEFAULT_BRANCH" ]; then
        echo "Đồng bộ nhánh '$DEFAULT_BRANCH'..."
        git checkout "$DEFAULT_BRANCH"
        git merge upstream/"$DEFAULT_BRANCH"
        
        # Đẩy thay đổi đã merge lên GitHub
        echo "Push các thay đổi đã merge lên 'origin'..."
        git push origin "$DEFAULT_BRANCH"
    else
        echo "Không tìm thấy nhánh mặc định cho $REPO_NAME. Bỏ qua..."
    fi
    
    # Quay lại thư mục gốc để lặp tiếp
    cd ..
    
    echo "--- Đồng bộ repo $REPO_NAME đã hoàn thành ---"
    echo ""
done

echo "Tất cả các repo đã được đồng bộ xong!"

