-- metadata.lua
-- Backend plugin metadata and configuration
-- Documentation: https://mise.jdx.dev/backend-plugin-development.html

PLUGIN = { -- luacheck: ignore
    -- Required: Plugin name (will be the backend name users reference)
    name = "chainenv",

    -- Required: Plugin version (not the tool versions)
    version = "1.0.0",

    -- Required: Brief description of the backend and tools it manages
    description = "Dynamic env injection via chainenv",

    -- Required: Plugin author/maintainer
    author = "dvcrn",

    -- Optional: Plugin homepage/repository URL
    homepage = "https://github.com/dvcrn/mise-chainenv",

    -- Optional: Plugin license
    license = "MIT",

    -- Optional: Important notes for users
    notes = {
        "Requires `chainenv` to be installed on your system",
    },
}
