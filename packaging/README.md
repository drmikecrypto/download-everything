# Packaging manifests (GitHub Releases–first)

These files help distribute **DEF** via package managers.
Update `PackageVersion` / URLs after each `app-vX.Y.Z` release and fill SHA256 hashes from release assets (`def-*`).

## Winget

See [winget/drmikecrypto.downloadeverything.yaml](winget/drmikecrypto.downloadeverything.yaml).

Submit via PR to [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) under
`manifests/d/drmikecrypto/DownloadEverything/<version>/`.

## Scoop

See [scoop/download-everything.json](scoop/download-everything.json).

## Homebrew Cask

See [homebrew/download-everything.rb](homebrew/download-everything.rb).

```bash
brew install --cask def
```

(after publishing the tap with the cask that installs `DEF.app`)

## F-Droid

Deferred until release APKs are reproducibly signed with a published key (see CONTRIBUTING Android signing secrets).
