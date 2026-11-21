require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = {
        "arduino_language_server",
        "clangd",
        "neocmake",
        "csharp_ls",
        "dockerls",
        "jdtls",
        "jsonls",
        "kotlin_language_server",
        "lua_ls",
        "sqls",
        "pyright",
        "rust_analyzer",
        "ts_ls",
    },
    automatic_enable = { exclude = { "jdtls" } },
})
