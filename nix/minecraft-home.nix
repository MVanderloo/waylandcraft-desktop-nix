{
  stdenvNoCC,
  cacert,
  fetchurl,
  jdk,
  lib,
  portablemc,
  pins,
}:

let
  fabricVersion = "fabric-${pins.minecraft.version}-${pins.minecraft.fabricLoader}";
  fabricProfile = builtins.fromJSON (builtins.readFile ./fabric-profile.json);
  minecraftManifest = fetchurl {
    inherit (pins.minecraft.manifest) url hash;
  };
in
assert fabricProfile.id == fabricVersion;
assert fabricProfile.inheritsFrom == pins.minecraft.version;
assert lib.any (
  library: library.name == "net.fabricmc:fabric-loader:${pins.minecraft.fabricLoader}"
) fabricProfile.libraries;
stdenvNoCC.mkDerivation {
  pname = "waylandcraft-minecraft-home";
  version = "${pins.minecraft.version}-fabric-${pins.minecraft.fabricLoader}";

  dontUnpack = true;
  nativeBuildInputs = [ portablemc ];

  outputHashMode = "recursive";
  outputHashAlgo = "sha256";
  outputHash = "sha256-txM/2iwNV8mKF/LvTy9a1+fe+UFerICWdr7EF4OZ5Is=";

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

    # Both upstream APIs can change metadata for an existing release.
    # Seed reviewed manifests and prevent PortableMC from refreshing them.
    mkdir -p "$out/versions/${pins.minecraft.version}" "$out/versions/${fabricVersion}"
    cp ${minecraftManifest} "$out/versions/${pins.minecraft.version}/${pins.minecraft.version}.json"
    cp ${./fabric-profile.json} "$out/versions/${fabricVersion}/${fabricVersion}.json"

    # PortableMC validates and reuses completed downloads, so retries only
    # request files that a transient Mojang/Fabric CDN failure left missing.
    # Native extraction uses a per-run directory name. Keep it outside the
    # fixed output so identical downloads produce an identical NAR hash.
    fetched=
    for attempt in 1 2 3 4 5; do
      if portablemc --main-dir "$out" --output machine start \
        --dry \
        --fetch-exclude-all \
        --bin-dir "$TMPDIR/bin" \
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
