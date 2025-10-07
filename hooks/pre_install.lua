-- hooks/pre_install.lua
-- Tool plugin: pre-install step. No-op for virtual tool.

function PLUGIN:PreInstall(ctx)
    local version = ctx.version or "latest"
    return {
        version = version,
        note = "chainenv virtual activation",
    }
end

