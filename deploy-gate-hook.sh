#!/usr/bin/env bash
# PreToolUse(Bash) フック: vercel --prod デプロイを predeploy-check.sh で検査し、
# 未通過ならデプロイをブロックする（Claudeが品質ゲートをスキップできないようにする強制層）。
input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null)

# vercel の本番デプロイ以外は素通り（allow）
printf '%s' "$cmd" | grep -q 'vercel' || exit 0
printf '%s' "$cmd" | grep -Eq -- '--prod|deploy[[:space:]]+--prod' || exit 0

# ===== スコープ限定: senkode-web のデプロイ時のみ作動 =====
# 他プロジェクト(anthroom-lp等)のデプロイに senkode-web のルールを押し付けない。
SENKODE_WEB="/Users/admin/Documents/Senkode/senkode-web"
target=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null)
# コマンド内に絶対パスへの cd があればそれをデプロイ対象ディレクトリとみなす
abscd=$(printf '%s' "$cmd" | grep -oE 'cd[[:space:]]+/[^ &;|"'"'"']+' | tail -1 | sed -E 's/^cd[[:space:]]+//')
[ -n "$abscd" ] && target="$abscd"
case "$target" in
  "$SENKODE_WEB"|"$SENKODE_WEB"/*) ;;  # senkode-web → 検査続行
  *) exit 0 ;;                          # それ以外 → 素通り(他システムに影響なし)
esac

GATE="/Users/admin/Documents/Senkode/senkode-web/predeploy-check.sh"
[ -f "$GATE" ] || exit 0

out=$(cd /Users/admin/Documents/Senkode/senkode-web && bash predeploy-check.sh 2>&1)
code=$?
if [ "$code" -ne 0 ]; then
  reason=$(printf '%s' "$out" | grep -F '[BLOCK]' | tr '\n' ' ')
  jq -nc --arg r "本番デプロイ前の品質ゲート(predeploy-check.sh)が未通過。修正後に再デプロイせよ → $reason" \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
fi
exit 0
