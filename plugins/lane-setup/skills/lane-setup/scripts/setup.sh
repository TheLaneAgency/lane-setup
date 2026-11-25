#!/bin/bash
# Lane setup: gets a colleague's Mac ready for the Lane Claude Code plugins,
# with no Terminal. Claude runs each command from the lane-setup skill.
#
#   setup.sh status                 what's done and what isn't, as key=value lines
#   setup.sh clt                    opens Apple's installer for git and python3
#   setup.sh gh                     installs GitHub's gh tool into ~/.local/bin
#   setup.sh gh-login               starts the browser sign-in and prints the one-time code
#   setup.sh gh-finish              after the code is approved: sets git up to use gh
#   setup.sh pandoc                 installs pandoc into ~/.local/bin
#   setup.sh path                   puts ~/.local/bin on the PATH for new sessions
#   setup.sh plugins [name ...]     adds the Lane marketplaces and installs plugins
#                                   (lane-site-generator if none named, "all" for every one)
#   setup.sh webtracker             connects WebTracker; reads the token on stdin
#
# Nothing here needs admin rights or Homebrew.

set -u

BIN="$HOME/.local/bin"
SHARE="$HOME/.local/share/lane-setup"
LOGIN_LOG="$SHARE/gh-login.log"
LANE_REPO="TheLaneAgency/lane-claude-skills"
SETUP_REPO="TheLaneAgency/lane-setup"
WEBTRACKER_MCP="https://webtracker.thelane.io/mcp"
CHROME_EXT="fcoeoabgfenejglbffodgkkbkcdhcgfn"

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
        echo "lane_repo_access=$(yn gh api "repos/$LANE_REPO" --silent)"
    else
        echo "gh=no"
        echo "gh_signed_in=no"
        echo "git_uses_gh=no"
        echo "lane_repo_access=no"
    fi
    echo "pandoc=$(yn command -v pandoc)"
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
        if echo "$markets" | grep -q "$LANE_REPO"; then echo "marketplace_lane=yes"; else echo "marketplace_lane=no"; fi
        if echo "$markets" | grep -q "$SETUP_REPO"; then echo "marketplace_lane_setup=yes"; else echo "marketplace_lane_setup=no"; fi
        echo "installed_lane_plugins=$(echo "$plugins" | grep -oE '[a-z0-9-]+@lane' | sort -u | tr '\n' ' ' | sed 's/ $//')"
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

cmd_pandoc() {
    if command -v pandoc >/dev/null 2>&1; then pandoc --version | head -1; return 0; fi
    local tag; tag="$(latest_tag jgm/pandoc)"
    [ -n "$tag" ] || { echo "couldn't find the latest pandoc release"; return 1; }
    install_zip "https://github.com/jgm/pandoc/releases/download/$tag/pandoc-$tag-$(arch_name)-macOS.zip" pandoc pandoc
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
    if gh api "repos/$LANE_REPO" --silent >/dev/null 2>&1; then
        echo "lane_repo_access=yes"
    else
        echo "lane_repo_access=no"
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
    local markets; markets="$("$claude" plugin marketplace list 2>/dev/null)"
    echo "$markets" | grep -q "$SETUP_REPO" || "$claude" plugin marketplace add "$SETUP_REPO" || return 1
    "$claude" plugin install lane-setup@lane-setup >/dev/null 2>&1 || true
    if echo "$markets" | grep -q "$LANE_REPO"; then
        "$claude" plugin marketplace update lane >/dev/null 2>&1
    else
        "$claude" plugin marketplace add "$LANE_REPO" || return 1
    fi
    local names=("$@")
    [ ${#names[@]} -eq 0 ] && names=(lane-site-generator)
    if [ "${names[0]}" = all ]; then
        names=($(grep -oE '"name": *"[a-z0-9-]+"' "$HOME/.claude/plugins/marketplaces/lane/.claude-plugin/marketplace.json" 2>/dev/null \
            | sed -E 's/.*"([a-z0-9-]+)"$/\1/' | grep -v '^lane$' | grep -v '^Lane'))
    fi
    local n failed=0
    for n in "${names[@]}"; do
        if "$claude" plugin install "$n@lane" >/dev/null 2>&1; then echo "installed $n"; else echo "failed $n"; failed=1; fi
    done
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

case "${1:-status}" in
    status) cmd_status ;;
    clt) cmd_clt ;;
    gh) cmd_gh ;;
    gh-login) cmd_gh_login ;;
    gh-finish) cmd_gh_finish ;;
    pandoc) cmd_pandoc ;;
    path) cmd_path ;;
    plugins) shift; cmd_plugins "$@" ;;
    webtracker) cmd_webtracker ;;
    *) echo "unknown command: $1"; exit 2 ;;
esac
