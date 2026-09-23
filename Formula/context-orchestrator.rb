class ContextOrchestrator < Formula
  desc "contorch memory layer: MCP server, chroma search index, transcript indexer"
  homepage "https://github.com/contorch/context-orchestrator"
  url "https://github.com/contorch/context-orchestrator/archive/refs/tags/v0.2.1.tar.gz"
  sha256 "1203aa09872f986b5d03a24b9d69f12ca235bab2742c982aca4f1a35a79d74ed"
  license "Apache-2.0"

  depends_on :macos
  depends_on "python@3.12"

  def install
    # Sources only; the per-user venv is built on first run so chromadb &
    # friends arrive as prebuilt wheels. The launchd agents and the Claude Code
    # registration point into that venv / at opt_bin, both stable across upgrades.
    libexec.install "pyproject.toml", "src", "README.md"
    pkgshare.install "claude-md-template.md"

    (libexec/"venv-exec").write <<~SH
      #!/bin/bash
      set -e
      VENV="${CONTEXT_ORCHESTRATOR_VENV:-$HOME/.context-orchestrator/venv}"
      STAMP="$VENV/.formula-version"
      PY="#{formula_opt_bin("python@3.12")}/python3.12"
      if ! "$VENV/bin/python" -c "" 2>/dev/null || [ "$(cat "$STAMP" 2>/dev/null)" != "#{version}" ]; then
        echo "context-orchestrator: setting up environment (first run / upgrade, ~1 min)..." >&2
        # Build beside the live venv and swap, so running daemons are not
        # pulled out from under themselves mid-build.
        rm -rf "$VENV.new"
        "$PY" -m venv "$VENV.new"
        "$VENV.new/bin/pip" -q install --upgrade pip
        "$VENV.new/bin/pip" -q install "#{libexec}[embeddings-gemini]"
        echo "#{version}" > "$VENV.new/.formula-version"
        rm -rf "$VENV.old"; [ -d "$VENV" ] && mv "$VENV" "$VENV.old"
        mv "$VENV.new" "$VENV"
        # venv scripts hard-code the build path in their shebangs — rewrite.
        grep -rl "$VENV.new" "$VENV/bin" 2>/dev/null | xargs sed -i '' "s|$VENV.new|$VENV|g"
        rm -rf "$VENV.old"
      fi
      name="$1"; shift
      exec "$VENV/bin/$name" "$@"
    SH
    chmod 0755, libexec/"venv-exec"

    %w[contorch-mcp context-orchestrator-chroma transcript-watcher save-transcript].each do |cmd|
      (bin/cmd).write <<~SH
        #!/bin/bash
        exec "#{opt_libexec}/venv-exec" #{cmd} "$@"
      SH
    end
  end

  def caveats
    <<~EOS
      Configure it (with meeting capture and Claude Code) by running:
        contorch setup
      — installed with: brew install contorch/tap/contorch
    EOS
  end

  test do
    assert_predicate libexec/"venv-exec", :executable?
    assert_predicate pkgshare/"claude-md-template.md", :exist?
  end
end
