#!/bin/bash
# Lane setup: gets a Lane developer's Mac ready for the build plugins in
# TheLaneAgency/lane-dev-skills (site generator, WordPress, hosting), from the Code tab.
# Claude runs each command from the lane-setup skill.
#
#   setup.sh status        what's done and what isn't, as key=value lines
#   setup.sh clt           opens Apple's installer for git and python3
#   setup.sh gh            installs GitHub's gh tool into ~/.local/bin
#   setup.sh gh-login      starts the browser sign-in and prints the one-time code
#   setup.sh gh-finish     after the code is approved: sets git up to use gh
#   setup.sh path          puts ~/.local/bin on the PATH for new sessions
#   setup.sh plugins       adds the lane-dev marketplace and installs its plugins
#   setup.sh webtracker    connects WebTracker; reads the token on stdin
#   setup.sh check         the site generator's own check of Herd, WP-CLI, Node and the rest
#
# Everyone else's Lane plugins (timesheet, populate-content and the rest) come through
# Lane's Claude Team account, and each sets up what it needs on its first run.
#
# Nothing here needs admin rights or Homebrew.

set -u

BIN="$HOME/.local/bin"
SHARE="$HOME/.local/share/lane-setup"
LOGIN_LOG="$SHARE/gh-login.log"
DEV_REPO="TheLaneAgency/lane-dev-skills"
DEV_PLUGINS="lane-site-generator lane-wordpress lane-hosting"
SETUP_REPO="TheLaneAgency/lane-setup"
WEBTRACKER_MCP="https://webtracker.thelane.io/mcp"
CHROME_EXT="fcoeoabgfenejglbffodgkkbkcdhcgfn"
PLUGINS_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins"

mkdir -p "$BIN" "$SHARE"
export PATH="$BIN:$PATH"

claude_bin() {
    if [ -n "${CLAUDE_CODE_EXECPATH:-}" ] && [ -x "$CLAUDE_CODE_EXECPATH" ]; then
        echo "$CLAUDE_CODE_EXECPATH"
    elif command -v claude >/dev/null 2>&1; then
        command -v claude
    fi
}

clt_ready() { xcode-select -p >/dev/null 2>&1; }

arch_name() {
    case "$(uname -m)" in
        arm64) echo arm64 ;;
        *) echo x86_64 ;;
    esac
}

latest_tag() {
    local json; json="$(curl -fsSL "https://api.github.com/repos/$1/releases/latest")"
    echo "$json" | grep '"tag_name"' | head -1 | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'
}

yn() { if "$@" >/dev/null 2>&1; then echo yes; else echo no; fi; }

cmd_status() {
    local claude; claude="$(claude_bin)"
    echo "clt=$(yn clt_ready)"
    if clt_ready; then
        echo "git=$(yn git --version)"
        echo "python3=$(yn python3 -c 'pass')"
    else
        echo "git=no"
        echo "python3=no"
    fi
    if command -v gh >/dev/null 2>&1; then
        echo "gh=yes"
        echo "gh_signed_in=$(yn gh auth status --hostname github.com)"
        if git config --global --get-all credential.https://github.com.helper 2>/dev/null | grep -q 'gh auth git-credential'; then
            echo "git_uses_gh=yes"
        else
            echo "git_uses_gh=no"
        fi
        echo "dev_repo_access=$(yn gh api "repos/$DEV_REPO" --silent)"
    else
        echo "gh=no"
        echo "gh_signed_in=no"
        echo "git_uses_gh=no"
        echo "dev_repo_access=no"
    fi
    if grep -qs '.local/bin' "$HOME/.zprofile" && grep -qs '.local/bin' "$HOME/.zshrc"; then
        echo "path=yes"
    else
        echo "path=no"
    fi
    if [ -n "$claude" ]; then
        echo "claude=yes"
        local markets plugins
        markets="$("$claude" plugin marketplace list 2>/dev/null)"
        plugins="$("$claude" plugin list 2>/dev/null)"
        if echo "$markets" | grep -q "$DEV_REPO"; then echo "marketplace_lane_dev=yes"; else echo "marketplace_lane_dev=no"; fi
        if echo "$markets" | grep -q "$SETUP_REPO"; then echo "marketplace_lane_setup=yes"; else echo "marketplace_lane_setup=no"; fi
        echo "installed_dev_plugins=$(echo "$plugins" | grep -oE '[a-z0-9-]+@lane-dev$' | sort -u | tr '\n' ' ' | sed 's/ $//')"
        echo "old_lane_copies=$(echo "$plugins" | grep -oE '(lane-site-generator|lane-wordpress|lane-hosting)@lane$' | sort -u | tr '\n' ' ' | sed 's/ $//')"
        echo "webtracker=$(yn "$claude" mcp get webtracker)"
    else
        echo "claude=no"
    fi
    if ls -d "$HOME/Library/Application Support/Google/Chrome/"*/Extensions/"$CHROME_EXT" >/dev/null 2>&1; then
        echo "chrome_extension=yes"
    else
        echo "chrome_extension=no"
    fi
}

cmd_clt() {
    if clt_ready; then echo "already installed"; return 0; fi
    xcode-select --install >/dev/null 2>&1
    echo "opened Apple's installer"
}

install_zip() {
    # install_zip <url> <name-of-binary> <folder-name>
    local url="$1" name="$2" dir="$SHARE/$3" tmp="$SHARE/download.zip"
    rm -rf "$dir" "$tmp"
    curl -fsSL "$url" -o "$tmp" || { echo "download failed: $url"; return 1; }
    mkdir -p "$dir"
    unzip -q "$tmp" -d "$dir" || { echo "unzip failed"; return 1; }
    rm -f "$tmp"
    local found; found="$(find "$dir" -type f -name "$name" -perm -u+x | head -1)"
    [ -n "$found" ] || { echo "no $name in the download"; return 1; }
    ln -sf "$found" "$BIN/$name"
    "$BIN/$name" --version | head -1
}

cmd_gh() {
    if command -v gh >/dev/null 2>&1; then gh --version | head -1; return 0; fi
    local tag arch; tag="$(latest_tag cli/cli)"; arch="$(arch_name)"
    [ "$arch" = x86_64 ] && arch=amd64
    [ -n "$tag" ] || { echo "couldn't find the latest gh release"; return 1; }
    install_zip "https://github.com/cli/cli/releases/download/$tag/gh_${tag#v}_macOS_$arch.zip" gh gh
}

cmd_gh_login() {
    command -v gh >/dev/null 2>&1 || { echo "gh isn't installed yet: run setup.sh gh"; return 1; }
    if gh auth status --hostname github.com >/dev/null 2>&1; then echo "already signed in"; return 0; fi
    pkill -f 'gh auth login --hostname github.com' >/dev/null 2>&1
    rm -f "$LOGIN_LOG"
    BROWSER=true nohup gh auth login --hostname github.com --git-protocol https --web --skip-ssh-key \
        </dev/null >"$LOGIN_LOG" 2>&1 &
    local code="" i
    for i in $(seq 1 30); do
        code="$(grep -oE '[A-Z0-9]{4}-[A-Z0-9]{4}' "$LOGIN_LOG" 2>/dev/null | head -1)"
        [ -n "$code" ] && break
        sleep 1
    done
    [ -n "$code" ] || { echo "no code from gh:"; cat "$LOGIN_LOG"; return 1; }
    open "https://github.com/login/device"
    echo "code=$code"
}

cmd_gh_finish() {
    if ! gh auth status --hostname github.com >/dev/null 2>&1; then
        echo "not signed in yet"
        tail -3 "$LOGIN_LOG" 2>/dev/null
        return 1
    fi
    gh auth setup-git --hostname github.com || return 1
    echo "signed in as $(gh api user --jq .login)"
    if gh api "repos/$DEV_REPO" --silent >/dev/null 2>&1; then
        echo "dev_repo_access=yes"
    else
        echo "dev_repo_access=no"
    fi
}

cmd_path() {
    local line='export PATH="$HOME/.local/bin:$PATH"' f
    for f in "$HOME/.zprofile" "$HOME/.zshrc"; do
        grep -qs '.local/bin' "$f" || printf '\n%s\n' "$line" >> "$f"
    done
    echo "done"
}

cmd_plugins() {
    local claude; claude="$(claude_bin)"
    [ -n "$claude" ] || { echo "can't find Claude Code: run this from a Code tab session"; return 1; }
    clt_ready || { echo "git isn't installed yet: run setup.sh clt"; return 1; }
    local markets n failed=0
    markets="$("$claude" plugin marketplace list 2>/dev/null)"
    echo "$markets" | grep -q "$SETUP_REPO" || "$claude" plugin marketplace add "$SETUP_REPO" >/dev/null 2>&1 || return 1
    "$claude" plugin install lane-setup@lane-setup >/dev/null 2>&1 || true
    if echo "$markets" | grep -q "$DEV_REPO"; then
        "$claude" plugin marketplace update lane-dev >/dev/null 2>&1
    elif ! "$claude" plugin marketplace add "$DEV_REPO" >/dev/null 2>&1; then
        echo "no access to $DEV_REPO"
        return 1
    fi
    for n in $DEV_PLUGINS; do
        if "$claude" plugin install "$n@lane-dev" >/dev/null 2>&1; then echo "installed $n"; else echo "failed $n"; failed=1; fi
    done
    move_old_copies "$claude" || failed=1
    return $failed
}

# Until 26 November 2026 the build plugins were in the lane marketplace, and a copy
# installed from there stops loading. It's removed. Someone who had the site generator
# for populate-content gets lane-populate-content in its place, so they keep the skill.
move_old_copies() {
    local claude="$1" n installed failed=0
    installed="$("$claude" plugin list 2>/dev/null)"
    for n in $DEV_PLUGINS; do
        echo "$installed" | grep -qE "$n@lane$" || continue
        if "$claude" plugin uninstall "$n@lane" >/dev/null 2>&1; then echo "removed $n@lane"; else echo "failed to remove $n@lane"; failed=1; fi
    done
    if echo "$installed" | grep -qE "lane-site-generator@lane$" && ! echo "$installed" | grep -qE "lane-populate-content@lane$"; then
        if "$claude" plugin install lane-populate-content@lane >/dev/null 2>&1; then echo "installed lane-populate-content"; else echo "failed lane-populate-content"; failed=1; fi
    fi
    return $failed
}

cmd_webtracker() {
    local claude token; claude="$(claude_bin)"
    [ -n "$claude" ] || { echo "can't find Claude Code: run this from a Code tab session"; return 1; }
    token="$(cat | tr -d '[:space:]')"
    token="${token#Bearer}"
    [ -n "$token" ] || { echo "no token on stdin"; return 1; }
    "$claude" mcp remove webtracker --scope user >/dev/null 2>&1
    "$claude" mcp add --scope user --transport http webtracker "$WEBTRACKER_MCP" \
        --header "Authorization: Bearer $token" >/dev/null || return 1
    echo "connected"
}

cmd_check() {
    local script="$PLUGINS_DIR/marketplaces/lane-dev/plugins/lane-site-generator/skills/generate-site/scripts/check-env.sh"
    [ -f "$script" ] || { echo "the site generator isn't installed yet: run setup.sh plugins"; return 1; }
    bash "$script"
}

case "${1:-status}" in
    status) cmd_status ;;
    clt) cmd_clt ;;
    gh) cmd_gh ;;
    gh-login) cmd_gh_login ;;
    gh-finish) cmd_gh_finish ;;
    path) cmd_path ;;
    plugins) cmd_plugins ;;
    webtracker) cmd_webtracker ;;
    check) cmd_check ;;
    *) echo "unknown command: $1"; exit 2 ;;
esac
