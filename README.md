# open-balena-base

balena.io services use this image as a base

## Environment (s6-overlay)

`s6-init` runs `configure-balena.sh` before s6 starts. `configure-balena.sh`
adds generated values (`*_HOST`, API keys, certificate-derived vars) to
`/etc/docker.env` and renders confd templates. `s6-init` then exports
`/etc/docker.env`, so s6 copies the values to `/run/s6/container_environment`.

The first line of each run script, and of the `CMD` entry script, decides
what env the process sees:

| Process needs                       | First line                     |
| ----------------------------------- | ------------------------------ |
| No container env (dbus, exporters)  | `#!/usr/bin/env bash`          |
| Full container env, generated too   | `#!/command/with-contenv bash` |

A `with-contenv` service does not need a `config/env` template or
`load_env_file`. Use a `config/env` template only for values that differ from
the container env for one service.

Test commands that replace a service must use the same env as the service,
for example `/command/with-contenv npm test`.

The `confd` oneshot runs `true`. The oneshot remains so that
`dependencies.d/confd` resolves.

A custom `ENTRYPOINT` must exec `/etc/s6-overlay/scripts/s6-init`, not `/init`.

`configure-balena.sh` runs before the `base` bundle and `/etc/cont-init.d`.
Certificates and `/balena` files must exist before the container starts.

Files in `/run/s6/container_environment` are world-readable and include the
generated secrets.
