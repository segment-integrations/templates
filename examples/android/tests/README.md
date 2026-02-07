# Example Android Tests

These are simple, educational tests showing how to test your Android app with devbox.

## Running Tests

From the `examples/android` directory:

```bash
# Test that the app builds
devbox run bash tests/test-build.sh

# Test that the emulator starts
devbox run bash tests/test-emulator.sh

# Or use the plugin's built-in E2E test
devbox run test:e2e
```

## Plugin Tests vs Example Tests

### Plugin Tests (`devbox run test:e2e`)
- **Purpose:** Test the plugin itself works correctly
- **Scope:** Complete workflow (build → emulator → deploy → verify)
- **Portable:** Works for any Android project that includes the plugin
- **Configuration:** Via environment variables

### Example Tests (these files)
- **Purpose:** Educational - show you how to write your own tests
- **Scope:** Simple, focused examples
- **Usage:** Copy these into your own projects and customize

## Copy to Your Project

To add testing to your own Android project:

1. **Include the plugin:**
   ```json
   {
     "include": ["plugin:android"]
   }
   ```

2. **Configure for your app:**
   ```json
   {
     "env": {
       "ANDROID_APP_APK": "app/build/outputs/apk/debug/app-debug.apk",
       "ANDROID_APP_ID": "com.mycompany.myapp"
     }
   }
   ```

3. **Run plugin E2E test:**
   ```bash
   devbox run test:e2e
   ```

4. **Optional: Copy example tests:**
   ```bash
   cp -r examples/android/tests/ your-project/tests/
   # Edit and customize for your needs
   ```

## Test Configuration

Configure via environment variables in `devbox.json`:

```json
{
  "env": {
    "ANDROID_APP_APK": "path/to/your/app.apk",
    "ANDROID_APP_ID": "com.your.package.name",
    "ANDROID_DEFAULT_DEVICE": "max",
    "ANDROID_SERIAL": "emulator-5554"
  }
}
```

## Learn More

- Plugin tests: `plugins/android/tests/README.md`
- Plugin reference: `plugins/android/REFERENCE.md`
