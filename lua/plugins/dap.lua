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

            -- ── Python ─────────────────────────────────────────────────────
            -- Requires: pip install debugpy
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

            -- ── C / C++ via codelldb ───────────────────────────────────────
            -- Requires: download codelldb from github.com/vadimcn/codelldb/releases
            -- and place at vendor/dap/codelldb/extension/adapter/codelldb.exe
            local codelldb = vim.fn.stdpath("config")
                .. "/vendor/dap/codelldb/extension/adapter/codelldb.exe"
            if vim.fn.executable(codelldb) == 1 then
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
            end
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
}
