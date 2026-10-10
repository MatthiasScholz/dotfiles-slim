# oh-my-opencode-slim orchestration plugin configuration.
# The `modules/oh-my-opencode-slim.nix` option declaration is imported by
# default.nix.
{
  ...
}:

{
  # oh-my-opencode-slim orchestration plugin in the "personal" profile
  # Uses the OpenCode Zen Free preset (all agents on opencode free models, no cost)
  # https://github.com/alvinunreal/oh-my-opencode-slim/blob/master/docs/opencode-zen-free-preset.md
  programs.oh-my-opencode-slim = {
    enable = true;
    profile = "personal";
    # Active preset (defaults to "opencode-zen-free")
    # preset = "opencode-zen-free";
    # Optional: enable companion desktop window
    companion = false;
  };
}
