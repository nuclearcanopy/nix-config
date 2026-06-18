{
  homeManager.modules.neovim = { pkgs, unstable, ... }: {
    programs.nixvim = {
      enable = true;
      nixpkgs.source = pkgs.path;

      plugins.nvim-autopairs.enable = true;

      plugins.lsp = {
        enable = true;
        servers.typos_lsp = {
          enable = true;
          extraOptions.init_options.diagnosticSeverity = "Warning";
        };
      };

      extraPlugins = with pkgs.vimPlugins; [
        lackluster-nvim
        nvim-colorizer-lua
        oil-nvim
        nvim-web-devicons
        (nvim-treesitter.withAllGrammars)
        gitsigns-nvim
        unstable.vimPlugins.render-markdown-nvim
        (pkgs.vimUtils.buildVimPlugin {
          name = "high-str-nvim";
          src = pkgs.fetchFromGitHub {
            owner = "Pocco81";
            repo = "high-str.nvim";
            rev = "1cb5e030bb16df52c8428b53dc235466a4eb1d01";
            hash = "sha256-oyCCYgFckG3F9OKOeajLrLsby2Z+4zJ1RtwEzJo9JIk=";
          };
        })
      ];

      extraConfigLua = builtins.readFile ./neovim/init.lua;
    };
  };
}
