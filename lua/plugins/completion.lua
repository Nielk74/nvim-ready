return {
    {
        "hrsh7th/nvim-cmp",
        event = { "InsertEnter", "CmdlineEnter" },
        dependencies = {
            -- LSP source
            "hrsh7th/cmp-nvim-lsp",
            -- Other sources
            "hrsh7th/cmp-buffer",
            "hrsh7th/cmp-path",
            "hrsh7th/cmp-cmdline",
            -- Snippet engine
            {
                "L3MON4D3/LuaSnip",
                build = (function()
                    -- Build jsregexp on non-Windows; skip on Windows to avoid
                    -- needing extra tools.
                    if vim.fn.has("win32") == 1 then return end
                    return "make install_jsregexp"
                end)(),
                dependencies = {
                    "rafamadriz/friendly-snippets",
                    config = function()
                        -- Load VS Code style snippets (friendly-snippets)
                        require("luasnip.loaders.from_vscode").lazy_load()
                    end,
                },
            },
            "saadparwaiz1/cmp_luasnip",
            -- Show function signatures while typing
            "hrsh7th/cmp-nvim-lsp-signature-help",
        },
        config = function()
            local cmp     = require("cmp")
            local luasnip = require("luasnip")

            local kind_icons = {
                Text          = "T",  Method        = "m",  Function      = "f",
                Constructor   = "c",  Field         = "F",  Variable      = "v",
                Class         = "C",  Interface     = "I",  Module        = "M",
                Property      = "p",  Unit          = "u",  Value         = "V",
                Enum          = "E",  Keyword       = "k",  Snippet       = "s",
                Color         = "#",  File          = "F",  Reference     = "r",
                Folder        = "D",  EnumMember    = "e",  Constant      = "K",
                Struct        = "S",  Event         = "!",  Operator      = "o",
                TypeParameter = "T",
            }

            cmp.setup({
                snippet = {
                    expand = function(args)
                        luasnip.lsp_expand(args.body)
                    end,
                },

                window = {
                    completion    = cmp.config.window.bordered(),
                    documentation = cmp.config.window.bordered(),
                },

                mapping = cmp.mapping.preset.insert({
                    ["<C-b>"]     = cmp.mapping.scroll_docs(-4),
                    ["<C-f>"]     = cmp.mapping.scroll_docs(4),
                    ["<C-Space>"] = cmp.mapping.complete(),
                    ["<C-e>"]     = cmp.mapping.abort(),
                    -- Confirm only explicitly selected entries
                    ["<CR>"]      = cmp.mapping.confirm({ select = false }),
                    -- Tab: cycle completions or jump through snippet placeholders
                    ["<Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_next_item()
                        elseif luasnip.expand_or_locally_jumpable() then
                            luasnip.expand_or_jump()
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                    ["<S-Tab>"] = cmp.mapping(function(fallback)
                        if cmp.visible() then
                            cmp.select_prev_item()
                        elseif luasnip.locally_jumpable(-1) then
                            luasnip.jump(-1)
                        else
                            fallback()
                        end
                    end, { "i", "s" }),
                }),

                sources = cmp.config.sources({
                    { name = "nvim_lsp",               priority = 1000 },
                    { name = "nvim_lsp_signature_help", priority = 900  },
                    { name = "luasnip",                priority = 750  },
                    { name = "buffer",                 priority = 500,
                      option = { get_bufnrs = vim.api.nvim_list_bufs } },
                    { name = "path",                   priority = 250  },
                }),

                formatting = {
                    fields = { "kind", "abbr", "menu" },
                    format = function(entry, item)
                        item.kind = string.format("%s %s",
                            kind_icons[item.kind] or "?", item.kind)
                        item.menu = ({
                            nvim_lsp               = "[LSP]",
                            nvim_lsp_signature_help = "[Sig]",
                            luasnip                = "[Snip]",
                            buffer                 = "[Buf]",
                            path                   = "[Path]",
                        })[entry.source.name] or ""
                        return item
                    end,
                },

                experimental = {
                    ghost_text = true,
                },
            })

            -- Cmdline completions
            cmp.setup.cmdline({ "/", "?" }, {
                mapping = cmp.mapping.preset.cmdline(),
                sources = { { name = "buffer" } },
            })

            cmp.setup.cmdline(":", {
                mapping = cmp.mapping.preset.cmdline(),
                sources = cmp.config.sources(
                    { { name = "path" } },
                    { { name = "cmdline" } }
                ),
            })
        end,
    },
}
