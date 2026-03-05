-- Debug Adapter Protocol (DAP) configuration for C/C++ and Python.
--
-- SETUP REQUIREMENTS:
-- ====================
-- C/C++ debugging (codelldb):
--   Automatically vendored at vendor/dap/codelldb/ by fetch.ps1
--   No manual setup required.
--
-- Python debugging (debugpy):
--   pip install debugpy --no-index --find-links vendor\wheels\
--   (debugpy wheel is vendored in vendor/wheels/)
--
-- STATUS CHECK:
--   Run :DapStatus to see which adapters are available.

return {
    -- Debug Adapter Protocol client
    {
        "mfussenegger/nvim-dap",
        keys = {
            { "<F5>",       function() require("dap").continue() end,                                                    desc = "DAP: continue / start" },
            { "<F10>",      function() require("dap").step_over() end,                                                   desc = "DAP: step over"        },
            { "<F11>",      function() require("dap").step_into() end,                                                   desc = "DAP: step into"        },
            { "<F12>",      function() require("dap").step_out() end,                                                    desc = "DAP: step out"         },
            { "<leader>db", function() require("dap").toggle_breakpoint() end,                                           desc = "DAP: toggle breakpoint" },
            { "<leader>dB", function() require("dap").set_breakpoint(vim.fn.input("Condition: ")) end,                  desc = "DAP: conditional breakpoint" },
            { "<leader>dC", function() require("dap").run_to_cursor() end,                                               desc = "DAP: run to cursor"    },
            { "<leader>dr", function() require("dap").repl.toggle() end,                                                 desc = "DAP: REPL"             },
            { "<leader>dl", function() require("dap").run_last() end,                                                    desc = "DAP: run last"         },
        },
        config = function()
            local dap = require("dap")

            -- Track adapter availability for :DapStatus
            local adapters_available = {
                python = false,
                codelldb = false,
            }

            -- ── Python ─────────────────────────────────────────────────────
            -- Check if debugpy is available
            local debugpy_ok = vim.fn.system("python -c \"import debugpy\" 2>&1")
            if vim.v.shell_error == 0 then
                adapters_available.python = true
                dap.adapters.python = {
                    type    = "executable",
                    command = "python",
                    args    = { "-m", "debugpy.adapter" },
                }
                dap.configurations.python = {
                    {
                        type    = "python",
                        request = "launch",
                        name    = "Launch file",
                        program = "${file}",
                        pythonPath = function()
                            local venv = vim.fn.getcwd() .. "/.venv/Scripts/python.exe"
                            return vim.fn.executable(venv) == 1 and venv or "python"
                        end,
                    },
                    {
                        type    = "python",
                        request = "launch",
                        name    = "Launch with args",
                        program = "${file}",
                        args    = function() return vim.split(vim.fn.input("Args: "), " ") end,
                        pythonPath = function()
                            local venv = vim.fn.getcwd() .. "/.venv/Scripts/python.exe"
                            return vim.fn.executable(venv) == 1 and venv or "python"
                        end,
                    },
                }
            else
                vim.notify(
                    "[DAP] debugpy not found — Python debugging disabled.\n"
                        .. "Install with: pip install debugpy --no-index --find-links vendor\\wheels\\",
                    vim.log.levels.WARN
                )
            end

            -- ── C / C++ via codelldb ───────────────────────────────────────
            local codelldb = vim.fn.stdpath("config")
                .. "/vendor/dap/codelldb/adapter/codelldb.exe"
            if vim.fn.executable(codelldb) == 1 then
                adapters_available.codelldb = true
                dap.adapters.codelldb = {
                    type       = "server",
                    port       = "${port}",
                    executable = { command = codelldb, args = { "--port", "${port}" } },
                }
                for _, lang in ipairs({ "c", "cpp" }) do
                    dap.configurations[lang] = {
                        {
                            type        = "codelldb",
                            request     = "launch",
                            name        = "Launch (codelldb)",
                            program     = function()
                                return vim.fn.input("Executable: ", vim.fn.getcwd() .. "/", "file")
                            end,
                            cwd         = "${workspaceFolder}",
                            stopOnEntry = false,
                        },
                    }
                end
            else
                vim.notify(
                    "[DAP] codelldb not found at " .. codelldb .. " — C/C++ debugging disabled.\n"
                        .. "Download from: https://github.com/vadimcn/codelldb/releases\n"
                        .. "Extract to: vendor/dap/codelldb/",
                    vim.log.levels.WARN
                )
            end

            -- ── :DapStatus command ─────────────────────────────────────────
            vim.api.nvim_create_user_command("DapStatus", function()
                local lines = { "DAP Adapter Status:", "" }
                table.insert(lines, "  Python (debugpy):  " .. (adapters_available.python and "✓ available" or "✗ not found"))
                table.insert(lines, "  C/C++ (codelldb):  " .. (adapters_available.codelldb and "✓ available" or "✗ not found"))
                vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
            end, { desc = "Show DAP adapter availability" })
        end,
    },

    -- DAP UI: panels for variables, call stack, breakpoints, watches
    {
        "rcarriga/nvim-dap-ui",
        dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
        keys = {
            { "<leader>du", function() require("dapui").toggle() end, desc = "DAP: toggle UI" },
        },
        config = function()
            local dap, dapui = require("dap"), require("dapui")

            dapui.setup({
                -- Text-only icons, no Nerd Font required
                icons    = { expanded = "v", collapsed = ">", current_frame = "*" },
                controls = {
                    icons = {
                        pause       = "||", play      = ">",
                        step_over   = "->", step_into = "=>",
                        step_out    = "<=", step_back = "<-",
                        run_last    = ">>", terminate = "x",
                        disconnect  = "~",
                    },
                },
            })

            -- Auto open/close the UI when the debugger starts/stops
            dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
            dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
            dap.listeners.before.event_exited["dapui_config"]     = function() dapui.close() end
        end,
    },

    -- Inline virtual text showing variable values during DAP sessions
    {
        "theHamsta/nvim-dap-virtual-text",
        dependencies = { "mfussenegger/nvim-dap", "nvim-treesitter/nvim-treesitter" },
        config = function()
            require("nvim-dap-virtual-text").setup({
                enabled                     = true,
                enabled_commands            = true,   -- :DapVirtualTextEnable/Disable/Toggle
                highlight_changed_variables = true,   -- highlight changed vars differently
                highlight_new_as_changed    = false,
                show_stop_reason            = true,   -- show why execution stopped
                commented                   = false,
                only_first_definition       = true,   -- avoid repetition across scopes
                all_references              = false,
                virt_text_pos               = "eol",  -- at end of line, not inline
                all_frames                  = false,  -- current frame only
            })
        end,
    },
}
