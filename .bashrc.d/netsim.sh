# netsim — simulate latency, jitter, and bandwidth on localhost via tc/netem.
# Source this from your rc file:  source ~/path/to/netsim.rc.sh
# Only one name is exposed: netsim
#
# Usage:
#   netsim set <latency_ms> <jitter_ms> <bandwidth_mbit> [iface]
#   netsim clear [iface]
#   netsim status [iface]

netsim() {
    local iface_default="lo"

    local usage="Usage:
  netsim set <latency_ms> <jitter_ms> <bandwidth_mbit> [iface]
  netsim clear [iface]
  netsim status [iface]

Examples:
  netsim set 20 5 80      # 20ms +/- 5ms jitter, 80 Mbit/s on lo
  netsim set 1 0 10000    # 1ms, no jitter, 10 Gbit/s on lo
  netsim clear            # remove all shaping from lo
  netsim status           # show current qdisc config

Note: loopback traffic passes through 'lo' twice, so latency/jitter
apply per direction — effective RTT is ~2x the value you set."

    if ! command -v tc >/dev/null 2>&1; then
        echo "netsim: 'tc' not found (sudo apt install iproute2)" >&2
        return 1
    fi

    # Run tc as root, transparently, whether or not we're already root.
    local sudo_cmd=""
    [[ $EUID -ne 0 ]] && sudo_cmd="sudo"

    local is_num='^[0-9]+([.][0-9]+)?$'

    local cmd="${1:-}"
    shift 2>/dev/null || true

    case "$cmd" in
        set)
            local latency="${1:-}" jitter="${2:-}" bw="${3:-}" iface="${4:-$iface_default}"

            [[ "$latency" =~ $is_num ]] || { echo "netsim: latency must be a number (ms)" >&2; return 1; }
            [[ "$jitter"  =~ $is_num ]] || { echo "netsim: jitter must be a number (ms)"  >&2; return 1; }
            [[ "$bw"      =~ $is_num ]] || { echo "netsim: bandwidth must be a number (Mbit/s)" >&2; return 1; }

            # Remove any existing root qdisc so repeated 'set' calls work.
            $sudo_cmd tc qdisc del dev "$iface" root 2>/dev/null

            local netem_args=(delay "${latency}ms")
            if awk "BEGIN{exit !($jitter > 0)}"; then
                netem_args+=("${jitter}ms" distribution normal)
            fi
            netem_args+=(rate "${bw}mbit")

            # Size the packet queue for the bandwidth-delay product;
            # netem's default (1000) silently drops at high rates.
            local limit
            limit=$(awk "BEGIN{printf \"%d\", ($bw*1000000*(($latency+$jitter)/1000))/(1500*8)*3 + 1000}")

            $sudo_cmd tc qdisc add dev "$iface" root netem "${netem_args[@]}" limit "$limit" || return 1

            local rtt
            rtt=$(awk "BEGIN{printf \"%g\", $latency*2}")
            echo "netsim: applied to $iface — ${latency}ms ±${jitter}ms @ ${bw}Mbit/s (loopback RTT ≈ ${rtt}ms, queue ${limit})"
            ;;

        clear)
            local iface="${1:-$iface_default}"
            if $sudo_cmd tc qdisc del dev "$iface" root 2>/dev/null; then
                echo "netsim: cleared shaping on $iface"
            else
                echo "netsim: nothing to clear on $iface"
            fi
            ;;

        status)
            local iface="${1:-$iface_default}"
            tc -s qdisc show dev "$iface"
            ;;

        *)
            echo "$usage" >&2
            return 1
            ;;
    esac
}

export -f netsim
