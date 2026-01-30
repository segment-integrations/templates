# iOS Devbox Plugin

This plugin configures iOS tooling inside Devbox, including enforcing the macOS toolchain and
managing simulator defaults via a project-local config file.

- Project config: `devbox.d/ios/ios.json`
- Scripts: `.devbox/virtenv/ios/scripts`

`start-ios` runs `devbox run --pure build-ios` in the project and installs the app bundle matched by
`IOS_APP_ARTIFACT`.

## Reference

See `devbox/plugins/ios/REFERENCE.md` for the full command and config reference.
