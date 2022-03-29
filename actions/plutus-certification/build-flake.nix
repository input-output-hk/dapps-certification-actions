{ name, std, nixpkgsFlake, ... }@args:
{
  inputs = {
    flake-tarball = ''
      "plutus-certification/generate-flake": success: true
      _inputs: "flake-tarball": binary_hash: string
    '';
  };

  outputs = { ... }: {
    failure.${name}.failure = true;
  };

  job = { flake-tarball }: std.chain args [
    (std.escapeNames [ ] [ ])

    std.singleTask

    {
      resources.memory = 1024 * 2;

      config = {
        console = "pipe";

        packages = std.data-merge.append [
          "${nixpkgsFlake}#gnutar"
          "${nixpkgsFlake}#gzip"
          "${nixpkgsFlake}#bash"
          "${nixpkgsFlake}#nix_2_5"
          "${nixpkgsFlake}#cacert"
        ];

        # Make sure we have Nix sandboxing on!
        bind_read_only = [
          { "/nix" = "/nix"; }
        ];
      };

      template = std.data-merge.append [{
        data = ''
          CICERO_API_URL="{{with secret "kv/data/cicero/api"}}https://cicero:{{.Data.data.basic}}@cicero.infra.aws.iohkdev.io/{{end}}"
        '';
        env = true;
        destination = "secrets/cicero-api-url.env";
      }];
    }

    std.postFact

    (std.script "bash" ''
      set -eEuo pipefail

      curl ''${CICERO_API_URL}/api/fact/${flake-tarball.id}/binary | tar xz
      cd flake

      export NIX_CONFIG='
      experimental-features = nix-command flakes
      '
      export SSL_CERT_FILE="/etc/ssl/certs/ca-bundle.crt"
      nix build path:. --no-link --json | jq  '{ ${builtins.toJSON name}: { success: .[0].outputs.out } }' > /local/cicero/post-fact/success/fact
    '')
  ];
}
