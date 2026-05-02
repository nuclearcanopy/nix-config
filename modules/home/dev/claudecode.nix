{ pkgs, lib, ... }:
{
  home.sessionVariables = {
    CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";

    DISABLE_TELEMETRY = "1";
    DISABLE_ERROR_REPORTING = "1";
    DISABLE_BUG_COMMAND = "1";
    CLAUDE_CODE_DISABLE_FEEDBACK_SURVEY = "1";
  };

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
    mcpServers = {
      nixos = {
        type = "stdio";
        command = "mcp-nixos";
      };
    };
    settings = {
      enabledPlugins = {
        "rust-analyzer-lsp@claude-plugins-official" = true;
      };
      gitCoAuthoredBy = false;
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
      command = "mcp-nixos"
      args = []

      [notice.model_migrations]
      "gpt-5.2" = "gpt-5.2-codex"
    '';
  };
}
