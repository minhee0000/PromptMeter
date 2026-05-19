# Reference template for the Homebrew Cask formula. Copy this file to your
# `homebrew-tap` repository under `Casks/promptmeter.rb`, then replace the
# placeholder version + SHA256 values from the latest GitHub release.
#
# The release workflow at .github/workflows/release.yml can do this for you
# automatically if you set the TAP_REPO_TOKEN secret.

cask "promptmeter" do
  version "0.1.0"
  sha256 :no_check # replace with the real SHA256 produced by Scripts/release.sh

  url "https://github.com/minhee0000/PromptMeter/releases/download/v#{version}/PromptMeter-#{version}.zip"
  name "PromptMeter"
  desc "Menu bar meter for AI coding assistant quota and local token usage"
  homepage "https://github.com/minhee0000/PromptMeter"

  # macOS 26 (Tahoe) matches the Xcode project's deployment target. If you
  # lower MACOSX_DEPLOYMENT_TARGET, soften this to :sequoia (15) or :sonoma (14).
  depends_on macos: ">= :tahoe"
  auto_updates false

  app "PromptMeter.app"

  zap trash: [
    "~/Library/Preferences/com.seo.promptMeter.plist",
    "~/Library/Caches/PromptMeter",
    "~/Library/Saved Application State/com.seo.promptMeter.savedState",
  ]
end
