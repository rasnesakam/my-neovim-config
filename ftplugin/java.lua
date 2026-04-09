-- Java Setup
local jdtls_ok, jdtls = pcall(require, "jdtls")
if not jdtls_ok then
    vim.notify("JDTLS not found, install with `:MasonInstall jdtls`", vim.log.levels.ERROR)
    return
end
local function get_gradle_excludes(root)
    local excludes = {}
    local settings_file = root .. "/settings.gradle"
    local f = io.open(settings_file, "r")
    if not f then return excludes end

    for line in f:lines() do
        local subproject = line:match("include%(['\"](.+)['\"]%)")
        if subproject then
            local path = subproject:gsub(":", "/")
            local full_path = root .. "/" .. path
            -- İçinde .java dosyası yoksa exclude et
            local java_files = vim.fn.glob(full_path .. "/**/*.java", 1, true)
            if #java_files == 0 then
                table.insert(excludes, path)
            end
        end
    end
    f:close()
    return excludes
end
local jdtls_dir = vim.fn.stdpath('data') .. '/mason/share/jdtls'
local config_dir = vim.fn.stdpath('data') .. '/mason/packages/jdtls/config_linux'

-- Root dir'i bir kez hesapla
local root_dir = require('jdtls.setup').find_root({
    'build.gradle',
    'build.gradle.kts',
    'settings.gradle',
    'settings.gradle.kts',
    'gradlew',
    'pom.xml',
    '.git',
}) or vim.fn.getcwd()

-- Workspace'i root_dir'den türet
local project_name = vim.fn.fnamemodify(root_dir, ':t')
local workspace_dir = vim.fn.stdpath('data') .. '/site/java/workspace-root/' .. project_name
os.execute("mkdir -p " .. workspace_dir)

-- Gradle source set'lerini dinamik olarak bul (src/ui gibi non-Java klasörleri hariç)
local source_paths = vim.fn.glob(root_dir .. "/src/*/java", 1, true)
if #source_paths == 0 then
    source_paths = { "src/main/java", "src/test/java" }
end

-- Sadece gerekli bundle'lar
local bundles = {}
local debug_jar = vim.fn.glob(vim.fn.stdpath('data') ..
    '/mason/share/java-debug-adapter/com.microsoft.java.debug.plugin.jar')
if debug_jar ~= "" then table.insert(bundles, debug_jar) end
local test_jar = vim.fn.glob(vim.fn.stdpath('data') .. '/mason/share/java-test/com.microsoft.java.test.plugin.jar')
if test_jar ~= "" then table.insert(bundles, test_jar) end

local capabilities = vim.lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)

local extendedClientCapabilities = jdtls.extendedClientCapabilities
extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

local config = {
    cmd = {
        'java',
        '-Declipse.application=org.eclipse.jdt.ls.core.id1',
        '-Dosgi.bundles.defaultStartLevel=4',
        '-Declipse.product=org.eclipse.jdt.ls.core.product',
        '-Dlog.protocol=true',
        '-Dlog.level=ALL',
        '-javaagent:' .. jdtls_dir .. '/lombok.jar',
        '-Xmx1g',
        '--add-modules=ALL-SYSTEM',
        '--add-opens', 'java.base/java.util=ALL-UNNAMED',
        '--add-opens', 'java.base/java.lang=ALL-UNNAMED',
        '-jar', jdtls_dir .. '/plugins/org.eclipse.equinox.launcher.jar',
        '-configuration', config_dir,
        '-data', workspace_dir,
    },

    root_dir = root_dir,

    settings = {
        java = {
            eclipse = { downloadSources = true },
            maven = { downloadSources = true },
            implementationsCodeLens = { enabled = true },
            referencesCodeLens = { enabled = true },
            references = { enabled = true },
            signatureHelp = { enabled = true },
            project = {
                outputPath = "bin",
                sourcesPaths = source_paths,
            },
            configuration = {
                updateBuildConfiguration = "interactive",
            },
            format = {
                enabled = true,
                comments = true,
                settings = {
                    url = vim.fn.stdpath('config') .. '/utils/eclipse-java-google-style.xml',
                    profile = 'GoogleStyle',
                },
            },
        },
        completion = {
            favoriteStaticMembers = {
                "org.hamcrest.MatcherAssert.assertThat",
                "org.hamcrest.Matchers.*",
                "org.hamcrest.CoreMatchers.*",
                "org.junit.jupiter.api.Assertions.*",
                "java.util.Objects.requireNonNull",
                "java.util.Objects.requireNonNullElse",
                "org.mockito.Mockito.*",
            },
            importOrder = { "java", "javax", "com", "org" },
        },
        extendedClientCapabilities = extendedClientCapabilities,
        sources = {
            organizeImports = {
                starThreshold = 9999,
                staticStarThreshold = 9999,
            },
        },
        codeGeneration = {
            toString = {
                template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}",
            },
            useBlocks = true,
        },
    },

    flags = { allow_incremental_sync = true },
    capabilities = capabilities,
    init_options = { bundles = bundles },
}

config.on_attach = function(client, bufnr)
    -- Global LSP keymap'leri
    local opts = { buffer = bufnr, remap = false }
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
    vim.keymap.set("n", "<leader>vws", vim.lsp.buf.workspace_symbol, opts)
    vim.keymap.set("n", "<leader>vd", vim.diagnostic.open_float, opts)
    vim.keymap.set("n", "[d", vim.diagnostic.goto_next, opts)
    vim.keymap.set("n", "]d", vim.diagnostic.goto_prev, opts)
    vim.keymap.set("n", "<leader>vca", vim.lsp.buf.code_action, opts)
    vim.keymap.set("n", "<leader>vrr", vim.lsp.buf.references, opts)
    vim.keymap.set("n", "<leader>vrn", vim.lsp.buf.rename, opts)
    vim.keymap.set("i", "<C-h>", vim.lsp.buf.signature_help, opts)

    -- Java'ya özel keymap'ler
    vim.keymap.set('n', "<leader>lo", jdtls.organize_imports, { desc = 'Organize imports', buffer = bufnr })
    vim.keymap.set('n', "<leader>tc", jdtls.test_class, { desc = 'Test class', buffer = bufnr })
    vim.keymap.set('n', "<leader>tm", jdtls.test_nearest_method, { desc = 'Test method', buffer = bufnr })
    vim.keymap.set('n', '<leader>lrv', jdtls.extract_variable_all, { desc = 'Extract variable', buffer = bufnr })
    vim.keymap.set('n', '<leader>lrc', jdtls.extract_constant, { desc = 'Extract constant', buffer = bufnr })
    vim.keymap.set('v', '<leader>lrm', [[<ESC><CMD>lua require('jdtls').extract_method(true)<CR>]],
        { desc = 'Extract method', buffer = bufnr })

    -- DAP kurulumu
    require('jdtls').setup_dap({ hotcodereplace = 'auto' })
    local dap_ok, jdtls_dap = pcall(require, "jdtls.dap")
    if dap_ok then
        jdtls_dap.setup_dap_main_class_configs()
    end
end

jdtls.start_or_attach(config)
