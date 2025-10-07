-- hooks/env_keys.lua
-- Tool plugin: configure environment variables

function PLUGIN:EnvKeys(ctx)
    local file = require("file")
    local cmd = require("cmd")

    local env_vars = {}
    local function add_env(k, v)
        if k and v and v ~= "" then
            table.insert(env_vars, { key = k, value = v })
        end
    end
    local function add_env_any(k, v)
        if k and v ~= nil then
            table.insert(env_vars, { key = k, value = v })
        end
    end

    -- Detect chainenv binary once
    local function find_chainenv()
        local out
        if RUNTIME and RUNTIME.osType == "Windows" then
            out = cmd.exec("where chainenv 2>nul") or ""
        else
            out = cmd.exec("sh -lc 'command -v chainenv 2>/dev/null || which chainenv 2>/dev/null'") or ""
        end
        out = out:gsub("%s+$", ""):gsub("^%s+", "")
        if out ~= "" and not out:lower():match("not found") then
            return out
        end
        return nil
    end

    local chainenv_bin = find_chainenv()
    local warned_missing = false
    local default_backend = nil

    -- Current working directory
    local cwd = os.getenv("PWD")
    if not cwd or cwd == "" then
        local got = cmd.exec("pwd") or ""
        cwd = got:gsub("%s+$", "")
    end
    if not cwd or cwd == "" then cwd = "." end

    -- Parse mappings from config files.
    -- Supports either:
    --   [env] NAME = { chainenv = "KEY" }
    -- or
    --   [chainenv.env] NAME = "KEY"
    local function merge_from_file(path)
        local ok, content = pcall(function()
            return file.read(path)
        end)
        if not ok or not content or content == "" then return end

        local in_env = false
        local in_chainenv_env = false
        local in_chainenv_settings = false
        for line in content:gmatch("[^\r\n]+") do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed:match("^%[.-%]") then
                in_env = (trimmed == "[env]")
                in_chainenv_env = (trimmed == "[chainenv.env]")
                in_chainenv_settings = (trimmed == "[chainenv]")
            elseif in_env then
                if trimmed ~= "" and not trimmed:match("^#") then
                    local name, tableBody = trimmed:match("^([A-Za-z_][A-Za-z0-9_]*)%s*=%s*{(.-)}%s*,?%s*$")
                    if name and tableBody then
                        local ce = tableBody:match('chainenv%s*=%s*"([^"]+)"')
                            or tableBody:match("chainenv%s*=%s*'([^']+)'")
                        -- detect template value to infer helper var like CHAINENV_<X>
                        local val = tableBody:match('value%s*=%s*"([^"]*)"') or tableBody:match("value%s*=%s*'([^']*)'")
                        local helper_from_value = nil
                        local template_target_env = nil
                        if val then
                            local hv = val:match("{{%s*env%.([A-Za-z_][A-Za-z0-9_]*)%s*}}")
                            if hv and hv ~= "" then
                                helper_from_value = hv
                                local t = hv:match("^CHAINENV_([A-Za-z_][A-Za-z0-9_]*)$")
                                if t then template_target_env = t end
                            end
                        end
                        if not ce or ce == "" then
                            ce = template_target_env or name
                        end
                        local backend = tableBody:match('chainenv_backend%s*=%s*"([^"]+)"')
                            or tableBody:match("chainenv_backend%s*=%s*'([^']+)'")
                        if not backend or backend == "" then backend = default_backend end
                        -- 'ce' already defaults to template_target_env if present
                        if ce and ce ~= "" then
                            local out = ""
                            if chainenv_bin then
                                local cmdline = chainenv_bin .. ((backend and backend ~= "") and (" --backend " .. backend) or "") .. " get " .. ce
                                local ok, res = pcall(function()
                                    return cmd.exec(cmdline) or ""
                                end)
                                if ok and res then out = res end
                            else
                                if not warned_missing then
                                    warned_missing = true
                                    pcall(function()
                                        io.stderr:write("[chainenv] Missing dependency: install 'chainenv' and ensure it is on PATH\n")
                                    end)
                                end
                            end
                            out = out:gsub("%s+$", ""):gsub("^%s+", "")
                            -- Always export helper so templates don't fail if secret is missing
                            add_env_any("CHAINENV_" .. name, out)
                            if helper_from_value and helper_from_value ~= ("CHAINENV_" .. name) then
                                add_env_any(helper_from_value, out)
                            end
                            if out ~= "" then
                                add_env(name, out)
                            end
                        end
                    end
                end
            elseif in_chainenv_settings then
                if trimmed ~= "" and not trimmed:match("^#") then
                    local db = trimmed:match('^default_backend%s*=%s*"([^"]*)"%s*,?%s*$')
                    if not db then
                        db = trimmed:match("^default_backend%s*=%s*'([^']*)'%s*,?%s*$")
                    end
                    if db and db ~= "" then
                        default_backend = db
                    end
                end
            elseif in_chainenv_env then
                if trimmed ~= "" and not trimmed:match("^#") then
                    -- Support string form: NAME = "KEY"
                    local name, ce = trimmed:match('^([A-Za-z_][A-Za-z0-9_]*)%s*=%s*"([^"]*)"%s*,?%s*$')
                    if not name then name, ce = trimmed:match("^([A-Za-z_][A-Za-z0-9_]*)%s*=%s*'([^']*)'%s*,?%s*$") end
                    -- Support table form: NAME = { key = "KEY", backend = "1password" }
                    local tname, tbody = trimmed:match("^([A-Za-z_][A-Za-z0-9_]*)%s*=%s*{(.-)}%s*,?%s*$")
                    local backend = nil
                    if tname and tbody then
                        name = tname
                        ce = tbody:match('key%s*=%s*"([^"]+)"') or tbody:match("key%s*=%s*'([^']+)'")
                        backend = tbody:match('backend%s*=%s*"([^"]+)"') or tbody:match("backend%s*=%s*'([^']+)'")
                    end
                    if not ce or ce == "" then ce = name end
                    if not backend or backend == "" then backend = default_backend end
                    if name and ce and ce ~= "" then
                        local out = ""
                        if chainenv_bin then
                            local cmdline = chainenv_bin .. ((backend and backend ~= "") and (" --backend " .. backend) or "") .. " get " .. ce
                            local ok, res = pcall(function()
                                return cmd.exec(cmdline) or ""
                            end)
                            if ok and res then out = res end
                        else
                            if not warned_missing then
                                warned_missing = true
                                pcall(function()
                                    io.stderr:write("[chainenv] Missing dependency: install 'chainenv' and ensure it is on PATH\n")
                                end)
                            end
                        end
                        out = out:gsub("%s+$", ""):gsub("^%s+", "")
                        -- Always export helper for template resolution
                        add_env_any("CHAINENV_" .. name, out)
                        if out ~= "" then
                            add_env(name, out)
                        end
                    end
                end
            end
        end
    end

    merge_from_file(file.join_path(cwd, "mise.local.toml"))
    merge_from_file(file.join_path(cwd, "mise.toml"))
    merge_from_file(file.join_path(cwd, ".mise.local.toml"))
    merge_from_file(file.join_path(cwd, ".mise.toml"))
    merge_from_file(file.join_path(cwd, "chainenv.local.toml"))
    merge_from_file(file.join_path(cwd, "chainenv.toml"))

    return env_vars
end
