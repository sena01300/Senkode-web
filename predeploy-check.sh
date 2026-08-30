#!/usr/bin/env bash
# ============================================================
# Senkode 品質保証ゲート（デプロイ前 必須実行）
# 目的: 過去に繰り返した「同じミス」を機械的に検出してデプロイを止める。
# 使い方: cd senkode-web && bash predeploy-check.sh
#   BLOCK=本社コアページの致命的違反 → 1件でもあれば exit 1（デプロイ禁止）
#   WARN =参考。portfolio等のクライアント別ブランド色は対象外
# ============================================================
set -u
cd "$(dirname "$0")" || exit 2
fail=0
ng()   { fail=$((fail+1)); printf '  [BLOCK] %s\n' "$*"; }
warn() { printf '  [warn]  %s\n' "$*"; }

# 本社コアページ（ブランド厳守対象）
CORE="index.html about.html services.html works.html contact.html organization.html articles/index.html"
# 改行バグだけは全HTML対象（クライアントLPでも句読点孤立はNG）
ALL=$(find . -name '*.html' -not -path './node_modules/*')

echo "=== Senkode 品質保証ゲート ==="

# 1) [BLOCK] 改行バグの元凶: keep-all / break-word は全ページ禁止
hit=$(grep -rl 'word-break: *keep-all\|word-break: *break-word' $ALL 2>/dev/null)
if [ -n "$hit" ]; then
  ng "word-break: keep-all/break-word を検出（句読点・1文字が孤立する原因。auto-phrase+normalへ）:"
  echo "$hit" | sed 's/^/          /'
fi

# 2) [BLOCK] 日本語改行レシピ(auto-phrase/line-break)がコアページに入っているか
for f in $CORE; do
  [ -f "$f" ] || continue
  grep -q 'auto-phrase' "$f" || ng "$f: word-break: auto-phrase が無い（日本語改行レシピ未適用）"
done

# 3) [BLOCK] コアページに html overflow-x:hidden があるか
for f in $CORE; do
  [ -f "$f" ] || continue
  grep -q 'overflow-x: *hidden' "$f" || ng "$f: overflow-x:hidden が見当たらない（横スクロール防止）"
done

# 4) [warn] コアページの本文<br>連発
for f in $CORE; do
  [ -f "$f" ] || continue
  n=$(grep -o '<br' "$f" 2>/dev/null | wc -l | tr -d ' ')
  [ "$n" -gt 12 ] && warn "$f: <br> が ${n}個（本文の改行はCSSに任せる）"
done

# 5) [warn] コアページの直書きカラー（portfolioはクライアント色なので対象外）
for f in $CORE; do
  [ -f "$f" ] || continue
  bad=$(grep -nE '#[0-9A-Fa-f]{6}' "$f" | grep -vE 'stop-color|:root|--[a-z]|linearGradient|flood-color|id="|#06C755' | head -2)
  [ -n "$bad" ] && { warn "$f: 直書きカラーの可能性（CSS変数推奨）"; echo "$bad" | sed 's/^/          /'; }
done

echo "--------------------------------"
if [ "$fail" -eq 0 ]; then
  echo "PASS: 自動チェック合格。次は Playwright(docSW≤vw) と iOS実機の改行目視を実施。"
  exit 0
else
  echo "FAIL: ${fail}件の致命的違反。修正するまでデプロイ禁止。"
  exit 1
fi
