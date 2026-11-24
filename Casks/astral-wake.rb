cask "astral-wake" do
  version "0.4.1"
  sha256 "91e7155ff22ef88a20b21c4dae79c7dab19fdc3c312ea9deef0930fa8416d344"

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
