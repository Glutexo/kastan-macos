# Kaštan for macOS Documentation

[← Project overview](../README.md)

- [macOS guide](macos-app.md) — requirements, features, build steps, testing, and download archives.

## Releases

Build with Xcode 26.4.1 or newer and run `make test` to check the app and its development tools.
The Xcode project resolves [Kaštan](https://github.com/Glutexo/kastan) from a versioned Swift package.
Commit the Xcode workspace's updated `Package.resolved` when changing the resolved library version.

Set the app's marketing version in Xcode. After CI passes for the exact commit on `main`, tag it as
`vMAJOR.MINOR.PATCH` and push the tag. The release workflow checks the version and CI result, builds the
universal DMG and source ZIP with `make dist`, and uploads them to GitHub Releases.
