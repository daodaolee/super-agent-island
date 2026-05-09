cask "superagentisland" do
  version "0.0.3"
  sha256 "9e5d63e10e573abd0bc819c09b3c09388f3e2da1c26427011b06417570a9aa32"

  url "https://github.com/daodaolee/super-agent-island/releases/download/v#{version}/SuperAgentIsland-#{version}.dmg"
  name "SuperAgentIsland"
  desc "macOS menu bar island for internal SuperAgent usage and GAC credits"
  homepage "https://github.com/daodaolee/super-agent-island"

  app "SuperAgentIsland.app"

  # Homebrew removed --no-quarantine in late 2025. SuperAgentIsland is unsigned by
  # Apple (Sparkle handles update verification independently), so without this
  # the first launch hits a "damaged or unidentified developer" Gatekeeper
  # block.
  #
  # MUST be -dr (recursive). Sparkle.framework ships nested helpers
  # (Updater.app + Installer.xpc + Downloader.xpc); macOS refuses to spawn
  # quarantined helpers from a non-quarantined parent, which surfaces as
  # "The updater failed to start" inside the app.
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/SuperAgentIsland.app"],
                   sudo: false
  end

  zap trash: [
    "~/Library/Preferences/cn.fireflyfusion.SuperAgentIsland.plist",
    "~/Library/Application Support/SuperAgentIsland",
  ]
end
