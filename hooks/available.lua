-- hooks/available.lua
-- Tool plugin: list available versions

function PLUGIN:Available(ctx)
    -- Single virtual version to activate env injection
    return {
        { version = "latest", note = "virtual" },
    }
end

