-- Interim treesitter parser installer for the trial config (see README).
--
-- nvim-treesitter's own installer needs the tree-sitter CLI, which Nix does
-- not supply yet. This script does the same job with only curl, tar and cc:
-- it reads the parser revisions pinned by the nvim-treesitter checkout,
-- compiles each grammar into stdpath("data")/site/parser, and links the
-- matching queries into stdpath("data")/site/queries.
--
-- Runs automatically as the lazy.nvim build step of lua/plugins/syntax.lua.
-- Manual run: NVIM_APPNAME=nvim-next nvim -l scripts/build-parsers.lua
local langs = {
  "bash",
  "css",
  "html",
  "javascript",
  "json",
  "lua",
  "markdown",
  "markdown_inline",
  "nix",
  "python",
  "rust",
  "toml",
  "tsx",
  "typescript",
  "yaml",
}

local data = vim.fn.stdpath("data")
local checkout = data .. "/lazy/nvim-treesitter"
local site = data .. "/site"
local work = vim.fn.stdpath("cache") .. "/parser-build"
local parsers = dofile(checkout .. "/lua/nvim-treesitter/parsers.lua")

local function run(cmd)
  local res = vim.system(cmd, { text = true }):wait()
  if res.code ~= 0 then
    error(table.concat(cmd, " ") .. "\n" .. (res.stderr or ""))
  end
end

local function link_queries(lang)
  local src = checkout .. "/runtime/queries/" .. lang
  local dst = site .. "/queries/" .. lang
  if vim.uv.fs_stat(src) then
    vim.uv.fs_unlink(dst)
    assert(vim.uv.fs_symlink(src, dst))
  end
end

local function build(lang)
  local spec = assert(parsers[lang], "unknown language")
  local info = spec.install_info
  assert(not info.generate, "grammar needs `tree-sitter generate`")

  local dir = work .. "/" .. lang
  vim.fn.delete(dir, "rf")
  vim.fn.mkdir(dir, "p")
  local tarball = dir .. "/src.tar.gz"
  run({ "curl", "-fsSL", "-o", tarball, info.url .. "/archive/" .. info.revision .. ".tar.gz" })
  run({ "tar", "-xzf", tarball, "-C", dir, "--strip-components=1" })

  local src = dir .. "/" .. (info.location and (info.location .. "/") or "") .. "src"
  local cmd = { "cc", "-shared", "-fPIC", "-Os", "-I", src, "-o", site .. "/parser/" .. lang .. ".so" }
  cmd[#cmd + 1] = src .. "/parser.c"
  if vim.uv.fs_stat(src .. "/scanner.c") then
    cmd[#cmd + 1] = src .. "/scanner.c"
  end
  run(cmd)

  link_queries(lang)
  for _, dep in ipairs(spec.requires or {}) do
    link_queries(dep)
  end
end

vim.fn.mkdir(site .. "/parser", "p")
vim.fn.mkdir(site .. "/queries", "p")

local failed = {}
for _, lang in ipairs(langs) do
  local ok, err = pcall(build, lang)
  print(("%-16s %s"):format(lang, ok and "ok" or "FAILED"))
  if not ok then
    failed[#failed + 1] = lang .. ": " .. tostring(err)
  end
end
vim.fn.delete(work, "rf")

if #failed > 0 then
  error("parser build failed:\n" .. table.concat(failed, "\n"))
end
