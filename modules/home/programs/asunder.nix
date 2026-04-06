{ pkgs, username, ... }:

{
  home.file.".config/asunder/asunder".text =
''
/dev/cdrom
/home/${username}/CD
0
1
%N - %T
%A - %L
%L
0
0
0
1
1
10
6
8
unused
1118
672
0
1
0
10.0.0.1
8080
0
1
1
3
0
gnudb.gnudb.org
8880
0
2
unused
unused
0
2
0
0
0
9
1
0
0
2
0
10
/
0

'';
}
