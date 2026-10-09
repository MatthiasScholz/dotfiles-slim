# agenix rules for the `agenix` CLI (`agenix -e/-d/-r`).
#
# The Home Manager module does not read this file — it points at
# `age.secrets.<name>.file` directly. It exists so the CLI knows which age
# recipients each secret is encrypted for (and can re-encrypt on edit).
#
# Recipient: the age public key of ~/.config/sops/age/keys.txt (ADR-0004).
let
  matthias = "age1l5kln63qmzn9chkp6ehee4p33y3j6e5a8znsz23g0yq0r20zwd9sehqn0k";
in
{
  "secrets/openchamber-web.age".publicKeys = [ matthias ];
  # Shared `OPENCODE_SERVER_PASSWORD` for the OpenCode v2 web server and the
  # OpenChamber server that attaches to it (ADR-0008/ADR-0009).
  "secrets/opencode-server.age".publicKeys = [ matthias ];
}
