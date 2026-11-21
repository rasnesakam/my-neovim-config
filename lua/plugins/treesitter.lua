return {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    config = function()
        local treesitter = require("nvim-treesitter")
        local languages = {
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
        }

        vim.api.nvim_create_autocmd("FileType", {
            group = vim.api.nvim_create_augroup("TreesitterHighlight", { clear = true }),
            callback = function(event)
                local lang = vim.treesitter.language.get_lang(event.match)
                if not lang or pcall(vim.treesitter.start, event.buf, lang) then
                    return
                end
                if not vim.tbl_contains(languages, lang) then
                    return
                end

                treesitter.install(lang):await(vim.schedule_wrap(function(err, installed)
                    if not err and installed and vim.api.nvim_buf_is_loaded(event.buf)
                        and vim.bo[event.buf].filetype == event.match then
                        pcall(vim.treesitter.start, event.buf, lang)
                    end
                end))
            end,
        })
    end,
}
