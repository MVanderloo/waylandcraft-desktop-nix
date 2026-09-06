{
  stdenvNoCC,
  cacert,
  jdk,
  lib,
  portablemc,
  pins,
}:

stdenvNoCC.mkDerivation {
  pname = "waylandcraft-minecraft-home";
  version = "${pins.minecraft.version}-fabric-${pins.minecraft.fabricLoader}";

  dontUnpack = true;
  nativeBuildInputs = [ portablemc ];

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "sha256-WV/TyYwk4S9s9jMlUjt/wnzz1vVVwGBKIE8uxw07hoU=";

  meta = {
    description = "Pinned Minecraft and Fabric client asset and library cache";
    homepage = "https://www.minecraft.net/";
    license = lib.licenses.unfreeRedistributable;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [
      binaryBytecode
      binaryNativeCode
    ];
  };

  buildCommand = ''
    export HOME="$TMPDIR/home"
    export XDG_CACHE_HOME="$TMPDIR/cache"
    export SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt
    mkdir -p "$HOME" "$XDG_CACHE_HOME" "$out"

    # PortableMC validates and reuses completed downloads, so retries only
    # request files that a transient Mojang/Fabric CDN failure left missing.
    fetched=
    for attempt in 1 2 3 4 5; do
      if portablemc --main-dir "$out" --output machine start \
        --dry \
        --jvm ${jdk}/bin/java \
        "fabric:${pins.minecraft.version}:${pins.minecraft.fabricLoader}"; then
        fetched=1
        break
      fi
      echo "PortableMC fetch attempt $attempt failed; retrying incomplete files" >&2
    done
    test -n "$fetched"

    rm -f "$out/portablemc_msa.json"
    find "$out" -name '*.lock' -type f -delete
  '';
}
