cask "machyperkey" do
  version "1.0.0"
  sha256 "5dd17d4d44a43c0755a86c21ff6a2537fac4108033c98234d16e696372a2590d"

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
