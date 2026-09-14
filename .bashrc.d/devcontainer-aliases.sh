# Personal devcontainer helpers: devu (up + bootstrap + enter), devi (enter), devd (stop).
# Drop this into ~/.bashrc.d/ as e.g. devcontainer.sh

# Host-side config you want copied into every container. Override in env if needed.
: "${DEVU_NVIM_CONFIG:=$HOME/.config/nvim}"
: "${DEVU_NVIM_VERSION:=latest}"   # 'latest', 'stable', 'nightly', or a tag like v0.10.2
: "${DEVU_NODE_MANIFEST:=}"  # defaults to package.json beside the installed dotfiles
: "${DEVU_SHARED_AGENT_CONFIG:=$HOME/.agents}"
: "${DEVU_NODE_VERSION:=v22.11.0}"  # used when the container has no node/npm
: "${DEVU_SYSTEM_DEPS:=unzip python3 python3-pip python3-venv ripgrep tmux bat fzf gcc golang-go}"  # apt names; skipped if no sudo/apt. gcc: compiles treesitter parsers; golang-go: Mason needs go for gopls
: "${DEVU_BASHRC_D_EXCLUDE:=devcontainer-aliases.sh}"  # space-separated filenames in ~/.bashrc.d/ to skip
: "${DEVU_GIT_CRED_HOSTS:=github.com gitlab.tools.basedweights.com huggingface.co}"  # https hosts whose creds get exported from the host credential helper

_devu_npm_globals() {
    local manifest="$DEVU_NODE_MANIFEST"
    local source_dir shared_agents packages

    if [ -z "$manifest" ]; then
        source_dir="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
        if [ -f "$source_dir/../package.json" ]; then
            manifest="$source_dir/../package.json"
        fi
    fi
    if [ -z "$manifest" ] && [ -d "$DEVU_SHARED_AGENT_CONFIG" ]; then
        shared_agents="$(realpath "$DEVU_SHARED_AGENT_CONFIG")"
        if [ -f "$shared_agents/../package.json" ]; then
            manifest="$shared_agents/../package.json"
        fi
    fi
    if [ -z "$manifest" ] && [ -f "$HOME/package.json" ]; then
        manifest="$HOME/package.json"
    fi

    if [ -z "$manifest" ] || [ ! -r "$manifest" ]; then
        echo "devu: Node manifest not found; set DEVU_NODE_MANIFEST to package.json" >&2
        return 1
    fi
    if ! command -v node >/dev/null 2>&1; then
        echo "devu: host Node is required to read $manifest" >&2
        return 1
    fi

    packages="$(node -e '
        const manifest = require(process.argv[1]);
        const dependencies = {
            ...manifest.dependencies,
            ...manifest.devDependencies,
        };
        const specs = Object.entries(dependencies).map(
            ([name, version]) => `${name}@${version}`,
        );
        if (specs.length === 0) process.exit(1);
        process.stdout.write(specs.join(" "));
    ' "$manifest" 2>/dev/null)" || {
        echo "devu: could not read Node dependencies from $manifest" >&2
        return 1
    }
    printf '%s\n' "$packages"
}

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
# Never fails the bootstrap: the devcontainer may bind-mount the dest (docker cp
# then errors or is redundant), so a failed copy is just a warning.
# $1=ws  $2=cid  $3=user  $4=host_path  $5=dest_path_in_container
_devu_cp() {
    local ws="$1" cid="$2" user="$3" src="$4" dst="$5"
    [ -e "$src" ] || return 0
    devcontainer exec --workspace-folder "$ws" sh -c \
        "[ ! -L '$dst' ] || rm -f '$dst'; mkdir -p '$(dirname "$dst")'" 2>/dev/null
    if [ -d "$src" ]; then
        docker cp -L "$src/." "$cid:$dst" >/dev/null 2>&1
    else
        docker cp -L "$src" "$cid:$dst" >/dev/null 2>&1
    fi || echo "devu:   warning: copy to $dst failed (bind mount?) — continuing"
    devcontainer exec --workspace-folder "$ws" sh -c \
        "chown -R '$user' '$dst' 2>/dev/null || true"
    return 0
}

_devu_bootstrap() {
    local ws="${1:-$PWD}"
    local cid user home arch tarname node_arch shared_agents
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

    # Shared rules, skills, agents, commands, and hooks.
    shared_agents=""
    if [ -d "$DEVU_SHARED_AGENT_CONFIG" ]; then
        shared_agents="$(realpath "$DEVU_SHARED_AGENT_CONFIG")"
        echo "devu:   copying shared agent config"
        _devu_cp "$ws" "$cid" "$user" "$shared_agents" "$home/.agents"
    fi

    # ---------- claude config + creds ----------
    # Selective copy — skip the giant per-project history dirs.
    if [ -d "$HOME/.claude" ]; then
        echo "devu:   copying claude config"
        devcontainer exec --workspace-folder "$ws" mkdir -p "$home/.claude"
        for f in .credentials.json settings.json settings.local.json CLAUDE.md; do
            _devu_cp "$ws" "$cid" "$user" "$HOME/.claude/$f" "$home/.claude/$f"
        done
        _devu_cp "$ws" "$cid" "$user" "$HOME/.claude.json" "$home/.claude.json"
        if [ -n "$shared_agents" ]; then
            _devu_cp "$ws" "$cid" "$user" "$shared_agents/rules" "$home/.claude/rules"
            _devu_cp "$ws" "$cid" "$user" "$shared_agents/skills" "$home/.claude/skills"
            _devu_cp "$ws" "$cid" "$user" "$shared_agents/agents/claude" "$home/.claude/agents"
            _devu_cp "$ws" "$cid" "$user" "$shared_agents/commands" "$home/.claude/commands"
        fi
    fi

    # ---------- codex creds + config ----------
    if [ -d "$HOME/.codex" ]; then
        echo "devu:   copying codex creds"
        devcontainer exec --workspace-folder "$ws" mkdir -p "$home/.codex"
        for f in auth.json config.toml; do
            _devu_cp "$ws" "$cid" "$user" "$HOME/.codex/$f" "$home/.codex/$f"
        done
        for d in skills hooks prompts; do
            _devu_cp "$ws" "$cid" "$user" "$HOME/.codex/$d" "$home/.codex/$d"
        done
        if [ -n "$shared_agents" ]; then
            _devu_cp "$ws" "$cid" "$user" "$shared_agents/AGENTS.md" "$home/.codex/AGENTS.md"
            _devu_cp "$ws" "$cid" "$user" "$shared_agents/hooks/codex.json" "$home/.codex/hooks.json"
        fi
    fi

    # ---------- copilot cli config ----------
    # Selective copy — skip session-state/logs/sqlite session store.
    if [ -d "$HOME/.copilot" ]; then
        echo "devu:   copying copilot config"
        devcontainer exec --workspace-folder "$ws" mkdir -p "$home/.copilot"
        for f in config.json mcp-config.json settings.json; do
            _devu_cp "$ws" "$cid" "$user" "$HOME/.copilot/$f" "$home/.copilot/$f"
        done
        if [ -n "$shared_agents" ]; then
            _devu_cp "$ws" "$cid" "$user" "$shared_agents/skills" "$home/.copilot/skills"
            _devu_cp "$ws" "$cid" "$user" "$shared_agents/agents/copilot" "$home/.copilot/agents"
            _devu_cp "$ws" "$cid" "$user" "$shared_agents/hooks/copilot" "$home/.copilot/hooks"
            _devu_cp "$ws" "$cid" "$user" "$shared_agents/AGENTS.md" "$home/.copilot/copilot-instructions.md"
        fi
    fi

    # ---------- tmux config ----------
    if [ -f "$HOME/.tmux.conf" ]; then
        echo "devu:   copying tmux config"
        _devu_cp "$ws" "$cid" "$user" "$HOME/.tmux.conf" "$home/.tmux.conf"
    fi

    # ---------- github copilot creds ----------
    if [ -d "$HOME/.config/github-copilot" ]; then
        echo "devu:   copying github-copilot creds"
        _devu_cp "$ws" "$cid" "$user" "$HOME/.config/github-copilot" "$home/.config/github-copilot"
    fi

    # ---------- git config ----------
    if [ -f "$HOME/.gitconfig" ] || [ -d "$HOME/.config/git" ]; then
        echo "devu:   copying git config"
        _devu_cp "$ws" "$cid" "$user" "$HOME/.gitconfig" "$home/.gitconfig"
        _devu_cp "$ws" "$cid" "$user" "$HOME/.config/git" "$home/.config/git"
        # host credential helpers (gcm, keyring) don't exist in the container
        devcontainer exec --workspace-folder "$ws" sh -c "
            command -v git >/dev/null 2>&1 || exit 0
            git config --global --unset-all credential.helper 2>/dev/null
            git config --global --unset-all credential.credentialStore 2>/dev/null
            git config --global --add safe.directory \"\$(pwd)\"
            true
        "
    fi

    # ---------- ssh keys (git auth) ----------
    if [ -d "$HOME/.ssh" ]; then
        echo "devu:   copying ssh keys"
        _devu_cp "$ws" "$cid" "$user" "$HOME/.ssh" "$home/.ssh"
        # no ssh agent in the container, so list every key as an identity candidate
        devcontainer exec --workspace-folder "$ws" sh -c "
            chmod 700 '$home/.ssh' 2>/dev/null
            chmod 600 '$home/.ssh'/* 2>/dev/null
            chmod 644 '$home/.ssh'/*.pub 2>/dev/null
            cfg='$home/.ssh/config'
            if ! grep -q 'devu identities' \"\$cfg\" 2>/dev/null; then
                {
                    printf '\n# devu identities\nHost *\n'
                    for pub in '$home/.ssh/'*.pub; do
                        key=\"\${pub%.pub}\"
                        [ -f \"\$key\" ] && printf '    IdentityFile %s\n' \"\$key\"
                    done
                } >> \"\$cfg\"
            fi
            chown '$user' \"\$cfg\" 2>/dev/null
            true
        "
    fi

    # ---------- https git credentials ----------
    # Pulls creds out of the host credential helper (gcm/keyring) and writes them
    # to a plaintext store in the container. Hosts with nothing stored are skipped.
    if command -v git >/dev/null 2>&1 && [ -n "$DEVU_GIT_CRED_HOSTS" ]; then
        local credtmp credhost filled
        credtmp="$(mktemp)"
        for credhost in $DEVU_GIT_CRED_HOSTS; do
            filled="$(printf 'protocol=https\nhost=%s\n\n' "$credhost" | \
                GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git credential fill 2>/dev/null)" || continue
            printf '%s\n\n' "$filled" | GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
                git -c "credential.helper=store --file=$credtmp" credential approve 2>/dev/null
        done
        if [ -s "$credtmp" ]; then
            echo "devu:   copying https git credentials"
            docker cp "$credtmp" "$cid:$home/.git-credentials" >/dev/null 2>&1 \
                || echo "devu:   warning: copy of .git-credentials failed — continuing"
            devcontainer exec --workspace-folder "$ws" sh -c "
                chown '$user' '$home/.git-credentials' 2>/dev/null
                chmod 600 '$home/.git-credentials' 2>/dev/null
                command -v git >/dev/null 2>&1 && git config --global credential.helper store
                true
            "
        fi
        rm -f "$credtmp"
    fi

    # ---------- system deps for Mason etc. (unzip, python3, pip, rg) ----------
    # Idempotent: only install names that resolve to missing binaries on PATH.
    local missing_bin=""
    for pkg in $DEVU_SYSTEM_DEPS; do
        local check
        case "$pkg" in
            python3-pip) check="command -v pip3" ;;
            # Debian images ship python3 without ensurepip, so probe the module
            # itself; Mason pip packages need it to create venvs
            python3-venv) check="python3 -c 'import ensurepip'" ;;
            ripgrep) check="command -v rg" ;;
            golang-go) check="command -v go" ;;
            bat) check="command -v bat || command -v batcat" ;;  # Debian ships bat as 'batcat'
            *) check="command -v $pkg" ;;
        esac
        devcontainer exec --workspace-folder "$ws" sh -c "{ $check ; } >/dev/null 2>&1" \
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
        # Install packages that are missing or at a different manifest version.
        local npm_globals need=""
        npm_globals="$(_devu_npm_globals)" || return 1
        for pkg in $npm_globals; do
            if ! devcontainer exec --workspace-folder "$ws" sh -c "
                export PATH='$home/.local/bin:\$PATH'
                npm list --global --depth=0 '$pkg' >/dev/null 2>&1
            "; then
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
