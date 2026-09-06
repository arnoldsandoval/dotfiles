#!/usr/bin/env bash
# Network speed check — pure curl against Cloudflare's speed endpoints,
# so it behaves identically on every Mac and Linux box with zero installs.
# curl reports bytes/sec itself (%{speed_download}/%{speed_upload}); we
# just pick sane payload sizes and do the Mbps arithmetic.

speed_test() {
  local quick=${1:-}
  local down_bytes=100000000 up_bytes=25000000
  [[ $quick == --quick || $quick == -q ]] && down_bytes=25000000 up_bytes=10000000

  command -v curl >/dev/null || { echo "speed: needs curl" >&2; return 1; }

  # Latency: three tiny requests, first-byte time, best-of (TCP warmth varies).
  local lat best=999999
  for _ in 1 2 3; do
    lat=$(curl -s -o /dev/null -w '%{time_starttransfer}' --max-time 10 \
      'https://speed.cloudflare.com/__down?bytes=0' 2>/dev/null) || continue
    lat=$(awk -v t="$lat" 'BEGIN{printf "%d", t*1000}')
    (( lat < best )) && best=$lat
  done
  [[ $best == 999999 ]] && { echo "speed: cannot reach speed.cloudflare.com" >&2; return 1; }

  printf 'latency: %s ms\n' "$best"

  local dl
  dl=$(curl -s -o /dev/null -w '%{speed_download}' --max-time 90 \
    "https://speed.cloudflare.com/__down?bytes=${down_bytes}") || dl=0
  awk -v b="$dl" 'BEGIN{printf "down:    %.1f Mbps\n", b*8/1000000}'

  # Upload payload: random bytes so nothing en route can cheat with compression.
  local tmp; tmp=$(mktemp)
  head -c "$up_bytes" /dev/urandom > "$tmp"
  local ul
  ul=$(curl -s -o /dev/null -w '%{speed_upload}' --max-time 90 \
    -X POST --data-binary @"$tmp" 'https://speed.cloudflare.com/__up') || ul=0
  rm -f "$tmp"
  awk -v b="$ul" 'BEGIN{printf "up:      %.1f Mbps\n", b*8/1000000}'
}
