# notebooklm-mcp-cli — CLI *and* MCP server for Google NotebookLM.
#
# Replaced notebooklm-go (#1781). Same reverse-engineered approach to the same
# undocumented internal API, but this one also ships an MCP server, so the
# notebooks are reachable as agent tools instead of only from a shell. That is
# the whole reason for the swap; upstream's own README says "use at your own
# risk" and that the internal APIs may change without notice, so this breaks on
# Google's schedule, not ours. Pin a release, do not track master.
#
# Authentication is a live Google session cookie, extracted from a browser by
# `nlm auth`. Three consequences, all inherited from the tool this replaced:
#
#   1. The cookie carries the full power of the account, deletion included, so a
#      dedicated Google account is the cautious choice.
#   2. It expires every few weeks and must be re-extracted, per host. This is
#      not fire-and-forget.
#   3. State lives in ~/.notebooklm-mcp-cli/ at mode 0700 (NOTEBOOKLM_MCP_CLI_PATH
#      overrides it). That is already outside the syncthing folders in
#      modules/services/syncthing.nix, which cover ~/.claude and ~/.gemini only,
#      so the credential does not replicate to other hosts. Keep it that way --
#      do not move this under a synced path.
#
# Nothing here declares the credential and nothing should: it is created
# interactively, it rotates when Google rotates it, and it is a user credential
# rather than a system secret, so agenix is the wrong instrument.
#
# Every runtime dependency is in python3Packages on the DEFAULT python, which is
# deliberate: Hydra only builds the default interpreter, so pinning a specific
# pythonXXXPackages set would compile the whole dependency tree locally and
# expose us to flaky upstream tests for no benefit.
#
# Bump: check `curl -s https://pypi.org/pypi/notebooklm-mcp-cli/json | jq -r .info.version`,
# update version, set hash to lib.fakeHash and take the value nix reports.
{ lib
, python3Packages
, fetchPypi
}:

python3Packages.buildPythonApplication rec {
  pname = "notebooklm-mcp-cli";
  version = "0.11.3";
  pyproject = true;

  src = fetchPypi {
    pname = "notebooklm_mcp_cli";
    inherit version;
    hash = "sha256-CWpInxAjDRjx38QuNCLJej2VI3L/AbR0wTHuSd9mxS8=";
  };

  build-system = [ python3Packages.hatchling ];

  dependencies = with python3Packages; [
    fastmcp
    httpx
    platformdirs
    pydantic
    pyyaml
    rich
    typer
    websocket-client
  ];

  # The bundled tests drive the live NotebookLM API, so they need a Google
  # session cookie and network. Both are unavailable in the sandbox and neither
  # belongs in a build. pythonImportsCheck below is the real gate: it catches a
  # missing dependency, which is the failure mode that actually bites here.
  doCheck = false;

  pythonImportsCheck = [
    "notebooklm_tools"
    "notebooklm_tools.cli.main"
    "notebooklm_tools.mcp.server"
  ];

  meta = {
    description = "CLI and MCP server for Google NotebookLM (unofficial, reverse-engineered)";
    homepage = "https://github.com/jacob-bd/gemini-notebook-mcp-cli";
    changelog = "https://github.com/jacob-bd/gemini-notebook-mcp-cli/blob/main/CHANGELOG.md";
    license = lib.licenses.mit;
    mainProgram = "nlm";
    platforms = lib.platforms.unix;
  };
}
