class PipelineMonitor < Formula
  desc "Menu-bar dashboard for the contorch pipeline (capture, transcripts, index, daemons)"
  homepage "https://github.com/contorch/pipeline-monitor"
  url "https://github.com/contorch/pipeline-monitor/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "c3f23397a5ead069982b24d91ee08b05e7ddb4e2c4f794bedd8de1560be5e91d"
  license "Apache-2.0"

  depends_on :macos
  depends_on "python@3.12"

  def install
    # Python sources only; installed into a per-user venv on first run so
    # dependencies (rumps/pyobjc, httpx) arrive as prebuilt wheels and the
    # launchd service keeps working across brew upgrades — same scheme as
    # the meeting-capture formula.
    libexec.install "pyproject.toml", "pipeline_monitor", "README.md"

    (bin/"pipeline-monitor").write <<~SH
      #!/bin/bash
      set -e
      VENV="${PIPELINE_MONITOR_VENV:-$HOME/.pipeline-monitor/venv}"
      STAMP="$VENV/.formula-version"
      PY="#{formula_opt_bin("python@3.12")}/python3.12"
      if ! "$VENV/bin/python" -c "" 2>/dev/null || [ "$(cat "$STAMP" 2>/dev/null)" != "#{version}" ]; then
        echo "pipeline-monitor: setting up environment (first run / upgrade)..." >&2
        rm -rf "$VENV"
        "$PY" -m venv "$VENV"
        "$VENV/bin/pip" -q install --upgrade pip
        "$VENV/bin/pip" -q install "#{libexec}"
        echo "#{version}" > "$STAMP"
      fi
      exec "$VENV/bin/pipeline-monitor" "$@"
    SH
  end

  # A menu-bar app needs the user's GUI session: brew services installs this
  # as a LaunchAgent (not a system daemon) for non-root installs.
  service do
    run [opt_bin/"pipeline-monitor"]
    keep_alive true
    log_path var/"log/pipeline-monitor.log"
    error_log_path var/"log/pipeline-monitor.log"
  end

  def caveats
    <<~EOS
      Start it (and at every login):
        brew services start contorch/tap/pipeline-monitor
      Look for ○ in the menu bar. It reads the meeting-capture / context-orchestrator
      launchd agents and the transcripts index; install those first.
    EOS
  end

  test do
    assert_predicate libexec/"pyproject.toml", :exist?
    assert_predicate bin/"pipeline-monitor", :executable?
  end
end
