#!/usr/bin/env bash
#
# Extracted from a production codebase's statusline — this is nearly 100%
# generic Claude Code session telemetry (project/branch/worktree, model,
# effort, context %, cost, lines changed, 5h burn-rate, PR link, terminal
# auth identity), with responsive multi-line wrapping and a 256-color heat
# palette. Drop it in at `.claude/statusline.sh` and wire it via
# `settings.json` → `statusLine.command`.
#
# Three segments are OPTIONAL and companion-file-dependent, marked "OPTIONAL"
# at their definition below. All three are already defensively guarded
# (`[ -f ... ]` / existence checks) — they silently no-op if the companion
# file/lib doesn't exist, so leaving them in is safe even if you don't build
# the mechanism they read: an active external-tool call marker + its
# cumulative token counter (a hook-writable JSON marker around calls to some
# cross-vendor review tool), and a parallel-instances/peers counter (a small
# multi-instance coordination lib, not included here).
#
# One more block is a side-effect, not a display segment, and is NOT a no-op:
# it unconditionally creates `tmp/` and writes `tmp/.claude-burnrate.json` on
# every render (see "OPTIONAL side-effect" below) — harmless, but delete that
# block if nothing in your own config consumes the file.
#
# Statusline Claude Code — aesthetic geek edition.
# Format: project · ⎇ branch · ◈ model [· ⚙ effort] · █████▌░░░░ NN% ctx · ⏱ Xm · $X.XX · +A/-R · ⧖ 5h █▌░░░░░░░░ NN% ↻Xh · [style]
# Responsive: segments wrap onto several lines if the terminal width is not enough.
# Bars: 10 levels over 5 cells (full-block █ + half-block ▌) + 256-color heat palette.
# "heat" colors: bright green <30, green 30-49, yellow 50-69, orange 70-84, red ≥85.
# Model icon: ◈ Opus / ♪ Sonnet / ✎ Haiku / ❯ other.
# Effort colors: low=green, medium=yellow, high=magenta, xhigh=red, max=red+bold.

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspace.current_dir // "."')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // .cwd // "."')
project=$(basename "$project_dir")
branch=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "-")

# Effort level: prefer live value from input JSON, fallback to settings files.
# Claude Code 2.1.133+ canonicalizes on `effort.level` (nested object); the old
# paths (effort_level / effortLevel / effort as a string) stay supported.
effort=$(echo "$input" | jq -r '
  (.effort.level // .effort_level // .effortLevel // .effort // empty) as $e
  | if   ($e | type) == "object" then ($e.level // $e.name // empty)
    elif ($e | type) == "string" then $e
    else empty end
' 2>/dev/null)
if [ -z "$effort" ]; then
  for f in "$project_dir/.claude/settings.local.json" "$project_dir/.claude/settings.json" "$HOME/.claude/settings.json"; do
    if [ -f "$f" ]; then
      effort=$(jq -r '
        (.effortLevel // .effort_level // empty) as $e
        | if   ($e | type) == "object" then ($e.level // $e.name // empty)
          elif ($e | type) == "string" then $e
          else empty end
      ' "$f" 2>/dev/null)
      [ -n "$effort" ] && break
    fi
  done
fi
[ -z "$effort" ] && effort="default"

# Worktree detection: prefer workspace.git_worktree from Claude Code 2.1.97+,
# fallback to git rev-parse for older CLI versions.
wt_name=""
wt_native=$(echo "$input" | jq -r '.workspace.git_worktree // empty')
if [ -n "$wt_native" ]; then
  wt_name=$(basename "$wt_native")
  # project segment should point at the main repo name, not the worktree dir
  project_main=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null || echo "")
  if [ -n "$project_main" ]; then
    main_abs=$(cd "$cwd" 2>/dev/null && cd "$project_main" 2>/dev/null && pwd || echo "$project_main")
    project=$(basename "$(dirname "$main_abs")")
  fi
else
  git_dir=$(git -C "$cwd" rev-parse --git-dir 2>/dev/null || echo "")
  git_common=$(git -C "$cwd" rev-parse --git-common-dir 2>/dev/null || echo "")
  if [ -n "$git_dir" ] && [ -n "$git_common" ]; then
    git_dir_abs=$(cd "$cwd" 2>/dev/null && cd "$git_dir" 2>/dev/null && pwd || echo "$git_dir")
    git_common_abs=$(cd "$cwd" 2>/dev/null && cd "$git_common" 2>/dev/null && pwd || echo "$git_common")
    if [ "$git_dir_abs" != "$git_common_abs" ]; then
      wt_name=$(basename "$cwd")
      project=$(basename "$(dirname "$git_common_abs")")
    fi
  fi
fi
if ab=$(git -C "$cwd" rev-list --left-right --count '@{u}...HEAD' 2>/dev/null); then
  behind=$(echo "$ab" | cut -f1)
  ahead=$(echo "$ab" | cut -f2)
  upstream=1
else
  behind=0; ahead=0; upstream=0
fi
now=$(date +%s)

# Terminal width for responsive rendering.
# Priority: JSON input → COLUMNS env → ancestor-tty (stty) → /dev/tty (stty) →
# tput → fallback. Claude Code exposes COLUMNS/LINES to status line commands
# since 2.1.153 (not in the JSON input — confirmed against
# docs.claude.com/statusline), so $COLUMNS is the cheap, reliable path on a
# current CLI and is tried first. The ancestor-tty walk remains as a fallback
# for older CLIs / unusual launchers: the statusline subprocess has no
# controlling tty, so /dev/tty fails with "Device not configured" and
# `tput cols` returns the TERM-default of 80 — both silently wrong on wide
# terminals. The walk climbs the parent process chain until it finds an ancestor
# (typically `claude` itself) that owns a real tty, then reads `stty size`.
# "0", non-numeric, and empty are all treated as "unset".
valid_width() { case "$1" in ''|*[!0-9]*|0) return 1 ;; *) return 0 ;; esac; }

# Walk up to 6 ancestors looking for one with a real tty (not "??"). Returns
# the column count on stdout, empty on failure. Bounded depth avoids runaway
# loops if the process tree is unexpectedly long.
ancestor_tty_width() {
  local pid=$$ ppid ptty size
  local i=0
  while [ $i -lt 6 ]; do
    ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
    [ -z "$ppid" ] || [ "$ppid" = "0" ] && return 1
    ptty=$(ps -o tty= -p "$ppid" 2>/dev/null | tr -d ' ')
    if [ -n "$ptty" ] && [ "$ptty" != "?" ] && [ "$ptty" != "??" ] && [ -r "/dev/$ptty" ]; then
      size=$(stty size <"/dev/$ptty" 2>/dev/null)
      if [ -n "$size" ]; then
        printf '%s' "$size" | awk '{print $2}'
        return 0
      fi
    fi
    pid=$ppid
    i=$((i + 1))
  done
  return 1
}

width=$(echo "$input" | jq -r '.terminal.width // .terminal.cols // .display.width // .shell.columns // .width // empty' 2>/dev/null)
valid_width "$width" || width="${COLUMNS:-}"
valid_width "$width" || width=$(ancestor_tty_width 2>/dev/null || echo "")
if ! valid_width "$width" && [ -r /dev/tty ]; then
  # Brace group swallows bash's own redirection errors ("Device not configured"
  # in sandboxed/non-tty contexts), not just stty's stderr.
  width=$({ stty size </dev/tty 2>/dev/null | awk '{print $2}'; } 2>/dev/null)
fi
valid_width "$width" || width=$(tput cols 2>/dev/null || echo "")
valid_width "$width" || width=120

# PR lookup: cached + background refresh so rendering NEVER blocks on the
# network. The statusline is re-run on a ~300ms debounce and Claude Code cancels
# any in-flight execution when a newer update arrives; a synchronous `gh pr view`
# (~0.5s warm, up to ~1.9s cold) gets killed mid-flight before it can emit
# output, leaving the line blank (no fallback to the previous value). We read the
# last known value instantly from a per-branch cache and refresh it in a detached
# job. TTL 60s; stale lock self-heals after 30s.
pr_url=""; pr_num=""
if [ -n "$branch" ] && [ "$branch" != "-" ] && command -v gh >/dev/null 2>&1; then
  pr_cache_dir="${TMPDIR:-/tmp}/claude-pr-cache"
  branch_key=$(printf '%s' "$branch" | tr -c 'A-Za-z0-9._-' '_')
  pr_cache_file="$pr_cache_dir/$branch_key"
  mkdir -p "$pr_cache_dir" 2>/dev/null || true
  # Instant render from whatever we have, even if stale.
  [ -f "$pr_cache_file" ] && pr_url=$(cat "$pr_cache_file" 2>/dev/null)
  cache_age=99999
  if [ -f "$pr_cache_file" ]; then
    mtime=$(stat -f %m "$pr_cache_file" 2>/dev/null || stat -c %Y "$pr_cache_file" 2>/dev/null || echo 0)
    cache_age=$(( now - mtime ))
  fi
  if [ "$cache_age" -gt 60 ]; then
    pr_lock="$pr_cache_dir/.$branch_key.lock"
    if [ -d "$pr_lock" ]; then
      lock_mtime=$(stat -f %m "$pr_lock" 2>/dev/null || stat -c %Y "$pr_lock" 2>/dev/null || echo 0)
      if [ $(( now - lock_mtime )) -gt 30 ]; then rmdir "$pr_lock" 2>/dev/null || true; fi
    fi
    # mkdir is the atomic lock: a single refresh runs even across concurrent renders.
    if mkdir "$pr_lock" 2>/dev/null; then
      (
        url=$(cd "$cwd" 2>/dev/null && GH_NO_UPDATE_NOTIFIER=1 gh pr view --json url -q .url 2>/dev/null || true)
        tmp="$pr_cache_file.tmp.$$"
        printf '%s' "$url" >"$tmp" 2>/dev/null && mv -f "$tmp" "$pr_cache_file" 2>/dev/null
        rmdir "$pr_lock" 2>/dev/null || true
      ) >/dev/null 2>&1 &
      disown 2>/dev/null || true
    fi
  fi
  [ -n "$pr_url" ] && pr_num=$(printf '%s' "$pr_url" | sed -n 's#.*/pull/\([0-9][0-9]*\).*#\1#p')
fi

# OPTIONAL — active external-tool call marker, e.g. written by a
# PreToolUse/PostToolUse hook pair around calls to a cross-vendor review tool.
# No-ops (empty segment) if the marker file doesn't exist. Adapt the path/hook
# names to your own equivalent, or delete this block entirely. Statusline-side
# TTL of 30 min is the last GC line of defense.
ext_marker="$project_dir/tmp/.external-tool-active.json"
ext_tool=""; ext_elapsed=0
if [ -f "$ext_marker" ]; then
  ext_started=$(jq -r '.started_at // 0' "$ext_marker" 2>/dev/null || echo 0)
  if [ "$ext_started" -gt 0 ]; then
    ext_elapsed=$(( now - ext_started ))
    if [ "$ext_elapsed" -gt 1800 ]; then
      rm -f "$ext_marker" 2>/dev/null || true
      ext_elapsed=0
    else
      ext_tool=$(jq -r '.tool // empty' "$ext_marker" 2>/dev/null)
    fi
  fi
fi

# OPTIONAL — cumulative token counter for that same external tool (per Claude
# session_id, auto-reset by whichever hook you write it from).
ext_tok_file="$project_dir/tmp/.external-tool-tokens.json"
ext_tokens=0
if [ -f "$ext_tok_file" ]; then
  ext_tokens=$(jq -r '.total // 0' "$ext_tok_file" 2>/dev/null || echo 0)
fi

# Auth identity for the current session — which account is logged in.
# Claude Code does not expose this in the statusline JSON (confirmed against
# docs.claude.com/statusline 2026-05), but the OAuth profile is persisted in
# ~/.claude.json as oauthAccount.{displayName,emailAddress}. Prefer the
# displayName when set, fall back to the email's local part for compactness,
# render "API" when oauthAccount is absent (API-key sessions). Silent fail if
# the file or jq path is unavailable — the statusline must never break on a
# missing optional field.
auth_label=""
if [ -f "$HOME/.claude.json" ]; then
  auth_label=$(jq -r '
    (.oauthAccount // null) as $a |
    if $a == null then "API"
    else
      ($a.displayName // "") as $name |
      ($a.emailAddress // "") as $email |
      if ($name | length) > 0 then $name
      elif ($email | length) > 0 then ($email | split("@")[0])
      else "?" end
    end
  ' "$HOME/.claude.json" 2>/dev/null || echo "")
fi

# OPTIONAL — parallel Claude instances: count OTHER live sessions sharing this
# host (e.g. a shared dev DB / Docker setup). Reads a `coord_others_count`
# shell function from a multi-instance coordination lib this repo doesn't
# include — build your own (liveness via PID `kill -0` + a TTL lease fallback
# is a reasonable pattern) or delete this block. No-ops (0 peers, hidden) if
# the lib isn't present. The count is the right differentiator here — an auth
# badge cannot distinguish parallel instances since they all run under the
# same account. Silent 0 if the session id, the lib, or jq is unavailable —
# the statusline must never break on it.
peers=0
sid=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
instances_lib="$project_dir/.claude/hooks/lib/instances.sh"
if [ -n "$sid" ] && [ -f "$instances_lib" ]; then
  # shellcheck source=/dev/null
  . "$instances_lib" 2>/dev/null && peers=$(coord_others_count "$sid" 2>/dev/null || echo 0)
fi
valid_width "$peers" || peers=0

# OPTIONAL side-effect — export a burn-rate snapshot other hooks could read
# (e.g. a UserPromptSubmit hook nudging you to delegate work when the 5h quota
# is at risk). Best-effort, atomic write, no impact on rendering if it fails.
# Delete this block if nothing in your config consumes the file.
burnrate_data=$(echo "$input" | jq -c --argjson now "$now" '
  (.rate_limits.five_hour.used_percentage // 0) as $rl |
  (.rate_limits.five_hour.resets_at // 0) as $rlReset |
  ([$rlReset - $now, 0] | max) as $rlRemaining |
  (18000 - $rlRemaining) as $rlElapsed |
  (if $rl > 0 and $rlElapsed > 0 then (((100 - $rl) * $rlElapsed / $rl) | floor) else 0 end) as $etaSec |
  (if   $rlReset == 0 or $rlRemaining <= 0 then "unknown"
   elif $rl >= 99 then "quota"
   elif $rlElapsed < 600 or $rl < 1 then "unknown"
   elif $etaSec < $rlRemaining then "danger"
   else "ok" end) as $status |
  {ts: $now, rl: $rl, rlRemaining: $rlRemaining, etaSec: $etaSec, status: $status}
' 2>/dev/null)
if [ -n "$burnrate_data" ]; then
  burnrate_file="$project_dir/tmp/.claude-burnrate.json"
  burnrate_dir=$(dirname "$burnrate_file")
  if [ -d "$burnrate_dir" ] || mkdir -p "$burnrate_dir" 2>/dev/null; then
    burnrate_tmp="${burnrate_file}.tmp.$$"
    # trap guarantees the tmpfile is removed even on SIGKILL/SIGINT between
    # printf and mv (otherwise an orphan in tmp/).
    trap 'rm -f "$burnrate_tmp" 2>/dev/null' EXIT
    if printf '%s\n' "$burnrate_data" >"$burnrate_tmp" 2>/dev/null; then
      mv -f "$burnrate_tmp" "$burnrate_file" 2>/dev/null || rm -f "$burnrate_tmp" 2>/dev/null
    fi
    trap - EXIT
  fi
fi

echo "$input" | jq -r --arg b "$branch" --arg project "$project" --arg wt "$wt_name" --arg prUrl "$pr_url" --arg prNum "$pr_num" --arg effort "$effort" --arg auth "$auth_label" --arg extTool "$ext_tool" --argjson extElapsed "$ext_elapsed" --argjson extTokens "$ext_tokens" --argjson now "$now" --argjson ahead "$ahead" --argjson behind "$behind" --argjson upstream "$upstream" --argjson width "$width" --argjson peers "$peers" '
  def color(code; text): "\u001b[\(code)m\(text)\u001b[0m";
  def dim(text): color("2"; text);
  def bold(text): color("1"; text);
  def cyan(text): color("36"; text);
  def magenta(text): color("35"; text);
  def green(text): color("32"; text);
  def red(text): color("31"; text);
  def yellow(text): color("33"; text);
  def threshold(pct): if pct >= 80 then "31" elif pct >= 50 then "33" else "32" end;
  # "heat" 256-color palette: green -> yellow -> orange -> red gradient (more granular than the 8-color trio).
  def heat(pct):
    if   pct >= 85 then "38;5;196"
    elif pct >= 70 then "38;5;208"
    elif pct >= 50 then "38;5;220"
    elif pct >= 30 then "38;5;82"
    else                "38;5;46" end;
  def fmtPct(pct): (pct | round) as $p | color(heat($p); "\($p)%");
  def rep(s; n): if n <= 0 then "" else s * n end;
  # 10-step bar over 5 cells: combines full-block (█) and half-block (▌) for
  # double resolution without taking more width. Empty in ░ (more discreet than ▱).
  def bar(pct):
    ([pct / 10 | floor, 10] | min) as $t |
    ($t / 2 | floor) as $full |
    ($t % 2) as $half |
    color(heat(pct); rep("█"; $full) + (if $half == 1 then "▌" else "" end))
      + dim(rep("░"; 5 - $full - $half));
  def fmtDuration(s):
    if s < 60 then "\(s)s"
    elif s < 3600 then "\(s/60|floor)m"
    else "\(s/3600|floor)h\((s%3600)/60|floor)m"
    end;
  def fmtCost(c):
    (c * 100 | floor) as $cents |
    ($cents % 100) as $m |
    "\(($cents/100) | floor).\(if $m < 10 then "0\($m)" else "\($m)" end)";
  # Compact token formatter: 850 → "850", 8543 → "8.5k", 124000 → "124k", 1234567 → "1.2M".
  def fmtTokens(n):
    if   n >= 1000000 then "\((n/100000|floor)/10)M"
    elif n >= 10000   then "\(n/1000|floor)k"
    elif n >= 1000    then "\((n/100|floor)/10)k"
    else "\(n)" end;
  # Visible length: strip OSC 8 (hyperlinks), then CSI (colors), then any stray
  # ESC bytes, before counting codepoints. The final sweep is defensive: it
  # catches partial sequences (e.g. an OSC 8 opener without its terminator)
  # that would otherwise inflate the count and wrap lines prematurely.
  def visibleLen(s):
    s
    | gsub("\\][^]*\\\\"; "")
    | gsub("\\[[0-9;]*[A-Za-z]"; "")
    | gsub(""; "")
    | length;

  ((.cost.total_duration_ms // 0)/1000|floor) as $s |
  # context_window.used_percentage can be null early in a session (fresh start,
  # or right after --resume before Claude Code recomputes usage from the
  # reloaded transcript) — keep it raw so it renders as "unknown", not a false 0%.
  (.context_window.used_percentage) as $ctxRaw |
  (.rate_limits.five_hour.used_percentage // 0) as $rl |
  (.rate_limits.five_hour.resets_at // 0) as $rlReset |
  (.output_style.name // "default") as $style |
  (.model.display_name // "?") as $mname |
  (if   $mname | test("Opus"; "i")   then {icon:"◈", col:"35"}
   elif $mname | test("Sonnet"; "i") then {icon:"♪", col:"36"}
   elif $mname | test("Haiku"; "i")  then {icon:"✎", col:"33"}
   else {icon:"❯", col:"2"} end) as $mStyle |
  (.cost.total_cost_usd // 0) as $usd |
  (.cost.total_lines_added // 0) as $la |
  (.cost.total_lines_removed // 0) as $lr |
  ([$rlReset - $now, 0] | max) as $rlRemaining |
  (18000 - $rlRemaining) as $rlElapsed |
  (if $rlReset == 0 or $rlRemaining <= 0 then ""
   elif $rl >= 99 then red("⛔ quota")
   elif $rlElapsed < 600 or $rl < 1 then ""
   else
     (((100 - $rl) * $rlElapsed / $rl) | floor) as $etaSec |
     (if $etaSec < $rlRemaining then red("⚠ ETA " + fmtDuration($etaSec))
      else green("✓ ETA " + fmtDuration($etaSec)) end)
   end) as $burnDisplay |
  (if $upstream == 0 then dim("⎇ ") + yellow($b) + dim(" ⚠")
   elif $behind > 0 and $ahead > 0 then dim("⎇ ") + red($b) + " " + red("↓\($behind)") + " " + yellow("↑\($ahead)")
   elif $behind > 0 then dim("⎇ ") + red($b) + " " + red("↓\($behind)")
   elif $ahead > 0 then dim("⎇ ") + yellow($b) + " " + yellow("↑\($ahead)")
   else dim("⎇ ") + cyan($b) end) as $branchDisplay |
  (if $prUrl != "" and $prNum != "" then
     "\u001b]8;;\($prUrl)\u001b\\" + magenta("⇄ PR#\($prNum)") + "\u001b]8;;\u001b\\"
   else "" end) as $prDisplay |
  (if $wt != "" then magenta("⧉ " + $wt) else "" end) as $wtDisplay |
  (if $peers > 0 then color("38;5;108"; "⇉ \($peers) peer" + (if $peers > 1 then "s" else "" end)) else "" end) as $peersDisplay |
  (if $extTool != "" then
     color("38;5;213"; "✦ " + $extTool + " " + fmtDuration($extElapsed))
   else "" end) as $extActiveDisplay |
  (if $extTokens > 0 then
     color("38;5;111"; "▤ " + fmtTokens($extTokens) + " ext")
   else "" end) as $extTokensDisplay |
  (if $effort == "" or $effort == "default" then ""
   elif $effort == "max" then red(bold("⚙ " + $effort))
   elif $effort == "xhigh" then red("⚙ " + $effort)
   elif $effort == "high" then magenta("⚙ " + $effort)
   elif $effort == "medium" then yellow("⚙ " + $effort)
   elif $effort == "low" then green("⚙ " + $effort)
   else dim("⚙ " + $effort) end) as $effortDisplay |
  # Auth tier badge — dim by default, red for API key sessions (no oauth profile)
  # so the lack of a subscription tier is visually obvious.
  (if $auth == "" then ""
   elif $auth == "API" then red("❖ " + $auth)
   else color("38;5;141"; "❖ " + $auth) end) as $authDisplay |
  (if $ctxRaw == null then dim("⋯ ctx")
   else bar($ctxRaw) + " " + fmtPct($ctxRaw) + dim(" ctx") end) as $ctxDisplay |
  [
    bold($project),
    $branchDisplay
  ] + (if $wtDisplay != "" then [$wtDisplay] else [] end)
    + (if $prDisplay != "" then [$prDisplay] else [] end)
    + (if $peersDisplay != "" then [$peersDisplay] else [] end)
    + (if $extActiveDisplay != "" then [$extActiveDisplay] else [] end)
    + (if $extTokensDisplay != "" then [$extTokensDisplay] else [] end) + [
    color($mStyle.col; $mStyle.icon) + " " + bold($mname)
  ] + (if $authDisplay != "" then [$authDisplay] else [] end)
    + (if $effortDisplay != "" then [$effortDisplay] else [] end) + [
    $ctxDisplay,
    dim("⏱ " + fmtDuration($s)),
    green("$" + fmtCost($usd)),
    green("+\($la)") + dim("/") + red("-\($lr)"),
    dim("⧖ 5h ") + bar($rl) + " " + fmtPct($rl) + (if $rlReset > 0 and $rlRemaining > 0 then dim(" ↻" + fmtDuration($rlRemaining)) else "" end) + (if $burnDisplay != "" then " " + $burnDisplay else "" end)
  ] + (if $style != "default" then [magenta($style)] else [] end)
  | reduce .[] as $seg (
      {lines: [], current: "", curLen: 0};
      (visibleLen($seg)) as $l |
      if .curLen == 0 then
        {lines: .lines, current: $seg, curLen: $l}
      elif (.curLen + 3 + $l) > $width then
        {lines: (.lines + [.current]), current: $seg, curLen: $l}
      else
        {lines: .lines, current: (.current + dim(" · ") + $seg), curLen: (.curLen + 3 + $l)}
      end
    )
  | (.lines + [.current])
  | join("\n")
'
