cask "machyperkey" do
  version "1.0.1"
  sha256 "a5011b732b02123fdbf0a3696b3d9b5cddbec945b2e4e65e979d84ea2dc375f2"

  url "https://github.com/henrikhestnes/MacHyperKey/releases/download/v#{version}/MacHyperKey.zip"
  name "MacHyperKey"
  desc "Turn caps lock or another key into a hyper key"
  homepage "https://github.com/henrikhestnes/MacHyperKey"

  depends_on macos: :sonoma

  app "MacHyperKey.app"

  uninstall quit: "io.machyperkey.app"

  zap trash: "~/Library/Preferences/io.machyperkey.app.plist"

  caveats <<~EOS
    This build is signed with a self-signed certificate and has not been notarized by Apple.

    MacHyperKey needs Accessibility access. Enable it in
    System Settings → Privacy & Security → Accessibility. Upgrades keep the permission.
  EOS
end
