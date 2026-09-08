cask "download-everything" do
  version "1.2.2"
  sha256 "REPLACE_WITH_SHA256_OF_MACOS_ZIP"

  url "https://github.com/drmikecrypto/download-everything/releases/download/app-v#{version}/download-everything-macos-universal.zip"
  name "Download Everything"
  desc "Free ad-free video downloader powered by yt-dlp"
  homepage "https://github.com/drmikecrypto/download-everything"

  livecheck do
    url :url
    regex(/app-v(\d+(?:\.\d+)+)/i)
    strategy :github_latest
  end

  app "Download Everything.app"

  zap trash: [
    "~/Library/Application Support/download_everything",
    "~/Library/Preferences/com.drmikecrypto.downloadEverything.plist",
  ]
end
