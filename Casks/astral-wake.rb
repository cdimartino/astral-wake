cask "astral-wake" do
  version "0.3.0"
  sha256 "1e63318f09e32679d5f39e75c0cd648328fc24d8097e2ca0f1b9a5171878870f"

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
