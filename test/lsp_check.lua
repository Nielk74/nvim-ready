-- test/lsp_check.lua — Headless LSP test harness
-- Run via: nvim --headless -u <init.lua> <file> -c "lua dofile('test/lsp_check.lua')"
-- Writes structured output to stdout; calls qa! when done.
--
-- Output lines:
--   OK    <msg>      — test passed
--   FAIL  <msg>      — test failed
--   INFO  <msg>      — informational
--   WARN  <msg>      — unexpected warning from notify
--   ERR   <msg>      — error-level notification from notify

local OUT_OK   = "OK   "
local OUT_FAIL = "FAIL "
local OUT_INFO = "INFO "
local OUT_WARN = "WARN "
local OUT_ERR  = "ERR  "

local function out(prefix, msg)
    -- Collapse newlines so each log entry is one line.
    local line = prefix .. " " .. msg:gsub("[\r\n]+", " | "):gsub("%s+", " ")
    io.write(line .. "\n")
    io.flush()
end

-- ── Intercept vim.notify to capture messages produced during startup ─────────
local captured_notifications = {}
local _real_notify = vim.notify
vim.notify = function(msg, level, opts)
    level = level or vim.log.levels.INFO
    table.insert(captured_notifications, { msg = tostring(msg), level = level })
    -- Do NOT forward in headless mode to avoid UI noise.
end

-- ── Main test (scheduled so lazy.nvim and all BufReadPre handlers finish) ────
vim.schedule(function()
    local bufnr = vim.api.nvim_get_current_buf()
    local fname = vim.api.nvim_buf_get_name(bufnr)

    out(OUT_INFO, "=== LSP CHECK: " .. fname)

    local ft = vim.bo[bufnr].filetype
    out(OUT_INFO, "filetype: " .. (ft ~= "" and ft or "(none — set manually)"))

    -- For headless mode the filetype detection might not trigger.
    -- Force filetype detection if needed.
    if ft == "" then
        vim.cmd("filetype detect")
        ft = vim.bo[bufnr].filetype
        out(OUT_INFO, "filetype after detect: " .. (ft ~= "" and ft or "(still none)"))
    end

    -- ── Wait for LSP to attach (up to 45 s) ─────────────────────────────────
    local ATTACH_TIMEOUT_MS = 45000
    local attached = vim.wait(ATTACH_TIMEOUT_MS, function()
        return #vim.lsp.get_clients({ bufnr = bufnr }) > 0
    end, 500)

    if not attached then
        out(OUT_FAIL, "No LSP client attached after " .. (ATTACH_TIMEOUT_MS / 1000) .. "s")
        -- Show notifications that might explain the failure.
        for _, n in ipairs(captured_notifications) do
            if n.level >= vim.log.levels.WARN then
                local pfx = n.level >= vim.log.levels.ERROR and OUT_ERR or OUT_WARN
                out(pfx, n.msg)
            end
        end
        vim.cmd("qa!")
        return
    end

    -- ── Report attached clients ───────────────────────────────────────────────
    local clients = vim.lsp.get_clients({ bufnr = bufnr })
    for _, c in ipairs(clients) do
        out(OUT_OK, "LSP attached: " .. c.name
            .. (c.initialized and " [initialized]" or " [initializing...]"))
    end

    -- ── Wait for server to fully initialise and send first diagnostics ────────
    local SETTLE_MS = 8000
    out(OUT_INFO, "waiting " .. (SETTLE_MS / 1000) .. "s for diagnostics to settle...")
    vim.wait(SETTLE_MS)

    -- ── Diagnostics summary ───────────────────────────────────────────────────
    local diags  = vim.diagnostic.get(bufnr)
    local counts = { [1] = 0, [2] = 0, [3] = 0, [4] = 0 }   -- E/W/I/H
    for _, d in ipairs(diags) do
        counts[d.severity] = (counts[d.severity] or 0) + 1
    end
    out(OUT_INFO, string.format("diagnostics: %d errors, %d warnings, %d info, %d hints",
        counts[1], counts[2], counts[3], counts[4]))

    -- Dump the first few errors so we know what they are.
    local shown = 0
    for _, d in ipairs(diags) do
        if d.severity == vim.diagnostic.severity.ERROR and shown < 5 then
            out(OUT_INFO, string.format("  diag[E] line %d: %s", d.lnum + 1, d.message))
            shown = shown + 1
        end
    end

    -- ── Notifications captured during the session ─────────────────────────────
    local notif_count = 0
    for _, n in ipairs(captured_notifications) do
        if n.level >= vim.log.levels.WARN then
            local pfx = n.level >= vim.log.levels.ERROR and OUT_ERR or OUT_WARN
            out(pfx, n.msg)
            notif_count = notif_count + 1
        end
    end
    if notif_count == 0 then
        out(OUT_OK, "no warnings or errors in notifications")
    end

    -- ── Final verdict ─────────────────────────────────────────────────────────
    if counts[1] == 0 and notif_count == 0 then
        out(OUT_OK, "clean — no errors")
    elseif counts[1] > 0 then
        out(OUT_FAIL, counts[1] .. " diagnostic error(s) found")
    else
        out(OUT_WARN, "notifications above may indicate issues")
    end

    vim.cmd("qa!")
end)
