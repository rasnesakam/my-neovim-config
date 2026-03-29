local config = {
  cmd = {
    -- Mason'ın kurduğu jdtls yolunu gösterir
    vim.fn.expand("~/.local/share/nvim/mason/bin/jdtls"),
  },
  -- Projenin kök dizinini belirler (gradle/pom dosyasını arar)
  root_dir = vim.fs.dirname(vim.fs.find({'gradlew', '.git', 'mvnw'}, { upward = true })[1]),
}

-- jdtls'i başlat
require('jdtls').start_or_attach(config)
