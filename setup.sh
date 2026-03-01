#!/usr/bin/env bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Prompts ---

echo ""
echo "=== Apermo Project Setup ==="
echo ""

# Project type
PS3="Select project type: "
select PROJECT_TYPE in "php" "generic"; do
    [ -n "$PROJECT_TYPE" ] && break
done
echo ""

# Repo name (auto-detect from git remote)
DETECTED_NAME=""
if git remote get-url origin &>/dev/null; then
    DETECTED_NAME=$(git remote get-url origin | sed -E 's|.*[:/]([^/]+)/([^/.]+)(\.git)?$|\2|')
fi

read -rp "Repository name [${DETECTED_NAME}]: " REPO_NAME
REPO_NAME="${REPO_NAME:-$DETECTED_NAME}"
[ -z "$REPO_NAME" ] && error "Repository name is required."

# Description
read -rp "Description: " DESCRIPTION
[ -z "$DESCRIPTION" ] && error "Description is required."

# PHP-specific prompts
if [ "$PROJECT_TYPE" = "php" ]; then
    DEFAULT_COMPOSER="apermo/${REPO_NAME}"
    read -rp "Composer package name [${DEFAULT_COMPOSER}]: " COMPOSER_NAME
    COMPOSER_NAME="${COMPOSER_NAME:-$DEFAULT_COMPOSER}"

    read -rp "PHP namespace (e.g. Apermo\\MyPackage): " NAMESPACE
    [ -z "$NAMESPACE" ] && error "Namespace is required."

    read -rp "Minimum PHP version [8.1]: " PHP_MIN
    PHP_MIN="${PHP_MIN:-8.1}"
fi

# --- Replace placeholders ---

info "Replacing placeholders..."

replace_in_files() {
    local placeholder="$1"
    local value="$2"

    find . -type f \
        -not -path './.git/*' \
        -not -path './setup.sh' \
        -not -name '*.dist' \
        -exec sed -i '' "s|${placeholder}|${value}|g" {} +

    find . -name '*.dist' -type f \
        -not -path './.git/*' \
        -exec sed -i '' "s|${placeholder}|${value}|g" {} +
}

replace_in_files "__REPO_NAME__" "$REPO_NAME"
replace_in_files "__DESCRIPTION__" "$DESCRIPTION"

if [ "$PROJECT_TYPE" = "php" ]; then
    # Escape backslashes for JSON (composer.json)
    NAMESPACE_JSON=$(echo "$NAMESPACE" | sed 's/\\/\\\\/g')
    NAMESPACE_ESCAPED=$(echo "$NAMESPACE" | sed 's/\\/\\\\/g')

    replace_in_files "__COMPOSER_NAME__" "$COMPOSER_NAME"
    replace_in_files "__PHP_MIN_VERSION__" "$PHP_MIN"

    # Handle namespace replacement carefully
    find . -type f -name '*.dist' \
        -not -path './.git/*' \
        -exec sed -i '' "s|__NAMESPACE__|${NAMESPACE_ESCAPED}|g" {} +

    find . -type f \
        -not -path './.git/*' \
        -not -path './setup.sh' \
        -not -name '*.dist' \
        -exec sed -i '' "s|__NAMESPACE__|${NAMESPACE_ESCAPED}|g" {} +
fi

# --- Rename .dist files ---

info "Renaming .dist files..."

# README.md.dist and CLAUDE.md.dist always get renamed
mv README.md.dist README.md
mv CLAUDE.md.dist CLAUDE.md

if [ "$PROJECT_TYPE" = "php" ]; then
    # Rename PHP .dist files (except phpunit.xml.dist and phpcs.xml.dist which keep .dist)
    mv composer.json.dist composer.json
    mv phpstan.neon.dist phpstan.neon
    mv ".github/workflows/ci-php.yml.dist" ".github/workflows/ci-php.yml"
else
    # Remove all PHP-only files for generic projects
    info "Removing PHP-only files..."
    rm -f composer.json.dist phpstan.neon.dist phpunit.xml.dist phpcs.xml.dist
    rm -f ".github/workflows/ci-php.yml.dist"
    rm -rf .githooks
    rm -f tests/bootstrap.php
    rm -f src/.gitkeep tests/.gitkeep
    rmdir src tests 2>/dev/null || true
fi

# --- Configure repository via gh CLI ---

if command -v gh &>/dev/null; then
    OWNER_REPO="apermo/${REPO_NAME}"

    info "Configuring repository settings..."
    gh repo edit "$OWNER_REPO" \
        --delete-branch-on-merge \
        --enable-wiki=false \
        --enable-projects=false 2>/dev/null || warn "Could not update repo settings."

    info "Removing default labels..."
    for label in $(gh label list --repo "$OWNER_REPO" --json name -q '.[].name' 2>/dev/null); do
        gh label delete "$label" --repo "$OWNER_REPO" --yes 2>/dev/null || true
    done

    info "Creating standard labels..."
    gh label create "type: bug"        --color "D73A4A" --description "Something isn't working" --repo "$OWNER_REPO" 2>/dev/null || true
    gh label create "type: feature"    --color "0E8A16" --description "New functionality" --repo "$OWNER_REPO" 2>/dev/null || true
    gh label create "type: docs"       --color "0075CA" --description "Documentation" --repo "$OWNER_REPO" 2>/dev/null || true
    gh label create "type: chore"      --color "BFD4F2" --description "Maintenance and cleanup" --repo "$OWNER_REPO" 2>/dev/null || true
    gh label create "priority: high"   --color "B60205" --description "Must have" --repo "$OWNER_REPO" 2>/dev/null || true
    gh label create "priority: medium" --color "FBCA04" --description "Should have" --repo "$OWNER_REPO" 2>/dev/null || true
    gh label create "priority: low"    --color "C5DEF5" --description "Nice to have" --repo "$OWNER_REPO" 2>/dev/null || true
    gh label create "dependencies"     --color "0366D6" --description "Dependency updates" --repo "$OWNER_REPO" 2>/dev/null || true

    info "Creating branch ruleset..."
    REQUIRED_CHECKS='[{"context":"Check CHANGELOG Entry"},{"context":"Check Commit Message Format"}]'

    if [ "$PROJECT_TYPE" = "php" ]; then
        REQUIRED_CHECKS='[{"context":"Check CHANGELOG Entry"},{"context":"Check Commit Message Format"},{"context":"PHPStan"},{"context":"Coding Standards"}]'
    fi

    gh api "repos/${OWNER_REPO}/rulesets" --method POST --input - <<RULESET_EOF || warn "Could not create ruleset."
{
    "name": "Protect main",
    "target": "branch",
    "enforcement": "active",
    "bypass_actors": [
        {
            "actor_id": 5,
            "actor_type": "RepositoryRole",
            "bypass_mode": "always"
        }
    ],
    "conditions": {
        "ref_name": {
            "include": ["refs/heads/main"],
            "exclude": []
        }
    },
    "rules": [
        {"type": "deletion"},
        {"type": "non_fast_forward"},
        {
            "type": "pull_request",
            "parameters": {
                "required_approving_review_count": 0,
                "dismiss_stale_reviews_on_push": false,
                "require_code_owner_review": false,
                "require_last_push_approval": false,
                "required_review_thread_resolution": false
            }
        },
        {
            "type": "required_status_checks",
            "parameters": {
                "strict_required_status_checks_policy": false,
                "required_status_checks": ${REQUIRED_CHECKS}
            }
        }
    ]
}
RULESET_EOF
else
    warn "gh CLI not found — skipping repository configuration."
fi

# --- Verify no placeholders remain ---

info "Verifying no placeholders remain..."
REMAINING=$(grep -r '__[A-Z_]*__' . --include='*.md' --include='*.yml' --include='*.json' --include='*.xml' --include='*.neon' --include='*.php' -l 2>/dev/null | grep -v '.git/' | grep -v 'setup.sh' || true)

if [ -n "$REMAINING" ]; then
    warn "Placeholders found in: $REMAINING"
else
    info "No remaining placeholders found."
fi

# --- Clean up ---

info "Removing setup script..."
rm -- "$0"

# --- Stage and commit ---

info "Creating initial commit..."
git add -A
git commit -m "feat: initial project setup"

echo ""
info "Setup complete! Your project '${REPO_NAME}' is ready."
echo ""
