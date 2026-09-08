# Packaging manifests (GitHub Releases–first)

These files help distribute Download Everything via package managers.
Update `PackageVersion` / URLs after each `app-vX.Y.Z` release and fill SHA256 hashes from release assets.

## Winget

See [winget/drmikecrypto.downloadeverything.yaml](winget/drmikecrypto.downloadeverything.yaml).

Submit via PR to [microsoft/winget-pkgs](https://github.com/microsoft/winget-pkgs) under
`manifests/d/drmikecrypto/DownloadEverything/<version>/`.

## Scoop

See [scoop/download-everything.json](scoop/download-everything.json).

Add to a personal bucket or publish `drmikecrypto/scoop-bucket`.

```powershell
scoop bucket add drmikecrypto https://github.com/drmikecrypto/scoop-bucket
scoop install download-everything
```

## Homebrew Cask

See [homebrew/download-everything.rb](homebrew/download-everything.rb).

Publish as a tap (`drmikecrypto/homebrew-download-everything`) or submit upstream when notarized.

```bash
brew tap drmikecrypto/download-everything
brew install --cask download-everything
```

## F-Droid

Deferred until release APKs are reproducibly signed with a published key (see CONTRIBUTING Android signing secrets).
