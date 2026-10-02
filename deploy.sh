#!/usr/bin/env bash
# deploy.sh — 2026-09-02 농진청 AgenticAI 특강 자료를 GitHub + Pages 에 올린다.
#
# 사용법:  bash deploy.sh <OWNER>          예) bash deploy.sh guebin   /  bash deploy.sh miruetoto
#
# 하는 일 (작년 guebin/rda251022 와 같은 구조: main 브랜치, Pages 는 /docs):
#   1. 사전 점검 (gh 로그인 계정 = OWNER 인지, .git 이 아직 없는지, 100MB 넘는 파일이 없는지, docs/ 가 있는지)
#   2. git init -b main → git add -A → git commit
#   3. gh repo create OWNER/rda261002 --public --source . --push
#   4. Pages 켜기: main 브랜치 /docs
#   5. 주소 출력
#
# ★ commit·push 는 대표 지시가 있어야 한다. 이 스크립트는 초안이며, 실행 여부는 사람이 정한다.
# ★ 작년처럼 fonts/(61MB)·figs/(28MB)·Downloads.zip(35MB) 도 그대로 올린다. 개별 파일 100MB 한도 안이다.
#   (.gitignore 가 .quarto/, *.mov, movs/, docs/movs/, .DS_Store 를 뺀다)

set -euo pipefail

OWNER="${1:-}"
REPO="rda261002"
BRANCH="main"
PAGES_PATH="/docs"
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

die() { echo "✗ $*" >&2; exit 1; }
ok()  { echo "✓ $*"; }

[ -n "$OWNER" ] || die "OWNER 를 인자로 주세요.  예) bash deploy.sh guebin"
cd "$DIR"

# ---------- 1. 사전 점검 ----------
command -v gh  >/dev/null || die "gh 가 없다"
command -v git >/dev/null || die "git 이 없다"

ACTIVE="$(gh api user --jq .login 2>/dev/null || true)"
[ -n "$ACTIVE" ] || die "gh 로그인이 안 되어 있다.  gh auth login"
if [ "$ACTIVE" != "$OWNER" ]; then
  # OWNER 가 조직이고 ACTIVE 가 멤버면 통과, 아니면 계정 전환이 필요하다
  if gh api "orgs/$OWNER/memberships/$ACTIVE" --jq .state 2>/dev/null | grep -q active; then
    ok "gh 계정 $ACTIVE 는 조직 $OWNER 의 멤버"
  else
    die "gh 활성 계정은 '$ACTIVE' 인데 OWNER 는 '$OWNER' 다.  먼저  gh auth switch --user $OWNER  (없으면 gh auth login)"
  fi
fi
ok "gh 계정: $ACTIVE  →  대상: $OWNER/$REPO"

if gh repo view "$OWNER/$REPO" >/dev/null 2>&1; then
  die "$OWNER/$REPO 가 이미 있다. 덮어쓰지 않는다 — 지우거나 이름을 바꾼 뒤 다시."
fi
ok "$OWNER/$REPO 없음 (새로 만든다)"

[ ! -e .git ] || die ".git 이 이미 있다. 초안 스크립트는 새 저장소만 다룬다 — 상황을 확인한 뒤 수동으로."
[ -f .gitignore ] || die ".gitignore 가 없다"
[ -d docs ] && [ -f docs/agentic.html ] && [ -f docs/hands-on.html ] || die "docs/ 가 덜 됐다 (agentic.html·hands-on.html 필요)"
[ -f docs/index.html ] || echo "! docs/index.html 이 없다 — Pages 루트가 404 가 된다 (agentic.html 은 열린다)"
ok "docs/ 확인"

# 100MB 넘는 파일 (GitHub 개별 파일 한도)
BIG="$(find . -type f -size +100M -not -path './.git/*' -not -path './.quarto/*' -not -path './movs/*' -not -path './docs/movs/*' -not -name '*.mov' || true)"
[ -z "$BIG" ] || die "100MB 넘는 파일이 있다:
$BIG"
ok "100MB 넘는 파일 없음"

# 올라갈 것 미리 보기
echo "----- 올라갈 항목 (상위 폴더별) -----"
du -sh fonts figs docs Downloads.zip hands-on.ipynb agentic.qmd 2>/dev/null || true
echo "------------------------------------"

# ---------- 2. git init / add / commit ----------
git init -q -b "$BRANCH"
git add -A
git status --short | head -20
echo "..."
git commit -q -m "농진청 신규연구사 특강(2026-10-02) 자료: 슬라이드·실습 노트북·Pages(docs/)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
ok "commit: $(git rev-parse --short HEAD)"

# ---------- 3. 저장소 만들고 push ----------
gh repo create "$OWNER/$REPO" --public --source . --push
ok "push 완료: https://github.com/$OWNER/$REPO"

# ---------- 4. Pages (main, /docs) ----------
gh api -X POST "repos/$OWNER/$REPO/pages" \
  -f "source[branch]=$BRANCH" -f "source[path]=$PAGES_PATH" >/dev/null
ok "Pages 켬: $BRANCH $PAGES_PATH"

# ---------- 5. 주소 ----------
URL="$(gh api "repos/$OWNER/$REPO/pages" --jq .html_url)"
echo
echo "==================================================="
echo " 저장소:  https://github.com/$OWNER/$REPO"
echo " Pages:   ${URL}            (첫 빌드 1~2분)"
echo " 슬라이드: ${URL}agentic.html"
echo " 실습:    ${URL}hands-on.html"
echo "==================================================="
