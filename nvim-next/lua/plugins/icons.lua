-- Role: icon provider. Other plugins detect it on their own; nothing requires
-- this file. Without it they fall back to plain text.
return {
  {
    "nvim-mini/mini.icons",
    lazy = true,
    opts = {},
    init = function()
      -- Serve plugins that still ask for nvim-web-devicons (lualine).
      package.preload["nvim-web-devicons"] = function()
        require("mini.icons").mock_nvim_web_devicons()
        return package.loaded["nvim-web-devicons"]
      end
    end,
  },
}
