# agenix secrets configuration
# This file maps which keys can decrypt which secrets

let
  # Host key - can decrypt all secrets at boot
  kuraokami = "age1zagw6v4ajuu4wrmjws7jxcmdp7763r7klq6ha9q7f7zc5hezuq7su8z00f";

  # All systems that can decrypt
  systems = [ kuraokami ];
in
{
  # SSH keys
  "ssh-codeberg.age".publicKeys = systems;

  # NAS credentials
  "nas-credentials.age".publicKeys = systems;

  # User password hash
  "user-password.age".publicKeys = systems;
}
