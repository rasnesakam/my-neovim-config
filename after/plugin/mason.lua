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
    handlers = {
        function(server_name)
            if server_name == "jdtls" then
                return -- ftplugin/java.lua already handles
            end
            require('lspconfig')[server_name].setup({})
        end,
    },
})
