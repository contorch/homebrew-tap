class MeetingCapture < Formula
  desc "Always-on two-channel (me/them) meeting transcription daemon for macOS"
  homepage "https://github.com/contorch/meeting-capture"
  url "https://github.com/contorch/meeting-capture/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "cbe9c366e91e9dc44b99005791c7f930ce0a44fe661540070d221003af135b06"
  license "Apache-2.0"

  depends_on :macos
  depends_on "python@3.12"

  # Prebuilt, Developer ID-signed universal binary from the release — no Xcode
  # needed to install, and the stable signature means macOS permission grants
  # survive upgrades (an ad-hoc local build would break them every version).
  resource "sysaudio-prebuilt" do
    url "https://github.com/contorch/meeting-capture/releases/download/v0.3.0/sysaudio-universal-macos.tar.gz"
    sha256 "89ef6e67b4c95daa1e6af10a0ef78bb761f221540553feead100b1e791653d9d"
  end

  def install
    # sysaudio: the ScreenCaptureKit capture binary and the TCC identity —
    # Screen Recording and Microphone grants attach to it. Installed prebuilt;
    # do NOT re-sign (that would replace the Developer ID signature).
    resource("sysaudio-prebuilt").stage do
      bin.install "sysaudio"
    end

    # Python sources only; installed into a per-user venv on first run so
    # dependencies arrive as prebuilt wheels (no compilers) and the daemon's
    # launchd plist keeps working across brew upgrades.
    libexec.install "pyproject.toml", "src", "README.md"

    (bin/"meeting-capture").write <<~SH
      #!/bin/bash
      set -e
      VENV="${MEETING_CAPTURE_VENV:-$HOME/.meeting-capture/venv}"
      STAMP="$VENV/.formula-version"
      PY="#{formula_opt_bin("python@3.12")}/python3.12"
      if ! "$VENV/bin/python" -c "" 2>/dev/null || [ "$(cat "$STAMP" 2>/dev/null)" != "#{version}" ]; then
        echo "meeting-capture: setting up environment (first run / upgrade)..." >&2
        rm -rf "$VENV"
        "$PY" -m venv "$VENV"
        "$VENV/bin/pip" -q install --upgrade pip
        "$VENV/bin/pip" -q install "#{libexec}"
        echo "#{version}" > "$STAMP"
      fi
      export MEETING_CAPTURE_SYSAUDIO="${MEETING_CAPTURE_SYSAUDIO:-#{opt_bin}/sysaudio}"
      exec "$VENV/bin/meeting-capture" "$@"
    SH
  end

  def caveats
    <<~EOS
      One-time setup:

      1. Permissions — System Settings → Privacy & Security →
         Screen & System Audio Recording → "+" → add:
           #{opt_bin}/sysaudio
         (press Cmd+Shift+G in the file dialog to type the path, and make
         sure it is enabled under "System Audio Recording Only" as well).
         The first recording session pops a Microphone prompt for
         "sysaudio" — click Allow to get own-voice ("Me:") transcription.
         Grants persist across upgrades — the binary carries a stable
         Developer ID signature.

      2. Gemini API key — export GOOGLE_API_KEY (or GEMINI_API_KEY), or
         write the key to ~/.config/google/key (chmod 600).
         Free keys: https://aistudio.google.com/apikey

      3. Start it:
           meeting-capture install    # auto-start at login (launchd)
           meeting-capture doctor     # verify the whole pipeline

      Transcripts land in ~/transcripts/ as Markdown.

      Tip: `brew uninstall` can autoremove shared deps (python@3.x) that
      other contorch tools link. Set HOMEBREW_NO_AUTOREMOVE=1 if you also
      run pipeline-monitor / context-orchestrator from Homebrew.
    EOS
  end

  test do
    assert_predicate bin/"sysaudio", :executable?
    assert_match "Usage", shell_output("#{bin}/sysaudio --help")
  end
end
