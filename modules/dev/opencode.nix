{
  homeManager.modules.opencode = { config, lib, pkgs, ... }:
    let
      jsonFormat = pkgs.formats.json { };
      instructions = import ./agent-instructions.data.nix;
      instructionsFile = pkgs.writeText "agent-instructions.md" instructions;
    in
    {
      # opencode still loads the obsolete config.json before the managed
      # opencode.json; remove stale pre-migration settings after HM links the
      # generation so the legacy filename remains absent.
      home.activation.removeLegacyOpencodeConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
        legacy="${config.home.homeDirectory}/.config/opencode/config.json"
        if [ -e "$legacy" ] || [ -L "$legacy" ]; then
          $DRY_RUN_CMD rm "$legacy"
        fi
      '';
      home.file.".config/opencode/AGENTS.md".source = instructionsFile;
      home.file.".config/opencode/opencode.json".source = jsonFormat.generate "opencode.json" {
        "$schema" = "https://opencode.ai/config.json";
        model = "openai/gpt-5.6-luna";
        experimental.todo = true;
        permissions = [
          { action = "*"; resource = "*"; effect = "ask"; }
          { action = "external_directory"; resource = "*"; effect = "ask"; }
          { action = "read"; resource = "*"; effect = "allow"; }
          { action = "edit"; resource = "*"; effect = "allow"; }
          { action = "glob"; resource = "*"; effect = "allow"; }
          { action = "grep"; resource = "*"; effect = "allow"; }
          { action = "skill"; resource = "*"; effect = "allow"; }
          { action = "question"; resource = "*"; effect = "allow"; }
          { action = "webfetch"; resource = "*"; effect = "allow"; }
          { action = "websearch"; resource = "*"; effect = "allow"; }
          { action = "subagent"; resource = "*"; effect = "allow"; }
          { action = "shell"; resource = "*"; effect = "ask"; }
          { action = "shell"; resource = "pwd"; effect = "allow"; }
          { action = "shell"; resource = "ls"; effect = "allow"; }
          { action = "shell"; resource = "ls *"; effect = "allow"; }
          { action = "shell"; resource = "git status"; effect = "allow"; }
          { action = "shell"; resource = "git status *"; effect = "allow"; }
          { action = "shell"; resource = "git diff"; effect = "allow"; }
          { action = "shell"; resource = "git diff *"; effect = "allow"; }
          { action = "shell"; resource = "git log"; effect = "allow"; }
          { action = "shell"; resource = "git log *"; effect = "allow"; }
          { action = "shell"; resource = "git show"; effect = "allow"; }
          { action = "shell"; resource = "git show *"; effect = "allow"; }
          { action = "shell"; resource = "git add"; effect = "allow"; }
          { action = "shell"; resource = "git add *"; effect = "allow"; }
          { action = "shell"; resource = "git commit"; effect = "allow"; }
          { action = "shell"; resource = "git commit *"; effect = "allow"; }
          { action = "shell"; resource = "git push"; effect = "allow"; }
          { action = "shell"; resource = "git push *"; effect = "allow"; }
          { action = "shell"; resource = "nix eval"; effect = "allow"; }
          { action = "shell"; resource = "nix eval *"; effect = "allow"; }
          { action = "shell"; resource = "nix build"; effect = "allow"; }
          { action = "shell"; resource = "nix build *"; effect = "allow"; }
          { action = "shell"; resource = "nix path-info"; effect = "allow"; }
          { action = "shell"; resource = "nix path-info *"; effect = "allow"; }
          { action = "shell"; resource = "rm"; effect = "allow"; }
          { action = "shell"; resource = "rm *"; effect = "allow"; }
        ];
        instructions = [ "${config.home.homeDirectory}/.config/opencode/AGENTS.md" ];
      };
    };
}
