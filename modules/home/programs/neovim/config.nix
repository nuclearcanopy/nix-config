{ pkgs, unstable, ... }:

{
  programs.nixvim = {
    enable = true;

    # Typo detection for code
    plugins.nvim-autopairs.enable = true;

    plugins.lsp = {
      enable = true;
      servers.typos_lsp = {
        enable = true;
        extraOptions.init_options = {
          diagnosticSeverity = "Warning";
        };
      };
    };

    extraPlugins = with pkgs.vimPlugins; [
      lackluster-nvim
      nvim-colorizer-lua
      neo-tree-nvim
      plenary-nvim
      nvim-web-devicons
      nui-nvim
      (nvim-treesitter.withAllGrammars)
      gitsigns-nvim
      unstable.vimPlugins.render-markdown-nvim
    ];

    extraConfigLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = "\\"
      vim.opt.termguicolors = true

      vim.api.nvim_create_autocmd("VimLeave", {
        callback = function()
          vim.opt.guicursor = ""
          io.write("\027[6 q")
        end,
      })

      vim.api.nvim_set_keymap(
        "n",
        "<F5>",
        ":w<CR>:vsp | terminal g++ -std=c++17 % -o /tmp/%:t:r && /tmp/%:t:r<CR>",
        { noremap = true }
      )

      require("lackluster").setup({
        tweak_color = {
          gray1 = "#1a1a1a",
          gray2 = "#2a2a2a",
          gray3 = "#494949",
          gray4 = "#5A5A5A",
          gray5 = "#7A7A7A",
          gray6 = "#AAAAAA",
          gray7 = "#CCCCCC",
          gray8 = "#DDDDDD",
          gray9 = "#f0f0f0",
          luster = "#ffffff",
          lack = "#1a1a1a",
          error = "#a04a4a",
        },
        tweak_syntax = {
          string = "#7A7A7A",
        },
        tweak_background = {
          normal = "#000000",
        },
      })
      vim.cmd("colorscheme lackluster")

      -- Make emphasis visible even when the terminal can't do "real" bold/italic fonts.
      -- (Still sets bold/italic attrs when available.)
      vim.api.nvim_set_hl(0, "@markup.strong", { fg = "#f0f0f0", bg = "#1a1a1a", bold = true })
      vim.api.nvim_set_hl(0, "@markup.emphasis", { fg = "#c0dfdd", bg = "#0a0a0a", italic = true, underline = true })
      vim.api.nvim_set_hl(0, "@markup.strong.emphasis", { fg = "#c0dfdd", bg = "#1a1a1a", bold = true, italic = true, underline = true })
      vim.api.nvim_set_hl(0, "markdownBold", { fg = "#f0f0f0", bg = "#1a1a1a", bold = true })
      vim.api.nvim_set_hl(0, "markdownItalic", { fg = "#c0dfdd", bg = "#0a0a0a", italic = true, underline = true })
      vim.api.nvim_set_hl(0, "markdownBoldItalic", { fg = "#c0dfdd", bg = "#1a1a1a", bold = true, italic = true, underline = true })
      vim.api.nvim_set_hl(0, "mkdBold", { fg = "#f0f0f0", bg = "#1a1a1a", bold = true })
      vim.api.nvim_set_hl(0, "mkdItalic", { fg = "#c0dfdd", bg = "#0a0a0a", italic = true, underline = true })
      vim.api.nvim_set_hl(0, "mkdBoldItalic", { fg = "#c0dfdd", bg = "#1a1a1a", bold = true, italic = true, underline = true })

      require("colorizer").setup({
        filetypes = { "*" },
        user_default_options = {
          RGB = true,
          RRGGBB = true,
          names = true,
          RRGGBBAA = true,
          rgb_fn = true,
          hsl_fn = true,
          css = true,
          css_fn = true,
        },
        buftypes = {},
      })

      local function smart_open(node)
        if not node then return end
        local ext = node.name:match("^.+(%..+)$")
        if ext then
          ext = ext:lower()
          local video_exts = {".mp4", ".mkv", ".mov", ".webm", ".avi"}
          local image_exts = {".png", ".jpg", ".jpeg", ".gif", ".bmp", ".webp"}
          if vim.tbl_contains(video_exts, ext) then
            vim.fn.jobstart({"mpv", node.path}, {detach = true})
          elseif vim.tbl_contains(image_exts, ext) then
            vim.fn.jobstart({"firefox", node.path}, {detach = true})
          else
            vim.fn.jobstart({"xdg-open", node.path}, {detach = true})
          end
        end
      end

      local function is_in_home(path)
        local home = vim.fn.expand("~")
        return path:sub(1, #home) == home
      end

      require("neo-tree").setup({
        filesystem = {
          filtered_items = { hide_dotfiles = false, hide_gitignored = false },
          follow_current_file = { enabled = true },
          use_default_mappings = true,

          commands = {
            delete = function(state)
              local node = state.tree:get_node()
              if not node then return end
              local path = node.path
              if not is_in_home(path) then
                vim.ui.input({prompt = "Delete permanently? (y/N): "}, function(input)
                  if input ~= "y" then
                    vim.notify("Cancelled deletion")
                    return
                  end
                  local ok = vim.fn.delete(path, "rf")
                  if ok == 0 then
                    vim.notify("Deleted: " .. path)
                    state.commands.refresh(state)
                  else
                    vim.notify("Failed to delete: " .. path, vim.log.levels.ERROR)
                  end
                end)
                return
              end
              vim.ui.input({prompt = "Move to trash? (y/N): "}, function(input)
                if input ~= "y" then
                  vim.notify("Cancelled deletion")
                  return
                end
                local ok = os.execute("trash-put " .. vim.fn.shellescape(path))
                if ok then
                  vim.notify("Moved to trash: " .. path)
                  state.commands.refresh(state)
                else
                  vim.notify("Failed to move to trash: " .. path, vim.log.levels.ERROR)
                end
              end)
            end,
          },
        },
        window = {
          mappings = {
            ["q"] = function(state)
              local node = state.tree:get_node()
              smart_open(node)
            end,
            ["y"] = function(state)
              local node = state.tree:get_node()
              if not node then return end
              vim.fn.setreg("+", node.path)
              vim.notify("Copied absolute path: " .. node.path)
            end,
            ["Y"] = function(state)
              local node = state.tree:get_node()
              if not node then return end
              vim.fn.setreg("+", node.name)
              vim.notify("Copied filename: " .. node.name)
            end,
            ["d"] = function(state)
              if state.commands and state.commands.delete then
                state.commands.delete(state)
              end
            end,
          },
        },
      })

      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.clipboard = "unnamedplus"
      vim.opt.number = true

      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "markdown" },
        callback = function()
          vim.opt_local.conceallevel = 2
          vim.opt_local.concealcursor = "nc"
        end,
      })

      require("nvim-treesitter.configs").setup({
        highlight = { enable = true },
        indent = { enable = true },
      })

      local ok_render_markdown, render_markdown = pcall(require, "render-markdown")
      if ok_render_markdown then
        render_markdown.setup({})
      end

      require("gitsigns").setup({
        signs = {
          add          = { text = "+" },
          change       = { text = "~" },
          delete       = { text = "_" },
          topdelete    = { text = "‾" },
          changedelete = { text = "~" },
        },
        current_line_blame = false,  -- toggle with :Gitsigns toggle_current_line_blame
        on_attach = function(bufnr)
          local gs = package.loaded.gitsigns
          local function map(mode, l, r, opts)
            opts = opts or {}
            opts.buffer = bufnr
            vim.keymap.set(mode, l, r, opts)
          end
          -- navigation
          map("n", "]c", function() gs.nav_hunk("next") end)
          map("n", "[c", function() gs.nav_hunk("prev") end)
          -- actions
          map("n", "<leader>hs", gs.stage_hunk)
          map("n", "<leader>hr", gs.reset_hunk)
          map("n", "<leader>hS", gs.stage_buffer)
          map("n", "<leader>hu", gs.undo_stage_hunk)
          map("n", "<leader>hp", gs.preview_hunk)
          map("n", "<leader>hb", function() gs.blame_line({ full = true }) end)
          map("n", "<leader>hd", gs.diffthis)
        end
      })
    '';
  };
}
