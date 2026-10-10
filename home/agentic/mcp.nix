# MCP servers exposed to MCP-aware agent clients.
{
  ...
}:

{
  # https://github.com/nix-community/home-manager/blob/master/modules/programs/mcp.nix
  # NOTE Reused in opencode
  programs.mcp = {
    enable = true;
    servers = {
      mermaid = {
        command = "bun";
        args = [
          "x"
          "mcp-mermaid"
        ];
      };
      devenv = {
        command = "devenv";
        args = [
          "mcp"
        ];
      };
      # TODO add somehow the homeassistant MCP, but not in general availability
    };
  };
}
