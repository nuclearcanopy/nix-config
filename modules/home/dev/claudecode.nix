{ pkgs, lib, ... }:
{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";

    DISABLE_TELEMETRY = "1";
    DISABLE_ERROR_REPORTING = "1";
    DISABLE_BUG_COMMAND = "1";
    CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
  };

  home.file.".claude/settings.json" = {
    force = true;
    text = builtins.toJSON {
      enabledPlugins = {
        "rust-analyzer-lsp@claude-plugins-official" = true;
      };
      mcpServers = {
        nixos = {
          command = "nix";
          args = [ "run" "github:utensils/mcp-nixos" "--" ];
        };
      };
    };
  };

  home.file.".codex/config.toml" = {
    force = true;
    text = ''
      analytics.enabled = false
      history.persistence = "none"
      history.max_bytes = 1048576
      log_dir = "/tmp/codex-log"
      model = "gpt-5.2"
      model_reasoning_effort = "medium"

      [otel]
      exporter = "none"
      metrics_exporter = "none"
      trace_exporter = "none"
      log_user_prompt = false

      [mcp_servers.nixos]
      url = "https://mcp-nixos.io/"

      [notice.model_migrations]
      "gpt-5.2" = "gpt-5.2-codex"
    '';
  };
}
