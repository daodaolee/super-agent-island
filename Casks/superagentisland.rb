cask "superagentisland" do
  version "0.0.3"
  sha256 "efae3c6cdeb64e01788c4af6492fd454e6f0bbeb4ef621a225cb7f92647abeea"

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
