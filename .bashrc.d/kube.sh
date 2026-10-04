if command -v kubectl >/dev/null 2>&1; then
  if ! shopt -oq posix; then
    for f in /usr/share/bash-completion/bash_completion /etc/bash_completion; do
      [ -r "$f" ] && source "$f" && break
    done
  fi

  if [ -r /usr/share/bash-completion/completions/_kubectl ]; then
    source /usr/share/bash-completion/completions/_kubectl
  else
    source <(kubectl completion bash)
  fi

  alias k=kubectl
  complete -o default -F __start_kubectl k 2>/dev/null || complete -o default -F _kubectl k
fi

# Extra Aliases

## Get allocatable gpus by node
alias kginv='kubectl get nodes -o json | jq -r '"'"'
  .items[]
  | select(.status.allocatable["nvidia.com/gpu"] != null)
  | [
      .metadata.name,
      (.metadata.labels["nvidia.com/gpu.product"] // "unknown"),
      (.status.capacity["nvidia.com/gpu"] // "0"),
      (.status.allocatable["nvidia.com/gpu"] // "0")
    ]
  | @tsv
'"'"' | column -t'
