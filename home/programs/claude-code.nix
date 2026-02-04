{ ... }:

{
  # no telemetry
  home.file.".config/Claude/settings.json".text = builtins.toJSON {
    "telemetry.telemetryLevel" = "off";
    "update.mode" = "none";
    "extensions.autoCheckUpdates" = false;
    "extensions.autoUpdate" = false;
  };
}
