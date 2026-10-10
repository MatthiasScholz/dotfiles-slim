# AgentsView: local web viewer for AI agent sessions.
# The `modules/agentsview.nix` option declaration is imported by home.nix.
{
  ...
}:

{
  # AgentsView - local web viewer for AI agent sessions
  # https://github.com/kenn-io/agentsview (installed via Nix release binary,
  # config.toml generated declaratively, no Docker/homebrew involved)
  programs.agentsview = {
    enable = true;
    launchd.enable = true;

    # Example per-agent overrides (see https://agentsview.io/configuration/):
    # agentDirs = {
    #   aider = [ "~/code" ];
    #   claude = [ "~/.claude/projects" ];
    # };
    # disabledAgents = [ "gemini" ];

    # Freeform TOML pass-through for tables like [pg], [duckdb], [vector]:
    # settings.pg.url = "postgres://user:pass@work-db/agentsview";
  };
}
