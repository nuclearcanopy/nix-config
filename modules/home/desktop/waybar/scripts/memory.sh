#!/usr/bin/env bash
total=0; avail=0
while read -r k v _; do
  case "$k" in
    MemTotal:)     total=$v ;;
    MemAvailable:) avail=$v; break ;;
  esac
done < /proc/meminfo
used_mb=$(( (total - avail) / 1024 ))
printf 'MEM %02d.%dG\n' $((used_mb / 1024)) $(( (used_mb % 1024) * 10 / 1024 ))
