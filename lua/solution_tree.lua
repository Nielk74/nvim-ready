-- lua/solution_tree.lua
-- Sidebar showing the logical structure of a Visual Studio .sln solution.
-- Supports C# (.csproj) and C++ (.vcxproj) projects.
--
-- Public API:
--   require("solution_tree").detect_and_prompt(dir)  -- called from VimEnter
--   require("solution_tree").toggle()                 -- <leader>S keymap

local M = {}

-- ── Internal state ────────────────────────────────────────────────────────────

local S = {
    win       = nil,  -- window handle (nil = closed)
    buf       = nil,  -- buffer handle
    sln       = nil,  -- { path, projects = [{name, path, kind}] }
    nodes     = {},   -- flat array: each entry is a rendered node descriptor
    collapsed = {},   -- set: proj_name -> true  (collapsed projects)
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function norm(path)
    return (path:gsub("\\", "/"))
end

local function joinpath(a, b)
    return norm(vim.fs.joinpath(norm(a), norm(b)))
end

-- ── .sln detection ───────────────────────────────────────────────────────────

-- Walk upward from dir looking for any *.sln files.
-- Returns a list of absolute .sln paths (may be empty).
local function find_slns(start)
    local dir = norm(vim.fn.fnamemodify(start, ":p"):gsub("[/\\]$", ""))
    local seen = {}
    while dir ~= "" and not seen[dir] do
        seen[dir] = true
        local ok, slns = pcall(vim.fn.glob, dir .. "/*.sln", false, true)
        if ok and #slns > 0 then
            return vim.tbl_map(norm, slns), dir
        end
        local parent = norm(vim.fn.fnamemodify(dir, ":h"))
        if parent == dir then break end
        dir = parent
    end
    return {}, nil
end

-- ── .sln parsing ─────────────────────────────────────────────────────────────

-- Returns list of { name, path, kind } where kind = "csharp" | "cpp".
local function parse_sln(sln_path)
    local sln_dir = norm(vim.fn.fnamemodify(sln_path, ":h"))
    local projects = {}
    local ok, lines = pcall(vim.fn.readfile, sln_path)
    if not ok then
        vim.notify("[SolutionTree] could not read " .. sln_path .. ": " .. lines, vim.log.levels.WARN)
        return projects
    end
    -- Solution folder GUID (skip these)
    local FOLDER_GUID = "2150E333-8FDC-42A3-9474-1A3956D46DE8"
    for _, line in ipairs(lines) do
        -- Project("{TYPE-GUID}") = "Name", "rel\path.ext", "{PROJ-GUID}"
        local tguid, name, rel =
            line:match('^%s*Project%("{([^}]+)}"%)[^=]*=[^"]*"([^"]+)"[^,]*,[^"]*"([^"]+)"')
        if tguid and name and rel then
            if tguid:upper() ~= FOLDER_GUID then
                local ext  = (rel:match("%.([^./\\]+)$") or ""):lower()
                local kind = ext == "csproj" and "csharp"
                    or (ext == "vcxproj" or ext == "vcproj") and "cpp"
                    or nil
                if kind then
                    table.insert(projects, {
                        name = name,
                        path = joinpath(sln_dir, rel),
                        kind = kind,
                    })
                end
            end
        end
    end
    return projects
end

-- ── Project file parsing ──────────────────────────────────────────────────────

-- Returns sorted list of absolute file paths in a C# project.
local function parse_csproj(proj_path)
    local proj_dir = norm(vim.fn.fnamemodify(proj_path, ":h"))
    if not vim.uv.fs_stat(proj_path) then return {} end
    local ok, lines = pcall(vim.fn.readfile, proj_path)
    if not ok then
        vim.notify("[SolutionTree] could not read " .. proj_path .. ": " .. lines, vim.log.levels.WARN)
        return {}
    end
    local content = table.concat(lines, "\n")

    -- SDK-style project: glob disk (all .cs under project dir, excluding obj/bin)
    if content:match('<Project%s[^>]*Sdk=') or content:match('<Sdk%s+Name=') then
        local ok_glob, all = pcall(vim.fn.glob, proj_dir .. "/**/*.cs", false, true)
        if not ok_glob then
            vim.notify("[SolutionTree] could not glob " .. proj_dir .. ": " .. all, vim.log.levels.WARN)
            return {}
        end
        local files = vim.tbl_filter(function(f)
            return not f:match("[/\\]obj[/\\]") and not f:match("[/\\]bin[/\\]")
        end, all)
        table.sort(files)
        return vim.tbl_map(norm, files)
    end

    -- Old-style: explicit <Compile Include="..." />
    local files = {}
    for inc in content:gmatch('<Compile%s+Include="([^"]+)"') do
        table.insert(files, joinpath(proj_dir, inc))
    end
    table.sort(files)
    return files
end

-- Returns sorted list of absolute file paths in a C++ project.
local function parse_vcxproj(proj_path)
    local proj_dir = norm(vim.fn.fnamemodify(proj_path, ":h"))
    if not vim.uv.fs_stat(proj_path) then return {} end
    local ok, lines = pcall(vim.fn.readfile, proj_path)
    if not ok then
        vim.notify("[SolutionTree] could not read " .. proj_path .. ": " .. lines, vim.log.levels.WARN)
        return {}
    end
    local content = table.concat(lines, "\n")
    local files = {}
    for _, tag in ipairs({ "ClCompile", "ClInclude", "None", "ResourceCompile", "Image" }) do
        for inc in content:gmatch("<" .. tag .. '%s+Include="([^"]+)"') do
            if not inc:match("%%") then   -- skip MSBuild variables like %(Identity)
                table.insert(files, joinpath(proj_dir, inc))
            end
        end
    end
    table.sort(files)
    return files
end

-- ── Tree node building ────────────────────────────────────────────────────────

local PROJ_ICON = { csharp = "", cpp = "" }

local function get_file_icon(fpath)
    local ok, devicons = pcall(require, "nvim-web-devicons")
    if ok then
        local icon = devicons.get_icon(vim.fn.fnamemodify(fpath, ":t"), nil, { default = true })
        return icon or ""
    end
    return ""
end

-- Build flat list of renderable nodes for the current state.
local function build_nodes()
    local nodes = {}
    local sln = S.sln

    -- Header row
    table.insert(nodes, {
        kind = "header",
        text = "  " .. vim.fn.fnamemodify(sln.path, ":t"),
        path = sln.path,
    })

    for _, proj in ipairs(sln.projects) do
        local collapsed = S.collapsed[proj.name]
        local arrow = collapsed and "▸ " or "▾ "
        local icon  = PROJ_ICON[proj.kind] or ""
        table.insert(nodes, {
            kind      = "project",
            text      = arrow .. icon .. " " .. proj.name,
            path      = proj.path,
            proj_name = proj.name,
            proj_kind = proj.kind,
            collapsed = collapsed,
        })

        if not collapsed then
            local ok_parse, files
            if proj.kind == "csharp" then
                ok_parse, files = pcall(parse_csproj, proj.path)
            elseif proj.kind == "cpp" then
                ok_parse, files = pcall(parse_vcxproj, proj.path)
            else
                files = {}
            end
            if not ok_parse then
                vim.notify("[SolutionTree] error parsing " .. proj.path .. ": " .. files, vim.log.levels.WARN)
                files = {}
            end

            -- Group by first sub-directory to show structure
            local subdirs  = {}  -- ordered list of subdir names
            local by_dir   = {} -- subdir -> [files]
            local root_files = {}
            local proj_dir = norm(vim.fn.fnamemodify(proj.path, ":h")) .. "/"

            for _, fpath in ipairs(files) do
                local rel = fpath:sub(#proj_dir + 1)
                local sub = rel:match("^([^/]+)/")
                if sub then
                    if not by_dir[sub] then
                        by_dir[sub] = {}
                        table.insert(subdirs, sub)
                    end
                    table.insert(by_dir[sub], fpath)
                else
                    table.insert(root_files, fpath)
                end
            end

            -- Root files first
            for _, fpath in ipairs(root_files) do
                local fname = vim.fn.fnamemodify(fpath, ":t")
                local icon  = get_file_icon(fpath)
                table.insert(nodes, {
                    kind = "file",
                    text = "    " .. icon .. " " .. fname,
                    path = fpath,
                })
            end

            -- Sub-directories
            for _, sub in ipairs(subdirs) do
                table.insert(nodes, {
                    kind = "dir",
                    text = "    󰉋 " .. sub .. "/",
                    path = proj_dir .. sub,
                })
                for _, fpath in ipairs(by_dir[sub]) do
                    local fname = vim.fn.fnamemodify(fpath, ":t")
                    local icon  = get_file_icon(fpath)
                    table.insert(nodes, {
                        kind = "file",
                        text = "      " .. icon .. " " .. fname,
                        path = fpath,
                    })
                end
            end
        end
    end

    return nodes
end

-- ── Buffer rendering ──────────────────────────────────────────────────────────

local HL = {
    header  = "Title",
    project = "Function",
    dir     = "Directory",
    file    = "Normal",
}

local function render()
    if not S.buf or not vim.api.nvim_buf_is_valid(S.buf) then return end

    S.nodes = build_nodes()
    local lines = vim.tbl_map(function(n) return n.text end, S.nodes)

    vim.bo[S.buf].modifiable = true
    vim.api.nvim_buf_set_lines(S.buf, 0, -1, false, lines)
    vim.bo[S.buf].modifiable = false

    -- Apply highlights
    vim.api.nvim_buf_clear_namespace(S.buf, -1, 0, -1)
    for i, node in ipairs(S.nodes) do
        local hl = HL[node.kind] or "Normal"
        vim.api.nvim_buf_add_highlight(S.buf, -1, hl, i - 1, 0, -1)
    end
end

-- ── Keymap actions ────────────────────────────────────────────────────────────

local function action_open_or_toggle()
    if not S.win or not vim.api.nvim_win_is_valid(S.win) then return end
    local linenr = vim.api.nvim_win_get_cursor(S.win)[1]
    local node   = S.nodes[linenr]
    if not node then return end

    if node.kind == "project" then
        S.collapsed[node.proj_name] = node.collapsed and nil or true
        render()
    elseif node.kind == "file" then
        -- Open in the last used non-solution-tree window
        local target = nil
        for _, wid in ipairs(vim.api.nvim_list_wins()) do
            if wid ~= S.win then
                local ft = vim.bo[vim.api.nvim_win_get_buf(wid)].filetype
                if ft ~= "solutiontree" and ft ~= "neo-tree" then
                    target = wid
                    break
                end
            end
        end
        if target then
            vim.api.nvim_win_call(target, function()
                vim.cmd("edit " .. vim.fn.fnameescape(node.path))
            end)
            vim.api.nvim_set_current_win(target)
        else
            vim.cmd("wincmd l")
            vim.cmd("edit " .. vim.fn.fnameescape(node.path))
        end
    end
end

local function action_refresh()
    if not S.sln then return end
    local ok, projects = pcall(parse_sln, S.sln.path)
    if not ok then
        vim.notify("[SolutionTree] could not refresh " .. S.sln.path .. ": " .. projects, vim.log.levels.WARN)
        projects = {}
    end
    S.sln.projects = projects
    render()
    vim.notify("[Solution Tree] Refreshed", vim.log.levels.INFO)
end

local function action_help()
    vim.notify(table.concat({
        "Solution Tree keymaps",
        "  <CR> / o  open file / expand-collapse project",
        "  R         refresh (re-parse solution)",
        "  q         close sidebar",
        "  <leader>S toggle sidebar",
    }, "\n"), vim.log.levels.INFO)
end

-- ── Window management ─────────────────────────────────────────────────────────

local function is_open()
    return S.win ~= nil and vim.api.nvim_win_is_valid(S.win)
end

local function make_buf()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype   = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile  = false
    vim.bo[buf].filetype  = "solutiontree"

    local opts = { buffer = buf, silent = true }
    vim.keymap.set("n", "<CR>", action_open_or_toggle,     vim.tbl_extend("force", opts, { desc = "Open/toggle" }))
    vim.keymap.set("n", "o",    action_open_or_toggle,     vim.tbl_extend("force", opts, { desc = "Open/toggle" }))
    vim.keymap.set("n", "R",    action_refresh,            vim.tbl_extend("force", opts, { desc = "Refresh" }))
    vim.keymap.set("n", "q",    function() M.close() end,  vim.tbl_extend("force", opts, { desc = "Close" }))
    vim.keymap.set("n", "?",    action_help,               vim.tbl_extend("force", opts, { desc = "Help" }))
    return buf
end

local function make_win(buf)
    vim.cmd("topleft 35vsplit")
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win, buf)
    local wo           = vim.wo[win]
    wo.number          = false
    wo.relativenumber  = false
    wo.signcolumn      = "no"
    wo.cursorline      = true
    wo.wrap            = false
    wo.winfixwidth     = true
    wo.statusline      = " Solution"
    return win
end

-- ── Public API ────────────────────────────────────────────────────────────────

function M.open(sln_path)
    sln_path = norm(sln_path)
    if is_open() then M.close() end

    -- Close neo-tree if it's sitting there
    pcall(vim.cmd, "Neotree close")

    local ok, projects = pcall(parse_sln, sln_path)
    if not ok then
        vim.notify("[SolutionTree] could not parse " .. sln_path .. ": " .. projects, vim.log.levels.ERROR)
        projects = {}
    end
    S.sln       = { path = sln_path, projects = projects }
    S.collapsed = {}
    S.buf       = make_buf()
    S.win       = make_win(S.buf)

    -- Close when the window is closed externally
    vim.api.nvim_create_autocmd("WinClosed", {
        pattern  = tostring(S.win),
        once     = true,
        callback = function() S.win = nil end,
    })

    render()
    vim.cmd("wincmd l")  -- return focus to editing area
end

function M.close()
    if is_open() then
        vim.api.nvim_win_close(S.win, true)
        S.win = nil
    end
end

--- Returns the absolute path of the currently loaded .sln, or nil.
function M.active_sln()
    return S.sln and S.sln.path or nil
end

function M.toggle()
    if is_open() then
        M.close()
    elseif S.sln then
        -- Reopen previously-loaded solution
        S.buf = make_buf()
        S.win = make_win(S.buf)
        vim.api.nvim_create_autocmd("WinClosed", {
            pattern  = tostring(S.win),
            once     = true,
            callback = function() S.win = nil end,
        })
        render()
        vim.cmd("wincmd l")
    else
        -- No solution loaded yet; run detection for cwd
        M.detect_and_prompt(vim.fn.getcwd())
    end
end

-- Called from VimEnter when nvim is started with a directory argument.
-- Finds .sln files; if any, asks the user what to open.
-- Falls back to neo-tree if the user picks "File tree" or if no .sln found.
function M.detect_and_prompt(dir)
    local slns, _ = find_slns(dir)
    local dir_esc = vim.fn.fnameescape(dir)

    if #slns == 0 then
        -- No solution: open plain neo-tree as before
        pcall(vim.cmd, "Neotree show " .. dir_esc)
        return
    end

    -- Build picker entries
    local items = {}
    for _, sln in ipairs(slns) do
        table.insert(items, {
            label = "Solution tree:  " .. vim.fn.fnamemodify(sln, ":t"),
            sln   = sln,
        })
    end
    table.insert(items, { label = "File tree  (neo-tree)" })

    local labels = vim.tbl_map(function(i) return i.label end, items)

    vim.ui.select(labels, { prompt = "Open as:" }, function(_, idx)
        if not idx then
            -- Dismissed: fall back to file tree
            pcall(vim.cmd, "Neotree show " .. dir_esc)
            return
        end
        local choice = items[idx]
        if choice.sln then
            M.open(choice.sln)
        else
            pcall(vim.cmd, "Neotree show " .. dir_esc)
        end
    end)
end

return M
