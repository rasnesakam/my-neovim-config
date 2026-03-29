local builtin = require('telescope.builtin')
vim.keymap.set('n', '<leader>ff', builtin.find_files, {})
vim.keymap.set('n', '<C-p>', builtin.git_files, {})
vim.keymap.set('n', '<leader>fs',  function()
	builtin.grep_string({ search = vim.fn.input("Grep > ") });
end)

-- Telescope 'ft_to_lang' nil value hatası için kesin çözüm
-- Neovim 0.10+ ve 0.11 sürümlerinde isimler değiştiği için bu köprüyü kuruyoruz

local ok, ts = pcall(require, "vim.treesitter")
if ok then
    -- Eğer eski isim yoksa ve yeni isim varsa, eski ismi yeniye bağla
    if not ts.ft_to_lang and ts.language and ts.language.get_lang then
        ts.ft_to_lang = ts.language.get_lang
    end

    -- Bazı durumlarda doğrudan vim.treesitter altında aranıyor
    if not vim.treesitter.ft_to_lang then
        vim.treesitter.ft_to_lang = function(ft)
            local lang_ok, lang = pcall(function() 
                return vim.treesitter.language.get_lang(ft) 
            end)
            return (lang_ok and lang) or ft
        end
    end
end


local telescope = require('telescope')
telescope.setup({
  defaults = {
    preview = {
      treesitter = false,
    },
  },
})
