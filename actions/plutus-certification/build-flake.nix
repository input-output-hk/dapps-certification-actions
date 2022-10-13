{ name, std, lib, nixpkgsFlake, helperFlakeInput, ... }@args:
{
  inputs = {
    flake-tarball = ''
      "plutus-certification/generate-flake": success: true
      _inputs: "flake-tarball": binary_hash: string
    '';
  };

  output = { ... }: {
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
          "${nixpkgsFlake}#nix"
          "${nixpkgsFlake}#cacert"
          (helperFlakeInput "build-flake")
        ];

        # Make sure we have Nix sandboxing on!
        bind_read_only = [
          { "/nix" = "/nix"; }
        ];
      };

      env.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";
    }

    std.postFact

    (std.script "bash" ''
      set -eEuo pipefail

      curl --netrc-optional --netrc-file /secrets/netrc-cicero --fail ''${CICERO_API_URL}/api/fact/${flake-tarball.id}/binary | tar xz

      export NIX_CONFIG="experimental-features = nix-command flakes"
      res=$(build-flake flake)

      echo "\"''${res}\"" | jq  '{ ${builtins.toJSON name}: { success: . } }' > /local/cicero/post-fact/success/fact

      if nix show-config --json | jq -r .substituters.value[] | grep --quiet spongix.service.consul
      then
        # Wait for the path to be available in the cache
        for ((i=0;i<8;i++))
        do
          if nix path-info --store http://spongix.service.consul:7745 "''${res}"
          then
            break
          fi
          let delay=2**i
          echo "''${res} is not yet in the cache, sleeping for ''${delay} seconds" >&2
          sleep "''${delay}"
        done
      fi
    '')
  ];
}
