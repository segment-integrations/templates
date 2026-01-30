# React Native Devbox Plugin Reference

## Overview

This plugin composes the Android and iOS plugins.

## Commands

- Android: `devbox run --pure start-emu`, `devbox run --pure start-android`, `devbox run --pure stop-emu`
- iOS: `devbox run --pure start-sim`, `devbox run --pure start-ios`, `devbox run --pure stop-sim`
- Web/Metro: `devbox run --pure start-web`

## Files

- Android config and devices: `devbox.d/android/`
- iOS config and devices: `devbox.d/ios/`
- React Native config: `devbox.d/react-native/react-native.json`

## Config keys (`react-native.json`)

- `WEB_BUILD_PATH`
