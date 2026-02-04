{ ... }:

{
  # privacy environment variables
  home.sessionVariables = {
    # disable telemetry
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    POWERSHELL_TELEMETRY_OPTOUT = "1";
    AZURE_CORE_COLLECT_TELEMETRY = "0";
    DO_NOT_TRACK = "1";
    HOMEBREW_NO_ANALYTICS = "1";
    NEXT_TELEMETRY_DISABLED = "1";
    GATSBY_TELEMETRY_DISABLED = "1";
    HASURA_GRAPHQL_ENABLE_TELEMETRY = "false";
    SAM_CLI_TELEMETRY = "0";
    STRIPE_CLI_TELEMETRY_OPTOUT = "1";
  };
}
