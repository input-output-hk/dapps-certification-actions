{ name, std, nixpkgsFlake, lib, ... }@args: {
  inputs.start = ''
    "dapps-certification/ci": start: {
      clone_url: string
      ref: string
      sha: string
    }
  '';

  job = { start }: let
    cfg = start.value."dapps-certification/ci".start;

    spec.job.dapps-certification = {
      type = "service";
      datacenters = [
        "dc1"
        "eu-central-1"
        "us-east-2"
      ];
      namespace = "marlowe";
      group.dapps-certification = {
        network = {
          mode = "host";
          port.http = {};
        };
        task.dapps-certification = {
          driver = "nix";

          resources = {
            memory = 2048;
            cpu = 300;
          };

          config = {
            packages = [
              "${nixpkgsFlake}#bash"
              "git+${cfg.clone_url}?ref=${cfg.ref}&rev=${cfg.sha}#plutus-certification:exe:plutus-certification"
            ];

            command = [ "/bin/bash" "local/run.bash" ];
          };

          service.dapps-certification = {
            port = "http";
            tags = [
              "dapps-certification"
              "ingress"
              "traefik.enable=true"
              "traefik.http.routers.dapps-certification.rule=Host(`testing.certification.dapps.iog.io`)"
              "traefik.http.routers.dapps-certification.entrypoints=https"
              "traefik.http.routers.dapps-certification.tls=true"
            ];
            check.health = {
              type = "http";
              path = "/version";
              interval = "10s";
              timeout = "2s";
            };
          };

          template = {
            data = ''
              set -eEuo pipefail

              {| range service "cicero" |}
              exec plutus-certification --port $NOMAD_PORT_http --bind $NOMAD_IP_http --cicero-url {| .Address |}:{| .Port |}
              {| end |}
              '';
              # Workaround bug in std.script looking for template vars in the script body
              left_delimiter = "{|";
              right_delimiter = "|}";
            destination = "local/run.bash";
          };
        };
      };
    };
  in std.chain args [
    (std.escapeNames [] [])

    std.singleTask

    {
      resources.memory = 1024;
      config.packages = std.data-merge.append [
        "${nixpkgsFlake}#nomad"
        "${nixpkgsFlake}#cacert"
      ];
    }

    (std.script "bash" ''
      export SSL_CERT_FILE=/etc/ssl/certs/ca-bundle.crt
      echo ${lib.escapeShellArg (builtins.toJSON spec)} > job.json
      nomad run job.json
    '')
  ];
}
