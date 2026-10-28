unalias cfs 2>/dev/null

function cfs() {
  if [ "$#" -eq 0 ]; then
    cd "$CFS_REPO" || return
    return
  fi

  local cfs_dir
  local cfs_data_dir
  local cfs_requirements
  local cfs_requirements_hash
  local cfs_venv_dir
  local cfs_venv_marker

  cfs_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.tools/camberfs" && pwd) || return
  cfs_data_dir=${XDG_DATA_HOME:-$HOME/.local/share}
  cfs_requirements="$cfs_dir/requirements.txt"
  cfs_requirements_hash=$(cksum "$cfs_requirements" | awk '{print $1 "-" $2}')
  cfs_venv_dir=${CFS_VENV:-$cfs_data_dir/cfs/venv}
  cfs_venv_marker="$cfs_venv_dir/.cfs-uv-$cfs_requirements_hash"

  if [ ! -x "$cfs_venv_dir/bin/python" ] || [ ! -f "$cfs_venv_marker" ]; then
    if ! command -v uv >/dev/null 2>&1; then
      echo "cfs: uv is required; install it from https://docs.astral.sh/uv/" >&2
      return 1
    fi
    echo "cfs: preparing $cfs_venv_dir" >&2
    if [ ! -x "$cfs_venv_dir/bin/python" ]; then
      uv venv --quiet --no-project "$cfs_venv_dir" || return
    fi
    uv pip install --quiet --python "$cfs_venv_dir/bin/python" -r "$cfs_requirements" || return
    touch "$cfs_venv_marker"
  fi

  "$cfs_venv_dir/bin/python" "$cfs_dir/camberfs.py" "$@"
}

alias cfsrepo='cd "$CFS_REPO"'
alias cfsp='cfs pods'
alias cfscsi='cfs csi'
alias cfslg='cfs logs'
alias cfslgf='cfs logs -f'
alias cfsmntlg='cfs mount logs'
alias cfsex='cfs exec'
alias cfsgdb='cfs gdb'
alias cfscsigdb='cfs csi gdb'
alias cfscurl='cfs curl'
alias cfsdb='cfs db'
alias cfsvk='cfs valkey'

function _cfs_completion() {
  local commands="camberfs server csi mount db valkey ui status pods lb storage top events context aliases alias oai openapi logs exec gdb delete curl curl-status curl-stop help"
  local target_actions="pods logs exec gdb delete"
  local cur=${COMP_WORDS[COMP_CWORD]}
  local prev=${COMP_WORDS[COMP_CWORD-1]}
  if [ "$COMP_CWORD" -eq 1 ]; then
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    return
  fi

  case "${COMP_WORDS[1]}" in
    camberfs|server|s|csi|c|mount|mnt|m)
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=($(compgen -W "$target_actions" -- "$cur"))
        return
      fi
      if [ "$COMP_CWORD" -eq 3 ] && [[ "${COMP_WORDS[2]}" =~ ^(logs|log|lg|l|exec|ex|e|gdb|g|delete|del|d|rm)$ ]]; then
        mapfile -t COMPREPLY < <(cfs __complete pods "${COMP_WORDS[1]}" "$cur" 2>/dev/null)
        return
      fi
      ;;
    db|valkey|vk|v)
      if [ "$COMP_CWORD" -eq 2 ]; then
        COMPREPLY=($(compgen -W "$target_actions shell" -- "$cur"))
        return
      fi
      if [ "$COMP_CWORD" -eq 3 ] && [[ "${COMP_WORDS[2]}" =~ ^(logs|log|lg|l|exec|ex|e|shell|sh|gdb|g|delete|del|d|rm)$ ]]; then
        mapfile -t COMPREPLY < <(cfs __complete pods "${COMP_WORDS[1]}" "$cur" 2>/dev/null)
        return
      fi
      ;;
    logs|log|lg|l|exec|ex|e|gdb|g|delete|del|d|rm)
      if [ "$COMP_CWORD" -eq 2 ]; then
        mapfile -t COMPREPLY < <(cfs __complete pods server "$cur" 2>/dev/null)
        return
      fi
      ;;
  esac

  case "${COMP_WORDS[1]}" in
    curl)
      if [ "$COMP_CWORD" -eq 2 ]; then
        mapfile -t COMPREPLY < <(cfs __complete routes "$cur" 2>/dev/null)
      elif [ "$prev" = "-X" ] || [ "$prev" = "--request" ]; then
        COMPREPLY=($(compgen -W "$(cfs __complete methods "${COMP_WORDS[2]}" 2>/dev/null)" -- "$cur"))
      fi
      ;;
    oai|openapi)
      if [ "$COMP_CWORD" -eq 2 ]; then
        mapfile -t COMPREPLY < <(cfs __complete routes "$cur" 2>/dev/null)
      elif [ "$COMP_CWORD" -eq 3 ]; then
        COMPREPLY=($(compgen -W "$(cfs __complete methods "${COMP_WORDS[2]}" 2>/dev/null)" -- "$cur"))
      fi
      ;;
  esac
}

complete -F _cfs_completion cfs
