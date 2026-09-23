class Contorch < Formula
  desc "Open-source memory layer for coding agents — meeting capture + search + menu bar"
  homepage "https://contorch.com"
  url "https://github.com/contorch/pipeline-monitor/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "68978949b5f1893a55deaad8321617b7f2bda4394f54f8a6d0d92cd6a4ab31d4"
  license "Apache-2.0"

  depends_on :macos
  depends_on "contorch/tap/context-orchestrator"
  depends_on "contorch/tap/meeting-capture"
  depends_on "python@3.12"

  def install
    # The `contorch` CLI (setup / doctor / status / stop / resume) and the
    # menu-bar app both live in the pipeline-monitor package.
    libexec.install "pyproject.toml", "pipeline_monitor", "README.md"

    (libexec/"venv-exec").write <<~SH
      #!/bin/bash
      set -e
      VENV="${CONTORCH_VENV:-$HOME/.contorch/venv}"
      STAMP="$VENV/.formula-version"
      PY="#{formula_opt_bin("python@3.12")}/python3.12"
      if ! "$VENV/bin/python" -c "" 2>/dev/null || [ "$(cat "$STAMP" 2>/dev/null)" != "#{version}" ]; then
        echo "contorch: setting up environment (first run / upgrade)..." >&2
        rm -rf "$VENV"
        "$PY" -m venv "$VENV"
        "$VENV/bin/pip" -q install --upgrade pip
        "$VENV/bin/pip" -q install "#{libexec}"
        echo "#{version}" > "$STAMP"
      fi
      name="$1"; shift
      exec "$VENV/bin/$name" "$@"
    SH
    chmod 0755, libexec/"venv-exec"

    (bin/"contorch").write <<~SH
      #!/bin/bash
      exec "#{opt_libexec}/venv-exec" contorch "$@"
    SH
    (bin/"contorch-menubar").write <<~SH
      #!/bin/bash
      exec "#{opt_libexec}/venv-exec" pipeline-monitor "$@"
    SH
  end

  # The menu-bar app. A LaunchAgent in the user's GUI session.
  service do
    run [opt_bin/"contorch-menubar"]
    keep_alive true
    log_path var/"log/contorch-menubar.log"
    error_log_path var/"log/contorch-menubar.log"
  end

  def caveats
    <<~EOS
      Finish installing — this connects everything and walks you through the
      two things macOS and Google need from you (a recording permission, a key):
        contorch setup
    EOS
  end

  test do
    assert_predicate bin/"contorch", :executable?
    assert_predicate libexec/"pyproject.toml", :exist?
  end
end
