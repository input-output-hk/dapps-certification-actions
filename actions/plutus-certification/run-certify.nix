{ name, std, lib, nixpkgsFlake, ... }@args:
{
  inputs = {
    certify-path = ''
      "plutus-certification/build-flake": success: string // Nix store path
    '';
  };

  outputs = { ... }: {
    failure.${name}.failure = true;
  };

  job = { certify-path }: std.chain args [
    (std.escapeNames [ ] [ ])

    # cicero-pipe needs network access, but would be nice if we could
    # do this for the main task. Perhaps with some nspawn settings?
    # { ${name}.group.${name}.network.mode = "none"; }

    std.singleTask

    { resources.memory = 1024 * 8; }

    {
      config.packages = std.data-merge.append [
        certify-path.value."plutus-certification/build-flake".success
        "${nixpkgsFlake}#util-linux"
        "${nixpkgsFlake}#cacert"
        "${nixpkgsFlake}#jq"
        "github:input-output-hk/cicero-pipe?ref=v1.2.1"
      ];

      config.console = "pipe";

      template = std.data-merge.append [{
        data = ''
          CICERO_PASS="{{with secret "kv/data/cicero/api"}}{{.Data.data.basic}}{{end}}"
        '';
        env = true;
        destination = "secrets/cicero-api-pass.env";
      }];

      env.SSL_CERT_FILE = "/etc/ssl/certs/ca-bundle.crt";

      env.CICERO_USER = "cicero";
    }

    (std.script "bash" ''
      set -eEuo pipefail

      env --ignore-environment \
        unshare --net --setuid=65534 --setgid=65534 \
        certify | tee /dev/fd/2 | \
        jq '{ ${builtins.toJSON name}: { success: . } }' | \
        cicero-pipe --disable-artifacts --run-id "$NOMAD_JOB_ID" --cicero-url https://cicero.infra.aws.iohkdev.io
    '')
  ];
}
