# Contributing

Thanks for helping improve Waylandcraft Desktop. Bug reports, hardware test
results, documentation fixes, and focused code changes are welcome.

This is a spare-time hobby project, not a support commitment. Opening an issue
does not guarantee a response or fix. Important or simple issues may be handled
when time and interest allow; larger changes are more likely to happen through
contributor pull requests.

## Before opening an issue

Search existing issues and run `waylandcraft-diagnose --logs` when the problem
involves an installed session. Review the report before sharing it: it includes
local usernames and Nix store paths. A useful report includes the NixOS system
closure, GPU and driver, monitor, launch command and context, and exact
reproduction steps.

There is no dedicated private security-response process. GitHub issues are
public, so do not include credentials, private data, or other secrets.

## Development workflow

The repository's development shell supplies `just` and the pinned formatter:

```console
nix develop
just format
just check
just supervision-vm
```

Run `just check-all` before submitting a pull request. Graphical or input
changes also need the [manual hardware checklist](docs/manual-testing.md);
describe what hardware testing was and was not performed.

Keep changes narrow and declarative. Pin downloaded artifacts and dependency
closures, add a focused automated check for new behavior, and do not commit
runtime saves, logs, credentials, account databases, or generated build
outputs.

By contributing, you agree that your contribution is licensed under the
repository's [MIT License](LICENSE).
