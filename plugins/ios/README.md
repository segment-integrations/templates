# iOS Devbox Plugin

This plugin configures iOS tooling inside Devbox, including enforcing the macOS toolchain and
managing simulator defaults.

- Configuration: Environment variables in `plugin.json`
- Scripts: `.devbox/virtenv/ios/scripts`

`start-ios` runs `devbox run --pure build-ios` in the project and installs the app bundle matched by
`IOS_APP_ARTIFACT`.

## Reference

See `devbox/plugins/ios/REFERENCE.md` for the full command and config reference.
