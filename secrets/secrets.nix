let
  kuraokami = "age1zagw6v4ajuu4wrmjws7jxcmdp7763r7klq6ha9q7f7zc5hezuq7su8z00f";

  # nidhoggr: replace with actual public key after running `age-keygen` on the laptop.
  # If you use the SAME age key as kuraokami, set nidhoggr = kuraokami above instead.
  # To get the pubkey from an existing key: `age-keygen -y /etc/age/key.txt`
  nidhoggr = "age1PLACEHOLDER_REPLACE_WITH_NIDHOGGR_PUBKEY";

  desktop_systems = [ kuraokami nidhoggr ];
  kurai_only = [ kuraokami ];
in
{
  # Shared between kuraokami and nidhoggr
  "ssh-codeberg.age".publicKeys = desktop_systems;
  "user-password.age".publicKeys = desktop_systems;

  # kuraokami-only
  "nas-credentials.age".publicKeys = kurai_only;

  # homeserver (encrypted with kuraokami key — kuraokami manages homeserver secrets)
  "homeserver-user-password.age".publicKeys = kurai_only;
  "homeserver-navidrome-env.age".publicKeys = kurai_only;
  "homeserver-searxng-env.age".publicKeys = kurai_only;
  "homeserver-cloudflared-credentials.age".publicKeys = kurai_only;
  "homeserver-mscd-api-hash.age".publicKeys = kurai_only;
}
