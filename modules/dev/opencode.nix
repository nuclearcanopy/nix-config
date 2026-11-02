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
        model = "openai/gpt-6-luna";
        agent = {
          plan = {
            model = "openai/gpt-6.1-terra";
            reasoningEffort = "high";
          };
          build = {
            model = "openai/gpt-6-luna";
            reasoningEffort = "medium";
          };
        };
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
          { action = "shell"; resource = "*"; effect = "allow"; }
          { action = "shell"; resource = "sudo *"; effect = "deny"; }
          { action = "shell"; resource = "doas *"; effect = "deny"; }
          { action = "shell"; resource = "rm -r *"; effect = "deny"; }
          { action = "shell"; resource = "rm -fr *"; effect = "deny"; }
          { action = "shell"; resource = "rm --recursive *"; effect = "deny"; }
          { action = "shell"; resource = "mkfs *"; effect = "deny"; }
          { action = "shell"; resource = "wipefs *"; effect = "deny"; }
          { action = "shell"; resource = "dd *"; effect = "deny"; }
          { action = "shell"; resource = "shred *"; effect = "deny"; }
        ];
        instructions = [ "${config.home.homeDirectory}/.config/opencode/AGENTS.md" ];
      };
    };
}
