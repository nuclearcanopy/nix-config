{
  # Git author identity is set here, separately from the system username.
  #
  # Kernel contributions use a different, real identity: intentionally public
  # on lore.kernel.org, but it must never be linked to this GitHub account.
  # includeIf swaps identity based on which
  # remote a repo talks to, so it applies automatically no matter where a
  # kernel.org clone lives, without ever touching this GitHub-linked repo.
  # The actual name/email lives in agenix, never as a literal string here.
  homeManager.modules.git = {
    programs.git = {
      enable = true;
      settings.user = {
        name = "nuclearcanopy";
        email = "git_l7a153rj3z@proton.me";
      };

      includes = [
        {
          condition = "hasconfig:remote.*.url:https://git.kernel.org/**";
          path = "/run/agenix/kernel-git-identity";
        }
        {
          condition = "hasconfig:remote.*.url:git://git.kernel.org/**";
          path = "/run/agenix/kernel-git-identity";
        }
      ];
    };
  };
}
