#!/usr/bin/env bash
printf -v t '%(%a %H:%M)T' -1
echo "${t^^}"
