{
  homeManager.modules.opencode = { config, pkgs, ... }:
    let
      jsonFormat = pkgs.formats.json { };
    in
    {
      home.file.".config/opencode/opencode.json".source = jsonFormat.generate "opencode.json" {
        "$schema" = "https://opencode.ai/config.json";
        shell = "${pkgs.zsh}/bin/zsh";
        share = "disabled";
        snapshots = true;
        instructions = [ "${config.home.homeDirectory}/.claude/CLAUDE.md" ];
      };
    };
}
