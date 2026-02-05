-- Bootstrap lazy.nvim
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = "https://github.com/folke/lazy.nvim.git"
  local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
      { out, "WarningMsg" },
      { "\nPress any key to exit..." },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Make sure to setup mapleader and maplocalleader before
-- loading lazy.nvim so that mappings are correct.
-- This is also a good place to setup other settings (vim.opt)
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    vim.opt.guicursor = ""
    io.write("\027[6 q")
  end,
})

-- GCC 

vim.api.nvim_set_keymap(
  "n",
  "<F5>",
  ":w<CR>:vsp | terminal g++ -std=c++17 % -o /tmp/%:t:r && /tmp/%:t:r<CR>",
  { noremap = true }
)


require("lazy").setup({
  spec = {


    {
      "slugbyte/lackluster.nvim",
      lazy = false,
      priority = 1000,
      config = function()
        require("lackluster").setup({
          tweak_color = {
            gray1 = "#1C1C1C",
            gray2 = "#2F2F2F",
            gray3 = "#494949",
            gray4 = "#5A5A5A",
            gray5 = "#7A7A7A",
            gray6 = "#AAAAAA",
            gray7 = "#CCCCCC",
            gray8 = "#DDDDDD",
            gray9 = "#f0f0f0",
            luster = "#ffffff",
            lack = "#2c2c2c",
            error = "#a04a4a",
          },
          tweak_background = {
            normal = "#0c0c0c",
          },
        })
        vim.cmd("colorscheme lackluster")
      end,
    },

    {
      "NvChad/nvim-colorizer.lua",
      config = function()
        require("colorizer").setup({
          filetypes = { "*" }, -- Enable for all filetypes
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
      end,
    },

  {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  lazy = false,
  config = function()
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
          vim.fn.jobstart({"librewolf", node.path}, {detach = true})
        else
          vim.fn.jobstart({"xdg-open", node.path}, {detach = true})
        end
      end
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
  end, -- closes config function
},

  }, -- <== closes spec table

  checker = { 
    enabled = true,
    notify = false,
  },
})


-- Setup lazy.nvim
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true

-- Setup clipboard
vim.opt.clipboard = "unnamedplus"
vim.opt.number = true

