precmd() { echo }

setopt prompt_subst

fg_custom() { echo "%{\e[38;2;${1}m%}"; }
bg_custom() { echo "%{\e[48;2;${1}m%}"; }

INVIZ="12;12;12"
C3="18;18;18"
WHITE="180;180;180"

PROMPT=" $(fg_custom $INVIZ)$(bg_custom $C3)"
PROMPT+="$(fg_custom $WHITE)$(bg_custom $C3) %~ "
PROMPT+="$(fg_custom $C3)%k%k%f "
