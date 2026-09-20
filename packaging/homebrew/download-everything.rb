cask "def" do
  version "1.3.0"
  sha256 "REPLACE_WITH_SHA256_OF_MACOS_ZIP"

  url "https://github.com/drmikecrypto/download-everything/releases/download/app-v#{version}/def-macos-universal.zip"
  name "DEF"
  desc "Download Everything Forever — free ad-free video downloader powered by yt-dlp"
  homepage "https://github.com/drmikecrypto/download-everything"

  livecheck do
    url :url
    regex(/app-v(\d+(?:\.\d+)+)/i)
    strategy :github_latest
  end

  app "DEF.app"

  zap trash: [
    "~/Library/Application Support/download_everything",
    "~/Library/Preferences/com.drmikecrypto.downloadEverything.plist",
  ]
end
