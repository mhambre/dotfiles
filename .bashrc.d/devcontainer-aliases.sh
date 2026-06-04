# Personal devcontainer helpers: devu (up + bootstrap + enter), devi (enter), devd (stop).
# Drop this into ~/.bashrc.d/ as e.g. devcontainer.sh

# Host-side config you want copied into every container. Override in env if needed.
: "${DEVU_NVIM_CONFIG:=$HOME/.config/nvim}"
: "${DEVU_NVIM_VERSION:=latest}"   # 'latest', 'stable', 'nightly', or a tag like v0.10.2
: "${DEVU_NPM_GLOBALS:=@anthropic-ai/claude-code @openai/codex tree-sitter-cli}"  # tree-sitter CLI for nvim-treesitter parser builds
: "${DEVU_NODE_VERSION:=v22.11.0}"  # used when the container has no node/npm
: "${DEVU_SYSTEM_DEPS:=unzip python3 python3-pip python3-venv ripgrep tmux bat fzf gcc golang-go}"  # apt names; skipped if no sudo/apt. gcc: compiles treesitter parsers; golang-go: Mason needs go for gopls
: "${DEVU_BASHRC_D_EXCLUDE:=devcontainer-aliases.sh}"  # space-separated filenames in ~/.bashrc.d/ to skip

_devu_container_id() {
    # devcontainer CLI labels the container with the absolute workspace path.
    local folder
    folder="$(realpath "${1:-$PWD}")"
    docker ps -q --filter "label=devcontainer.local_folder=${folder}" | head -n1
}

_devu_remote_user() {
    devcontainer exec --workspace-folder "${1:-$PWD}" sh -c 'printf %s "${USER:-$(id -un)}"' 2>/dev/null
}

# Copy a host file/dir into the container at the given dest, then chown to remote user.
# $1=ws  $2=cid  $3=user  $4=host_path  $5=dest_path_in_container
_devu_cp() {
    local ws="$1" cid="$2" user="$3" src="$4" dst="$5"
    [ -e "$src" ] || return 0
    devcontainer exec --workspace-folder "$ws" mkdir -p "$(dirname "$dst")"
    if [ -d "$src" ]; then
        docker cp "$src/." "$cid:$dst" >/dev/null
    else
        docker cp "$src" "$cid:$dst" >/dev/null
    fi
    devcontainer exec --workspace-folder "$ws" sh -c \
        "chown -R '$user' '$dst' 2>/dev/null || true"
}

_devu_bootstrap() {
    local ws="${1:-$PWD}"
    local cid user home arch tarname node_arch
    cid="$(_devu_container_id "$ws")"
    if [ -z "$cid" ]; then
        echo "devu: could not locate container for $ws" >&2
        return 1
    fi
    user="$(_devu_remote_user "$ws")"
    user="${user:-root}"
    home="$(devcontainer exec --workspace-folder "$ws" sh -c 'printf %s "$HOME"')"
    home="${home:-/root}"
    arch="$(devcontainer exec --workspace-folder "$ws" uname -m | tr -d '\r')"

    echo "devu: bootstrapping $cid ($user @ $home)"

    # Config copies are NOT idempotent-by-presence — host is authoritative,
    # so we always re-copy. Installs (nvim binary, node, npm) stay idempotent below.

    # ---------- nvim config ----------
    if [ -d "$DEVU_NVIM_CONFIG" ]; then
        echo "devu:   copying nvim config"
        _devu_cp "$ws" "$cid" "$user" "$DEVU_NVIM_CONFIG" "$home/.config/nvim"
    fi

    # ---------- claude config + creds ----------
    # Selective copy — skip the giant per-project history dirs.
    if [ -d "$HOME/.claude" ]; then
        echo "devu:   copying claude config"
        devcontainer exec --workspace-folder "$ws" mkdir -p "$home/.claude"
        for f in .credentials.json settings.json settings.local.json CLAUDE.md; do
            [ -e "$HOME/.claude/$f" ] && \
                docker cp "$HOME/.claude/$f" "$cid:$home/.claude/$f" >/dev/null
        done
        [ -f "$HOME/.claude.json" ] && \
            docker cp "$HOME/.claude.json" "$cid:$home/.claude.json" >/dev/null
        devcontainer exec --workspace-folder "$ws" sh -c \
            "chown -R '$user' '$home/.claude' '$home/.claude.json' 2>/dev/null || true"
    fi

    # ---------- codex creds + config ----------
    if [ -d "$HOME/.codex" ]; then
        echo "devu:   copying codex creds"
        devcontainer exec --workspace-folder "$ws" mkdir -p "$home/.codex"
        for f in auth.json config.toml; do
            [ -e "$HOME/.codex/$f" ] && \
                docker cp "$HOME/.codex/$f" "$cid:$home/.codex/$f" >/dev/null
        done
        devcontainer exec --workspace-folder "$ws" sh -c \
            "chown -R '$user' '$home/.codex' 2>/dev/null || true"
    fi

    # ---------- tmux config ----------
    if [ -f "$HOME/.tmux.conf" ]; then
        echo "devu:   copying tmux config"
        docker cp "$HOME/.tmux.conf" "$cid:$home/.tmux.conf" >/dev/null
        devcontainer exec --workspace-folder "$ws" sh -c \
            "chown '$user' '$home/.tmux.conf' 2>/dev/null || true"
    fi

    # ---------- github copilot creds ----------
    if [ -d "$HOME/.config/github-copilot" ]; then
        echo "devu:   copying github-copilot creds"
        _devu_cp "$ws" "$cid" "$user" "$HOME/.config/github-copilot" "$home/.config/github-copilot"
    fi

    # ---------- system deps for Mason etc. (unzip, python3, pip, rg) ----------
    # Idempotent: only install names that resolve to missing binaries on PATH.
    local missing_bin=""
    for pkg in $DEVU_SYSTEM_DEPS; do
        local bin
        case "$pkg" in
            python3-pip) bin=pip3 ;;
            python3-venv) bin=python3 ;;  # venv is a python3 module; presence implied by python3
            ripgrep) bin=rg ;;
            golang-go) bin=go ;;
            bat) bin='bat || command -v batcat' ;;  # Debian ships bat as 'batcat'
            *) bin="$pkg" ;;
        esac
        devcontainer exec --workspace-folder "$ws" sh -c "command -v $bin >/dev/null" \
            || missing_bin="$missing_bin $pkg"
    done
    if [ -n "$missing_bin" ]; then
        echo "devu:   installing system deps:$missing_bin"
        devcontainer exec --workspace-folder "$ws" sh -c "
            export DEBIAN_FRONTEND=noninteractive
            if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then SUDO='sudo'; else SUDO=''; fi
            if command -v apt-get >/dev/null 2>&1; then
                \$SUDO apt-get update -qq && \$SUDO apt-get install -y --no-install-recommends$missing_bin
            elif command -v apk >/dev/null 2>&1; then
                \$SUDO apk add --no-cache$missing_bin
            else
                echo 'devu: no apt-get/apk and/or no sudo — skipping system deps' >&2
                exit 1
            fi
        " || echo "devu:   system deps install failed (Mason packages may not install)"
    fi

    # ---------- bat symlink (Debian ships /usr/bin/batcat) ----------
    devcontainer exec --workspace-folder "$ws" sh -c "
        if ! command -v bat >/dev/null 2>&1 && command -v batcat >/dev/null 2>&1; then
            mkdir -p '$home/.local/bin'
            ln -sf \"\$(command -v batcat)\" '$home/.local/bin/bat'
        fi
    " 2>/dev/null

    # ---------- lazygit ----------
    if ! devcontainer exec --workspace-folder "$ws" test -x "$home/.local/bin/lazygit" 2>/dev/null; then
        local lg_arch
        case "$arch" in
            x86_64|amd64) lg_arch="x86_64" ;;
            aarch64|arm64) lg_arch="arm64" ;;
            *) lg_arch="" ; echo "devu:   unsupported arch '$arch' for lazygit" >&2 ;;
        esac
        if [ -n "$lg_arch" ]; then
            echo "devu:   installing lazygit"
            devcontainer exec --workspace-folder "$ws" sh -c "
                set -e
                ver=\$(curl -fsSL https://api.github.com/repos/jesseduffield/lazygit/releases/latest \
                    | sed -n 's/.*\"tag_name\": *\"v\\([^\"]*\\)\".*/\\1/p' | head -n1)
                [ -n \"\$ver\" ] || { echo 'devu: failed to resolve lazygit version' >&2; exit 1; }
                mkdir -p '$home/.local/bin'
                cd /tmp
                curl -fsSL \"https://github.com/jesseduffield/lazygit/releases/download/v\${ver}/lazygit_\${ver}_Linux_${lg_arch}.tar.gz\" -o lazygit.tgz
                tar -xzf lazygit.tgz lazygit
                mv lazygit '$home/.local/bin/lazygit'
                chmod +x '$home/.local/bin/lazygit'
                rm -f lazygit.tgz
            " || echo "devu:   lazygit install failed"
        fi
    fi

    # ---------- bashrc.d aliases ----------
    if [ -d "$HOME/.bashrc.d" ]; then
        echo "devu:   copying bashrc.d"
        devcontainer exec --workspace-folder "$ws" mkdir -p "$home/.bashrc.d"
        for f in "$HOME/.bashrc.d/"*.sh; do
            [ -f "$f" ] || continue
            local base
            base="$(basename "$f")"
            local skip=0
            for ex in $DEVU_BASHRC_D_EXCLUDE; do
                [ "$base" = "$ex" ] && skip=1 && break
            done
            [ "$skip" = 1 ] && continue
            docker cp "$f" "$cid:$home/.bashrc.d/$base" >/dev/null
        done
        devcontainer exec --workspace-folder "$ws" sh -c \
            "chown -R '$user' '$home/.bashrc.d' 2>/dev/null || true"
        devcontainer exec --workspace-folder "$ws" sh -c "
            rc='$home/.bashrc'
            [ -f \"\$rc\" ] || touch \"\$rc\"
            if ! grep -q 'devu bashrc.d' \"\$rc\" 2>/dev/null &&
               ! grep -q '\\.bashrc\\.d/.*\\.sh' \"\$rc\" 2>/dev/null; then
                {
                    printf '\n# devu bashrc.d\n'
                    printf 'if [ -d \"\$HOME/.bashrc.d\" ]; then\n'
                    printf '    for f in \"\$HOME/.bashrc.d/\"*.sh; do\n'
                    printf '        [ -r \"\$f\" ] && . \"\$f\"\n'
                    printf '    done\n'
                    printf '    unset f\n'
                    printf 'fi\n'
                } >> \"\$rc\"
            fi
            chown '$user' \"\$rc\" 2>/dev/null || true
        "
    fi

    # ---------- neovim binary ----------
    case "$arch" in
        x86_64|amd64) tarname="nvim-linux-x86_64.tar.gz" ;;
        aarch64|arm64) tarname="nvim-linux-arm64.tar.gz" ;;
        *) tarname="" ; echo "devu:   unsupported arch '$arch' for nvim" >&2 ;;
    esac
    if [ -n "$tarname" ] && \
       ! devcontainer exec --workspace-folder "$ws" test -x "$home/.local/bin/nvim" 2>/dev/null; then
        echo "devu:   installing neovim ($DEVU_NVIM_VERSION, $arch)"
        local nvim_url
        if [ "$DEVU_NVIM_VERSION" = "latest" ]; then
            nvim_url="https://github.com/neovim/neovim/releases/latest/download/$tarname"
        else
            nvim_url="https://github.com/neovim/neovim/releases/download/$DEVU_NVIM_VERSION/$tarname"
        fi
        devcontainer exec --workspace-folder "$ws" sh -c "
            set -e
            mkdir -p '$home/.local/bin' '$home/.local/nvim'
            cd /tmp
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL '$nvim_url' -o nvim.tgz
            elif command -v wget >/dev/null 2>&1; then
                wget -qO nvim.tgz '$nvim_url'
            else
                echo 'devu: need curl or wget for nvim' >&2; exit 1
            fi
            tar -xzf nvim.tgz -C '$home/.local/nvim' --strip-components=1
            ln -sf '$home/.local/nvim/bin/nvim' '$home/.local/bin/nvim'
            rm -f nvim.tgz
        " || echo "devu:   nvim install failed"
    fi

    # ---------- portable Node (only if container has no npm) ----------
    case "$arch" in
        x86_64|amd64) node_arch="linux-x64" ;;
        aarch64|arm64) node_arch="linux-arm64" ;;
        *) node_arch="" ;;
    esac
    if [ -n "$node_arch" ] && \
       ! devcontainer exec --workspace-folder "$ws" sh -c "PATH='$home/.local/bin:\$PATH' command -v npm >/dev/null"; then
        echo "devu:   installing portable Node $DEVU_NODE_VERSION ($node_arch)"
        local node_url="https://nodejs.org/dist/$DEVU_NODE_VERSION/node-$DEVU_NODE_VERSION-$node_arch.tar.xz"
        devcontainer exec --workspace-folder "$ws" sh -c "
            set -e
            mkdir -p '$home/.local/bin' '$home/.local/node'
            cd /tmp
            if command -v curl >/dev/null 2>&1; then
                curl -fsSL '$node_url' -o node.txz
            elif command -v wget >/dev/null 2>&1; then
                wget -qO node.txz '$node_url'
            else
                echo 'devu: need curl or wget for node' >&2; exit 1
            fi
            tar -xJf node.txz -C '$home/.local/node' --strip-components=1
            for b in node npm npx; do
                ln -sf '$home/.local/node/bin/'\$b '$home/.local/bin/'\$b
            done
            rm -f node.txz
        " || echo "devu:   node install failed"
    fi

    # ---------- npm globals (claude, codex, ...) ----------
    if devcontainer exec --workspace-folder "$ws" sh -c "PATH='$home/.local/bin:\$PATH' command -v npm >/dev/null"; then
        # Check what's missing — only install if any package's binary is absent.
        local need=""
        for pkg in $DEVU_NPM_GLOBALS; do
            local bin
            case "$pkg" in
                @anthropic-ai/claude-code) bin=claude ;;
                @openai/codex) bin=codex ;;
                *) bin="${pkg##*/}" ; bin="${bin%-cli}" ;;
            esac
            if ! devcontainer exec --workspace-folder "$ws" sh -c \
                "PATH='$home/.local/bin:\$PATH' command -v $bin >/dev/null"; then
                need="$need $pkg"
            fi
        done
        if [ -n "$need" ]; then
            echo "devu:   npm install -g$need"
            devcontainer exec --workspace-folder "$ws" sh -c "
                export PATH='$home/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:'\"\$PATH\"
                npm config set prefix '$home/.local' >/dev/null 2>&1 || true
                npm install -g$need
            " || echo "devu:   npm install failed — re-run 'devu' to retry"
        fi
    else
        echo "devu:   no npm available — skipping claude/codex"
    fi

    # ---------- PATH + COLORTERM + LANG for future shells ----------
    devcontainer exec --workspace-folder "$ws" sh -c "
        for rc in '$home/.bashrc' '$home/.profile' '$home/.zshrc'; do
            [ -f \"\$rc\" ] || continue
            grep -q 'devu env' \"\$rc\" 2>/dev/null && continue
            {
                printf '\n# devu env\n'
                printf 'export PATH=\"%s/.local/bin:\$PATH\"\n' '$home'
                printf 'export COLORTERM=\${COLORTERM:-truecolor}\n'
                printf 'export LANG=\${LANG:-C.UTF-8}\n'
                printf 'export LC_ALL=\${LC_ALL:-C.UTF-8}\n'
            } >> \"\$rc\"
        done
    "
}

# Builds/starts the devcontainer for the current workspace.
devu() {
    local ws="${1:-$PWD}"
    devcontainer up --workspace-folder "$ws" || return $?
    _devu_bootstrap "$ws" || return $?
    devi "$ws"
}

# Just enter the devcontainer for the current workspace. Must already be running.
devi() {
    local ws="${1:-$PWD}"
    local cid
    cid="$(_devu_container_id "$ws")"
    if [ -n "$cid" ]; then
        # docker exec lets us forward TERM/COLORTERM live; devcontainer exec doesn't.
        docker exec -it \
            -e "COLORTERM=${COLORTERM:-truecolor}" \
            -e "TERM=${TERM:-xterm-256color}" \
            -e "LANG=${LANG:-C.UTF-8}" \
            -e "LC_ALL=${LC_ALL:-C.UTF-8}" \
            "$cid" bash -l
    else
        devcontainer exec --workspace-folder "$ws" bash -l
    fi
}

# Rebuild the container from scratch, re-run bootstrap, and enter. Useful if you added new host
# config or just want a clean slate.
devr() {
    # Rebuild the devcontainer from scratch and re-bootstrap.
    local ws="${1:-$PWD}"
    devcontainer up --workspace-folder "$ws" --remove-existing-container || return $?
    _devu_bootstrap "$ws" || return $?
    devi "$ws"
}

# Stop the container for the current workspace.
devd() {
    local ws="${1:-$PWD}"
    local cid
    cid="$(_devu_container_id "$ws")"
    if [ -z "$cid" ]; then
        echo "devd: no running container for $ws" >&2
        return 1
    fi
    docker stop "$cid" >/dev/null && echo "devd: stopped $cid"
}
