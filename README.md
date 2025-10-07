# chainenv mise tool plugin

mise tool plugin for injecting keychain/1password secrets as environment variables through `chainenv` CLI (https://github.com/dvcrn/chainenv)

## What It Does

- Uses `chainenv` to resolve secrets from `keychain` or `1password`
- Injects them into the env

## Install

Make sure you installed https://github.com/dvcrn/chainenv

```bash
# Or after publishing
mise plugin install chainenv https://github.com/dvcrn/mise-chainenv
mise install chainenv
```

##### Local dev

```bash
# Local development
mise plugin link --force chainenv .
mise install chainenv
```

## Configure (inline, with templates)

Enable the tool and declare an env var that pulls from the helper exported by the plugin. Set `tools = true` so it evaluates after the plugin runs. Optionally set a per-var backend (defaults to `keychain`).

```toml
# mise.toml
[tools]
chainenv = "latest"

[env]
# use 1password backend to get `MISE_FOO`
MISE_FOO = { value = "{{env.CHAINENV_MISE_FOO}}", tools = true, chainenv_backend = "1password" }

# use keychain backend to get `MISE_FOO`
MISE_FOO = { value = "{{env.CHAINENV_MISE_FOO}}", tools = true, chainenv_backend = "keychain" }

# use default backend (keychain) to get `MISE_FOO`
MISE_FOO = { value = "{{env.CHAINENV_MISE_FOO}}", tools = true }
```

How it resolves:

- The plugin sees `MISE_FOO` and runs `chainenv --backend 1password get MISE_FOO`.
- It exports both `MISE_FOO` and `CHAINENV_MISE_FOO`.
- The template sets `MISE_FOO` from `CHAINENV_MISE_FOO` after tools, ensuring correct precedence.

Notes:

- Avoid `value = ""` or `required = true` on these entries; they can override/block plugin values.
- If you omit `chainenv_backend`, the plugin uses the default `keychain` backend.

### Examples: keychain and 1Password side-by-side

Store two secrets (one per backend), then configure both vars:

```bash
# Store secrets
chainenv --backend keychain set SERVICE_A_TOKEN
chainenv --backend 1password set SERVICE_B_TOKEN
```

```toml
# mise.toml
[tools]
chainenv = "latest"

[env]
# Uses default backend (keychain)
SERVICE_A_TOKEN = { value = "{{env.CHAINENV_SERVICE_A_TOKEN}}", tools = true }

# Overrides backend to 1Password
SERVICE_B_TOKEN = { value = "{{env.CHAINENV_SERVICE_B_TOKEN}}", tools = true, chainenv_backend = "1password" }
```

Verify:

```bash
mise exec chainenv -- printenv SERVICE_A_TOKEN SERVICE_B_TOKEN
```

## Alternative (sidecar file)

Instead of inline `[env]`, you can declare mappings in `chainenv.toml` and skip templates entirely:

```toml
# chainenv.toml
[chainenv]
default_backend = "1password"  # optional; defaults to keychain

[chainenv.env]
MISE_FOO = "MISE_FOO"                         # uses default backend
ANOTHER = { key = "ANOTHER", backend = "1password" }  # per-var override
```

Then just enable the tool in `mise.toml`:

```toml
[tools]
chainenv = "latest"
```

## Activate and Verify

```bash
# Once in your shell init
eval "$(mise activate bash)"   # zsh/fish supported

# In your project directory
mise exec chainenv -- printenv MISE_FOO
# or, with activation enabled
echo "$MISE_FOO"
```

## Troubleshooting

- Missing CLI: If `chainenv` isn’t on `PATH`, the plugin prints a one-time warning to stderr.
- Backend selection: Default is `keychain`; set `chainenv_backend = "1password"` per variable inline.

## License

MIT
