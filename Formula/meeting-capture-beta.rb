class MeetingCaptureBeta < Formula
  desc "meeting-capture BETA — live mode + in-meeting copilot (preview channel)"
  homepage "https://github.com/contorch/meeting-capture"
  url "https://github.com/contorch/meeting-capture/archive/refs/tags/v0.3.0-beta.1.tar.gz"
  sha256 "11c3dfb864ddd96f1d14df382b0eddee30d203d87b0eee34405f75558d8dd4b2"
  license "Apache-2.0"

  depends_on :macos
  depends_on "python@3.12"

  # Preview channel — cannot coexist with the stable formula (both ship the
  # meeting-capture + sysaudio binaries). Switch back: brew uninstall
  # meeting-capture-beta && brew install contorch/tap/meeting-capture
  conflicts_with "meeting-capture", because: "both install meeting-capture and sysaudio"

  # Prebuilt, Developer ID-signed universal binary from the release — no Xcode
  # needed to install, and the stable signature means macOS permission grants
  # survive upgrades (an ad-hoc local build would break them every version).
  resource "sysaudio-prebuilt" do
    url "https://github.com/contorch/meeting-capture/releases/download/v0.3.0-beta.1/sysaudio-universal-macos.tar.gz"
    sha256 "0e0607aadfc89bef1dfb546bd4382c6088d544a4ff9edacd10fabf8c80b9b270"
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
    EOS
  end

  test do
    assert_predicate bin/"sysaudio", :executable?
    assert_match "Usage", shell_output("#{bin}/sysaudio --help")
  end
end
