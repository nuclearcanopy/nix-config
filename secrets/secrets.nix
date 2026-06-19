let
  kuraokami = "age1zagw6v4ajuu4wrmjws7jxcmdp7763r7klq6ha9q7f7zc5hezuq7su8z00f";

  nidhoggr = kuraokami;

  desktop_systems = [ kuraokami nidhoggr ];
  kurai_only = [ kuraokami ];
in
{
  # Shared between kuraokami and nidhoggr
  "ssh-codeberg.age".publicKeys = desktop_systems;
  "user-password.age".publicKeys = desktop_systems;

  "nas-credentials.age".publicKeys = desktop_systems;

  # System identity (username). Decrypted by nix-commit/nix-upd wrappers
  # before each rebuild and written to /etc/identity.nix.
  "identity.age".publicKeys = desktop_systems;

  # homeserver (encrypted with kuraokami key; kuraokami manages homeserver secrets)
  "homeserver-user-password.age".publicKeys = kurai_only;
  "homeserver-navidrome-env.age".publicKeys = kurai_only;
  "homeserver-searxng-env.age".publicKeys = kurai_only;
  "homeserver-cloudflared-credentials.age".publicKeys = kurai_only;
  "homeserver-cloudflared-config.age".publicKeys = kurai_only;
  "homeserver-mscd-api-hash.age".publicKeys = kurai_only;
}
