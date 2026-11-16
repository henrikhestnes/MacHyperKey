cask "machyperkey" do
  version "1.0.3"
  sha256 "7caa2587442f17163e818df2262798ca00580241db8fa9e0b495efa6c484e99b"

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
