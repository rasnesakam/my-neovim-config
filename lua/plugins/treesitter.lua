return {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
        ensure_installed = {
            "arduino",
            "c",
            "cpp",
            "cmake",
            "c_sharp",
            "dockerfile",
            "java",
            "json",
            "kotlin",
            "lua",
            "sql",
            "python",
            "rust",
            "typescript",
            "javascript",
            "vim",
            "vimdoc",
            "query",
            "markdown",
            "markdown_inline",
        },
        sync_install = false,
        auto_install = true,
        highlight = {
            enable = true,
            additional_vim_regex_highlighting = false,
        },

    }
}
