-- New addition: the original config had no completion engine.
return {
  "saghen/blink.cmp",
  event = "InsertEnter",
  version = "1.*",
  opts = {
    keymap = { preset = "default" },
    sources = {
      default = { "lsp", "path", "buffer" },
    },
  },
}
