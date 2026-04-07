let
  kuraokami = "age1zagw6v4ajuu4wrmjws7jxcmdp7763r7klq6ha9q7f7zc5hezuq7su8z00f";

  systems = [ kuraokami ];
in
{
  "ssh-codeberg.age".publicKeys = systems;

  "nas-credentials.age".publicKeys = systems;

  "user-password.age".publicKeys = systems;

  "homeserver-user-password.age".publicKeys = systems;
  "homeserver-navidrome-env.age".publicKeys = systems;
  "homeserver-searxng-env.age".publicKeys = systems;
  "homeserver-cloudflared-credentials.age".publicKeys = systems;
  "homeserver-mscd-api-hash.age".publicKeys = systems;
}
