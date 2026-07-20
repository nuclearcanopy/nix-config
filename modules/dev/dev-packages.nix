{
  homeManager.modules.dev-packages = { pkgs, ... }: {
    home.packages = with pkgs; [
      # programming
      lazygit
      gh
      age
      gnumake
      gcc
      (python313.withPackages (ps: [ ps.pip ]))
      rustc
      cargo
      rust-analyzer
      clippy
      rustfmt

      # ai slop tools
      # mcp-nixos  # temporarily out: pulls cfn-lint whose tests fail upstream
      codex

      # cybersec stuff
      # NOTE: wireshark is enabled at the system level via programs.wireshark
      # for dumpcap capabilities; not listed here.
      ghidra
      metasploit
      tcpdump
      ffuf
      nmap
      netcat-gnu
      gobuster
      nikto
      binwalk
      binutils
      masscan
      wfuzz
      cyberchef
      john
      hashcat
      hash-identifier
      zsteg
      scalpel
      hexedit
      gnupg
      burpsuite
      exploitdb
    ];
  };
}
