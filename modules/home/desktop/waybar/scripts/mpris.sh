#!/usr/bin/env bash

status=$(playerctl status 2>/dev/null)
if [[ -z "$status" ]]; then
  exit 0
fi

artist=$(playerctl metadata --format '{{artist}}' 2>/dev/null)

if [[ -n "$artist" ]]; then
  printf "[%s] %s\n" "$status" "$artist" | tr '[:lower:]' '[:upper:]' | cut -c 1-50
else
  printf "[%s]\n" "$status" | tr '[:lower:]' '[:upper:]'
fi
