{ pkgs, ... }:

{
  programs.nixvim = {
    enable = true;

    extraPlugins = with pkgs.vimPlugins; [
      lackluster-nvim
      nvim-colorizer-lua
      neo-tree-nvim
      plenary-nvim
      nvim-web-devicons
      nui-nvim
    ];

    extraConfigLua = ''
      vim.g.mapleader = " "
      vim.g.maplocalleader = "\\"

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
          lack = "#000000",
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
    '';
  };
}
