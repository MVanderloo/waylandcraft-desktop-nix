# Contributing

Thanks for helping improve Waylandcraft Desktop. Bug reports, hardware test
results, documentation fixes, and focused code changes are welcome.

## Before opening an issue

Search existing issues and run `waylandcraft-diagnose --logs` when the problem
involves an installed session. Review the report before sharing it: it includes
local usernames and Nix store paths. A useful report includes the NixOS system
closure, GPU and driver, display manager, launch path, and exact reproduction
steps.

For suspected vulnerabilities, follow [SECURITY.md](SECURITY.md) and do not put
sensitive details in a public issue.

## Development workflow

The repository's development shell supplies `just` and the pinned formatter:

```console
nix develop
just format
just check
just supervision-vm
```

Run `just check-all` before submitting a pull request. Graphical or input
changes also need the [target-machine check](docs/development.md#target-machine-check);
describe what hardware testing was and was not performed.

Keep changes narrow and declarative. Pin downloaded artifacts and dependency
closures, add a focused automated check for new behavior, and do not commit
runtime saves, logs, credentials, account databases, or generated build
outputs.

By contributing, you agree that your contribution is licensed under the
repository's [MIT License](LICENSE).
