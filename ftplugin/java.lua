--- ~/.config/nvim/ftplugin/java.lua

local jdtls_ok, jdtls = pcall(require, "jdtls")

if not jdtls_ok then
    vim.notify(
        "JDTLS bulunamadı. :MasonInstall jdtls",
        vim.log.levels.ERROR
    )
    return
end

-- --------------------------------------------------
-- 1. Project root
-- --------------------------------------------------

local markers = {
    "settings.gradle",
    "settings.gradle.kts",
    "build.gradle",
    "build.gradle.kts",
    "gradlew",
    "pom.xml",
    ".git",
}

local root_dir = vim.fs.root(0, markers)

if not root_dir then
    vim.notify(
        "Java project root bulunamadı.",
        vim.log.levels.WARN
    )
    return
end

root_dir = vim.fs.normalize(root_dir)

-- --------------------------------------------------
-- 2. JDTLS paths
-- --------------------------------------------------

local mason_share = vim.fn.stdpath("data") .. "/mason/share"
local mason_packages = vim.fn.stdpath("data") .. "/mason/packages"

local jdtls_dir = mason_share .. "/jdtls"
local config_dir = mason_packages .. "/jdtls/config_linux"

local launcher_matches = vim.fn.glob(
    jdtls_dir .. "/plugins/org.eclipse.equinox.launcher_*.jar",
    false,
    true
)

-- Bazı JDTLS paketlerinde launcher sabit isimli olabilir.
if #launcher_matches == 0 then
    local fallback = jdtls_dir .. "/plugins/org.eclipse.equinox.launcher.jar"

    if vim.fn.filereadable(fallback) == 1 then
        launcher_matches = { fallback }
    end
end

if #launcher_matches == 0 then
    vim.notify(
        "JDTLS Equinox launcher bulunamadı.",
        vim.log.levels.ERROR
    )
    return
end

if vim.fn.isdirectory(config_dir) == 0 then
    vim.notify(
        "JDTLS config_linux klasörü bulunamadı.",
        vim.log.levels.ERROR
    )
    return
end

local launcher_jar = launcher_matches[1]

-- --------------------------------------------------
-- 3. Workspace
-- --------------------------------------------------

-- Aynı isimli farklı projelerin workspace'leri çakışmasın.
local project_name = vim.fn.fnamemodify(root_dir, ":t")
local project_hash = vim.fn.sha256(root_dir):sub(1, 12)

local workspace_dir = vim.fn.stdpath("data")
    .. "/site/java/workspace/"
    .. project_name
    .. "-"
    .. project_hash

vim.fn.mkdir(workspace_dir, "p")

-- --------------------------------------------------
-- 4. Java runtime
-- --------------------------------------------------

local java_bin = vim.fn.exepath("java")

if java_bin == "" then
    vim.notify(
        "Java executable bulunamadı. PATH ayarını kontrol et.",
        vim.log.levels.ERROR
    )
    return
end

-- --------------------------------------------------
-- 5. Debugger and test bundles
-- --------------------------------------------------

local bundles = {}

local function add_bundle(pattern)
    local matches = vim.fn.glob(pattern, false, true)

    for _, jar in ipairs(matches) do
        table.insert(bundles, jar)
    end
end

add_bundle(
    mason_share
    .. "/java-debug-adapter/com.microsoft.java.debug.plugin.jar"
)

add_bundle(
    mason_share
    .. "/java-test/com.microsoft.java.test.plugin.jar"
)

-- --------------------------------------------------
-- 6. Capabilities
-- --------------------------------------------------

local capabilities = vim.lsp.protocol.make_client_capabilities()

local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

if cmp_ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

local extended_capabilities = jdtls.extendedClientCapabilities

extended_capabilities.resolveAdditionalTextEditsSupport = true

-- --------------------------------------------------
-- 7. Command
-- --------------------------------------------------

local cmd = {
    java_bin,

    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",

    "-Dlog.protocol=true",
    "-Dlog.level=INFO",

    "--add-modules=ALL-SYSTEM",

    "--add-opens",
    "java.base/java.util=ALL-UNNAMED",

    "--add-opens",
    "java.base/java.lang=ALL-UNNAMED",

    "-Xms256m",
    "-Xmx1g",
}

-- Lombok agent (varsa)
local lombok_jar = jdtls_dir .. "/lombok.jar"

if vim.fn.filereadable(lombok_jar) == 1 then
    table.insert(cmd, "-javaagent:" .. lombok_jar)
end

vim.list_extend(cmd, {
    "-jar",
    launcher_jar,

    "-configuration",
    config_dir,

    "-data",
    workspace_dir,
})

-- --------------------------------------------------
-- 8. Google Java Format
-- --------------------------------------------------

local format_config = vim.fn.stdpath("config")
    .. "/utils/eclipse-java-google-style.xml"

-- --------------------------------------------------
-- 9. JDTLS configuration
-- --------------------------------------------------

local config = {
    cmd = cmd,

    root_dir = root_dir,

    capabilities = capabilities,

    init_options = {
        bundles = bundles,
    },

    flags = {
        allow_incremental_sync = true,
    },

    settings = {
        java = {
            eclipse = {
                downloadSources = true,
            },

            maven = {
                downloadSources = true,
            },

            implementationsCodeLens = {
                enabled = true,
            },

            referencesCodeLens = {
                enabled = true,
            },

            references = {
                enabled = true,
            },

            signatureHelp = {
                enabled = true,
            },

            configuration = {
                updateBuildConfiguration = "interactive",
            },

            format = {
                enabled = true,

                comments = true,

                settings = {
                    url = format_config,
                    profile = "GoogleStyle",
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

                importOrder = {
                    "java",
                    "javax",
                    "com",
                    "org",
                },
            },

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
    },
}

-- --------------------------------------------------
-- 10. Attach
-- --------------------------------------------------

config.on_attach = function(client, bufnr)
    local opts = {
        buffer = bufnr,
        remap = false,
    }

    -- General LSP
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

    vim.keymap.set(
        "n",
        "<leader>vws",
        vim.lsp.buf.workspace_symbol,
        opts
    )

    vim.keymap.set(
        "n",
        "<leader>vd",
        vim.diagnostic.open_float,
        opts
    )

    vim.keymap.set(
        "n",
        "[d",
        vim.diagnostic.goto_prev,
        opts
    )

    vim.keymap.set(
        "n",
        "]d",
        vim.diagnostic.goto_next,
        opts
    )

    vim.keymap.set(
        "n",
        "<leader>vca",
        vim.lsp.buf.code_action,
        opts
    )

    vim.keymap.set(
        "n",
        "<leader>vrr",
        vim.lsp.buf.references,
        opts
    )

    vim.keymap.set(
        "n",
        "<leader>vrn",
        vim.lsp.buf.rename,
        opts
    )

    vim.keymap.set(
        "i",
        "<C-h>",
        vim.lsp.buf.signature_help,
        opts
    )

    -- Java-specific
    vim.keymap.set(
        "n",
        "<leader>lo",
        jdtls.organize_imports,
        { buffer = bufnr, desc = "Organize imports" }
    )

    vim.keymap.set(
        "n",
        "<leader>tc",
        jdtls.test_class,
        { buffer = bufnr, desc = "Test class" }
    )

    vim.keymap.set(
        "n",
        "<leader>tm",
        jdtls.test_nearest_method,
        { buffer = bufnr, desc = "Test method" }
    )

    vim.keymap.set(
        "n",
        "<leader>lrv",
        jdtls.extract_variable_all,
        { buffer = bufnr, desc = "Extract variable" }
    )

    vim.keymap.set(
        "n",
        "<leader>lrc",
        jdtls.extract_constant,
        { buffer = bufnr, desc = "Extract constant" }
    )

    vim.keymap.set(
        "v",
        "<leader>lrm",
        function()
            jdtls.extract_method(true)
        end,
        { buffer = bufnr, desc = "Extract method" }
    )

    -- DAP
    local dap_ok = pcall(function()
        jdtls.setup_dap({
            hotcodereplace = "auto",
        })

        require("jdtls.dap").setup_dap_main_class_configs()
    end)

    if not dap_ok then
        vim.notify(
            "JDTLS DAP yapılandırması yüklenemedi.",
            vim.log.levels.WARN
        )
    end
end

-- --------------------------------------------------
-- 11. Start
-- --------------------------------------------------

jdtls.start_or_attach(config)- ~/.config/nvim/ftplugin/java.lua

local jdtls_ok, jdtls = pcall(require, "jdtls")

if not jdtls_ok then
    vim.notify(
        "JDTLS bulunamadı. :MasonInstall jdtls",
        vim.log.levels.ERROR
    )
    return
end

-- --------------------------------------------------
-- 1. Project root
-- --------------------------------------------------

local markers = {
    "settings.gradle",
    "settings.gradle.kts",
    "build.gradle",
    "build.gradle.kts",
    "gradlew",
    "pom.xml",
    ".git",
}

local root_dir = vim.fs.root(0, markers)

if not root_dir then
    vim.notify(
        "Java project root bulunamadı.",
        vim.log.levels.WARN
    )
    return
end

root_dir = vim.fs.normalize(root_dir)

-- --------------------------------------------------
-- 2. JDTLS paths
-- --------------------------------------------------

local mason_share = vim.fn.stdpath("data") .. "/mason/share"
local mason_packages = vim.fn.stdpath("data") .. "/mason/packages"

local jdtls_dir = mason_share .. "/jdtls"
local config_dir = mason_packages .. "/jdtls/config_linux"

local launcher_matches = vim.fn.glob(
    jdtls_dir .. "/plugins/org.eclipse.equinox.launcher_*.jar",
    false,
    true
)

-- Bazı JDTLS paketlerinde launcher sabit isimli olabilir.
if #launcher_matches == 0 then
    local fallback = jdtls_dir .. "/plugins/org.eclipse.equinox.launcher.jar"

    if vim.fn.filereadable(fallback) == 1 then
        launcher_matches = { fallback }
    end
end

if #launcher_matches == 0 then
    vim.notify(
        "JDTLS Equinox launcher bulunamadı.",
        vim.log.levels.ERROR
    )
    return
end

if vim.fn.isdirectory(config_dir) == 0 then
    vim.notify(
        "JDTLS config_linux klasörü bulunamadı.",
        vim.log.levels.ERROR
    )
    return
end

local launcher_jar = launcher_matches[1]

-- --------------------------------------------------
-- 3. Workspace
-- --------------------------------------------------

-- Aynı isimli farklı projelerin workspace'leri çakışmasın.
local project_name = vim.fn.fnamemodify(root_dir, ":t")
local project_hash = vim.fn.sha256(root_dir):sub(1, 12)

local workspace_dir = vim.fn.stdpath("data")
    .. "/site/java/workspace/"
    .. project_name
    .. "-"
    .. project_hash

vim.fn.mkdir(workspace_dir, "p")

-- --------------------------------------------------
-- 4. Java runtime
-- --------------------------------------------------

local java_bin = vim.fn.exepath("java")

if java_bin == "" then
    vim.notify(
        "Java executable bulunamadı. PATH ayarını kontrol et.",
        vim.log.levels.ERROR
    )
    return
end

-- --------------------------------------------------
-- 5. Debugger and test bundles
-- --------------------------------------------------

local bundles = {}

local function add_bundle(pattern)
    local matches = vim.fn.glob(pattern, false, true)

    for _, jar in ipairs(matches) do
        table.insert(bundles, jar)
    end
end

add_bundle(
    mason_share
    .. "/java-debug-adapter/com.microsoft.java.debug.plugin.jar"
)

add_bundle(
    mason_share
    .. "/java-test/com.microsoft.java.test.plugin.jar"
)

-- --------------------------------------------------
-- 6. Capabilities
-- --------------------------------------------------

local capabilities = vim.lsp.protocol.make_client_capabilities()

local cmp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")

if cmp_ok then
    capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

local extended_capabilities = jdtls.extendedClientCapabilities

extended_capabilities.resolveAdditionalTextEditsSupport = true

-- --------------------------------------------------
-- 7. Command
-- --------------------------------------------------

local cmd = {
    java_bin,

    "-Declipse.application=org.eclipse.jdt.ls.core.id1",
    "-Dosgi.bundles.defaultStartLevel=4",
    "-Declipse.product=org.eclipse.jdt.ls.core.product",

    "-Dlog.protocol=true",
    "-Dlog.level=INFO",

    "--add-modules=ALL-SYSTEM",

    "--add-opens",
    "java.base/java.util=ALL-UNNAMED",

    "--add-opens",
    "java.base/java.lang=ALL-UNNAMED",

    "-Xms256m",
    "-Xmx1g",
}

-- Lombok agent (varsa)
local lombok_jar = jdtls_dir .. "/lombok.jar"

if vim.fn.filereadable(lombok_jar) == 1 then
    table.insert(cmd, "-javaagent:" .. lombok_jar)
end

vim.list_extend(cmd, {
    "-jar",
    launcher_jar,

    "-configuration",
    config_dir,

    "-data",
    workspace_dir,
})

-- --------------------------------------------------
-- 8. Google Java Format
-- --------------------------------------------------

local format_config = vim.fn.stdpath("config")
    .. "/utils/eclipse-java-google-style.xml"

-- --------------------------------------------------
-- 9. JDTLS configuration
-- --------------------------------------------------

local config = {
    cmd = cmd,

    root_dir = root_dir,

    capabilities = capabilities,

    init_options = {
        bundles = bundles,
    },

    flags = {
        allow_incremental_sync = true,
    },

    settings = {
        java = {
            eclipse = {
                downloadSources = true,
            },

            maven = {
                downloadSources = true,
            },

            implementationsCodeLens = {
                enabled = true,
            },

            referencesCodeLens = {
                enabled = true,
            },

            references = {
                enabled = true,
            },

            signatureHelp = {
                enabled = true,
            },

            configuration = {
                updateBuildConfiguration = "interactive",
            },

            format = {
                enabled = true,

                comments = true,

                settings = {
                    url = format_config,
                    profile = "GoogleStyle",
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

                importOrder = {
                    "java",
                    "javax",
                    "com",
                    "org",
                },
            },

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
    },
}

-- --------------------------------------------------
-- 10. Attach
-- --------------------------------------------------

config.on_attach = function(client, bufnr)
    local opts = {
        buffer = bufnr,
        remap = false,
    }

    -- General LSP
    vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
    vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)

    vim.keymap.set(
        "n",
        "<leader>vws",
        vim.lsp.buf.workspace_symbol,
        opts
    )

    vim.keymap.set(
        "n",
        "<leader>vd",
        vim.diagnostic.open_float,
        opts
    )

    vim.keymap.set(
        "n",
        "[d",
        vim.diagnostic.goto_prev,
        opts
    )

    vim.keymap.set(
        "n",
        "]d",
        vim.diagnostic.goto_next,
        opts
    )

    vim.keymap.set(
        "n",
        "<leader>vca",
        vim.lsp.buf.code_action,
        opts
    )

    vim.keymap.set(
        "n",
        "<leader>vrr",
        vim.lsp.buf.references,
        opts
    )

    vim.keymap.set(
        "n",
        "<leader>vrn",
        vim.lsp.buf.rename,
        opts
    )

    vim.keymap.set(
        "i",
        "<C-h>",
        vim.lsp.buf.signature_help,
        opts
    )

    -- Java-specific
    vim.keymap.set(
        "n",
        "<leader>lo",
        jdtls.organize_imports,
        { buffer = bufnr, desc = "Organize imports" }
    )

    vim.keymap.set(
        "n",
        "<leader>tc",
        jdtls.test_class,
        { buffer = bufnr, desc = "Test class" }
    )

    vim.keymap.set(
        "n",
        "<leader>tm",
        jdtls.test_nearest_method,
        { buffer = bufnr, desc = "Test method" }
    )

    vim.keymap.set(
        "n",
        "<leader>lrv",
        jdtls.extract_variable_all,
        { buffer = bufnr, desc = "Extract variable" }
    )

    vim.keymap.set(
        "n",
        "<leader>lrc",
        jdtls.extract_constant,
        { buffer = bufnr, desc = "Extract constant" }
    )

    vim.keymap.set(
        "v",
        "<leader>lrm",
        function()
            jdtls.extract_method(true)
        end,
        { buffer = bufnr, desc = "Extract method" }
    )

    -- DAP
    local dap_ok = pcall(function()
        jdtls.setup_dap({
            hotcodereplace = "auto",
        })

        require("jdtls.dap").setup_dap_main_class_configs()
    end)

    if not dap_ok then
        vim.notify(
            "JDTLS DAP yapılandırması yüklenemedi.",
            vim.log.levels.WARN
        )
    end
end

-- --------------------------------------------------
-- 11. Start
-- --------------------------------------------------

jdtls.start_or_attach(config)
