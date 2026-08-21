vim.g.mapleader = " "
vim.g.maplocalleader = "\\"
vim.opt.termguicolors = true

vim.api.nvim_create_autocmd("VimLeave", {
  callback = function()
    vim.opt.guicursor = ""
    io.write("\27[6 q")
  end,
})

-- <F5>: save and run the current file, dispatching on filetype.
local function run_file()
  vim.cmd("w")
  local ft = vim.bo.filetype
  local cmd
  if ft == "python" then
    cmd = "python3 %"
  elseif ft == "cpp" then
    cmd = "g++ -std=c++17 % -o /tmp/%:t:r && /tmp/%:t:r"
  else
    vim.notify("no run command for filetype: " .. ft, vim.log.levels.WARN)
    return
  end
  vim.cmd("vsp | terminal " .. cmd)
end
vim.keymap.set("n", "<F5>", run_file, { noremap = true })

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

local mpv_exts = {
  [".mp4"] = true, [".mkv"] = true, [".mov"] = true, [".webm"] = true,
  [".avi"] = true, [".flv"] = true, [".m4v"] = true, [".wmv"] = true,
  [".mpg"] = true, [".mpeg"] = true, [".ts"] = true, [".m2ts"] = true,
  [".mp3"] = true, [".flac"] = true, [".wav"] = true, [".ogg"] = true,
  [".opus"] = true, [".m4a"] = true, [".aac"] = true, [".wma"] = true,
}
local browser_exts = {
  [".png"] = true, [".jpg"] = true, [".jpeg"] = true, [".gif"] = true,
  [".bmp"] = true, [".webp"] = true, [".svg"] = true, [".avif"] = true,
  [".pdf"] = true, [".html"] = true, [".htm"] = true, [".xhtml"] = true,
  [".epub"] = true,
}

local function oil_smart_open()
  local oil = require("oil")
  local entry = oil.get_cursor_entry()
  local dir = oil.get_current_dir()
  if not entry or not dir then return end
  if entry.type == "directory" then
    require("oil.actions").select.callback()
    return
  end
  local path = dir .. entry.name
  local ext = entry.name:match("^.+(%..+)$")
  local external_cmd = nil
  if ext then
    ext = ext:lower()
    if mpv_exts[ext] then
      external_cmd = { "mpv", path }
    elseif browser_exts[ext] then
      external_cmd = { "firefox", path }
    end
  end
  if not external_cmd then
    require("oil.actions").select.callback()
    return
  end
  vim.ui.select(
    { "open externally", "edit in nvim" },
    { prompt = "open " .. entry.name .. ":" },
    function(choice)
      if choice == "open externally" then
        vim.fn.jobstart(external_cmd, { detach = true })
      elseif choice == "edit in nvim" then
        require("oil.actions").select.callback()
      end
    end
  )
end

require("oil").setup({
  delete_to_trash = true,
  view_options = {
    show_hidden = true,
  },
  keymaps = {
    ["<CR>"] = { callback = oil_smart_open, desc = "Open (mpv/firefox for media, nvim otherwise)" },
    ["q"] = { callback = oil_smart_open, desc = "Open with external app" },
    ["y"] = {
      callback = function()
        local oil = require("oil")
        local entry = oil.get_cursor_entry()
        local dir = oil.get_current_dir()
        if not entry or not dir then return end
        local path = dir .. entry.name
        vim.fn.setreg("+", path)
        vim.notify("Copied absolute path: " .. path)
      end,
      desc = "Copy absolute path",
    },
    ["Y"] = {
      callback = function()
        local entry = require("oil").get_cursor_entry()
        if not entry then return end
        vim.fn.setreg("+", entry.name)
        vim.notify("Copied filename: " .. entry.name)
      end,
      desc = "Copy filename",
    },
  },
})
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory in oil" })

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

vim.api.nvim_create_autocmd("FileType", {
  callback = function(args)
    if pcall(vim.treesitter.start, args.buf) then
      vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end,
})

local ok_render_markdown, render_markdown = pcall(require, "render-markdown")
if ok_render_markdown then
  render_markdown.setup({})
end

require("high-str").setup({
  verbosity = 0,
  saving_path = vim.fn.expand("~/.local/share/nvim/highstr/"),
  highlight_colors = {
    color_1 = { "#c0392b", "smart" }, -- red
    color_2 = { "#1e8449", "smart" }, -- green
    color_3 = { "#1a5276", "smart" }, -- blue
    color_4 = { "#117a65", "smart" }, -- cyan
    color_5 = { "#8e44ad", "smart" }, -- magenta
    color_6 = { "#ffeb3b", "smart" }, -- yellow
    color_7 = { "#d5d8dc", "smart" }, -- white
  },
})
-- visual mode: <leader>1-7 to highlight, <leader>- to remove
for i = 1, 7 do
  vim.api.nvim_set_keymap("v", "<leader>" .. i, ":<c-u>HSHighlight " .. i .. "<CR>", { noremap = true, silent = true })
end
vim.api.nvim_set_keymap("v", "<leader>-", ":<c-u>HSRmHighlight<CR>", { noremap = true, silent = true })

require("gitsigns").setup({
  signs = {
    add          = { text = "+" },
    change       = { text = "~" },
    delete       = { text = "_" },
    topdelete    = { text = "‾" },
    changedelete = { text = "~" },
  },
  current_line_blame = false, -- toggle with :Gitsigns toggle_current_line_blame
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
  end,
})
