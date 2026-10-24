cask "astral-wake" do
  version "0.1.0"
  sha256 "c8eb914539403cf794be157979feea47427bceb8b61882976fe5971b4a8e6a1b"

  url "https://github.com/cdimartino/astral-wake/releases/download/v#{version}/Astral-Wake-#{version}-macos.zip"
  name "Astral Wake"
  desc "Offline deck-building roguelike aboard a living spacecraft"
  homepage "https://github.com/cdimartino/astral-wake"

  depends_on :macos

  app "Astral Wake.app"

  caveats <<~EOS
    This build is ad-hoc signed and has not been notarized by Apple.
    If macOS blocks the first launch, and you trust this release, use
    System Settings > Privacy & Security > Open Anyway after trying to open it.
  EOS
end
