{ lib
, stdenv
, fetchFromGitHub
, go
, rocmPackages
, makeWrapper
,
}:
stdenv.mkDerivation rec {
  pname = "amd-smi-exporter";
  version = "2.0.0";

  src = fetchFromGitHub {
    owner = "amd";
    repo = "amd_smi_exporter";
    rev = "v${version}";
    hash = "sha256-xNHI8iAtiQ34yWN/XNq2O+EYq929UBr9Hp6o3Z/AFLA=";
  };

  nativeBuildInputs = [ go makeWrapper ];

  buildInputs = [ rocmPackages.rocm-smi ];

  # Change to src directory for building
  buildPhase = ''
    runHook preBuild
    cd src

    # Initialize Go module as done in the Makefile
    go mod init src

    # Get dependencies
    go get golang.org/x/exp/slices
    go get github.com/prometheus/client_golang/prometheus
    go get github.com/prometheus/client_golang/prometheus/promauto
    go get github.com/prometheus/client_golang/prometheus/promhttp
    go get github.com/amd/go_amd_smi@master

    # Build the binary
    go build -ldflags="-s -w -X main.version=${version}" -o amd_smi_exporter main.go cpu_data.go

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp src/amd_smi_exporter $out/bin/

    runHook postInstall
  '';

  # Post-install wrapper to ensure ROCm tools are in PATH
  postInstall = ''
    wrapProgram $out/bin/amd_smi_exporter \
      --prefix PATH : ${lib.makeBinPath [rocmPackages.rocm-smi]} \
      --set ROCM_PATH ${rocmPackages.rocm-smi}
  '';

  # Tests require actual AMD hardware
  doCheck = false;

  meta = with lib; {
    description = "AMD SMI Exporter for Prometheus - exports AMD EPYC CPU and Datacenter GPU metrics";
    longDescription = ''
      The AMD SMI Exporter is a standalone application written in GO that exports
      AMD EPYC CPU and Datacenter GPU metrics to a Prometheus server. It uses the
      AMDSMI library for data acquisition and provides comprehensive monitoring
      for AMD hardware including power consumption, temperature, clock frequencies,
      and utilization metrics.
    '';
    homepage = "https://github.com/amd/amd_smi_exporter";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.linux;
    mainProgram = "amd_smi_exporter";
  };
}
