-- Role: winbar breadcrumbs (path and code context), clickable and pickable.
return {
  {
    "Bekaboo/dropbar.nvim",
    lazy = false, -- the plugin defers its own work
    keys = {
      {
        "<leader>;",
        function()
          require("dropbar.api").pick()
        end,
        desc = "Pick breadcrumb",
      },
    },
  },
}
