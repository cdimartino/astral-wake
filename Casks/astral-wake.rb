cask "astral-wake" do
  version "0.2.0"
  sha256 "b78af0124dca04fa2fa86ba42a778370f9940343504dc2083145b8da70e96362"

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
