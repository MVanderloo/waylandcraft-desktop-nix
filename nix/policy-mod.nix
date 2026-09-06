{
  findutils,
  jdk,
  lib,
  minecraftHome,
  pins,
  stdenvNoCC,
  waylandcraftJar,
}:

let
  minecraftClient = "${minecraftHome}/versions/fabric-${pins.minecraft.version}-${pins.minecraft.fabricLoader}/fabric-${pins.minecraft.version}-${pins.minecraft.fabricLoader}.jar";
  placeholders = {
    fabric = "$" + "{fabric_version}";
    loader = "$" + "{loader_version}";
    minecraft = "$" + "{minecraft_version}";
    version = "$" + "{version}";
    waylandcraft = "$" + "{waylandcraft_version}";
  };
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "waylandcraft-desktop-policy";
  version = pins.policyMod.version;

  src = lib.cleanSource ../policy-mod;

  nativeBuildInputs = [ jdk ];

  buildPhase = ''
    runHook preBuild

    mkdir -p classes resources test-classes
    cp -r src/main/resources/. resources/
    substituteInPlace resources/fabric.mod.json \
      --replace-fail '${placeholders.version}' '${finalAttrs.version}' \
      --replace-fail '${placeholders.minecraft}' '${pins.minecraft.version}' \
      --replace-fail '${placeholders.loader}' '${pins.minecraft.fabricLoader}' \
      --replace-fail '${placeholders.fabric}' '${pins.minecraft.fabricApi}' \
      --replace-fail '${placeholders.waylandcraft}' '${pins.waylandcraft.version}'

    classpath='${waylandcraftJar}:${minecraftClient}'
    while IFS= read -r library; do
      classpath="$classpath:$library"
    done < <(${findutils}/bin/find ${minecraftHome}/libraries \
      -type f -name '*.jar' -print | sort)
    javac --release 25 \
      -classpath "$classpath" \
      -d classes \
      $(${findutils}/bin/find src/main/java -type f -name '*.java' -print | sort)

    javac --release 25 \
      -classpath "$classpath:classes" \
      -d test-classes \
      $(${findutils}/bin/find src/test/java -type f -name '*.java' -print | sort)
    java -ea -classpath "$classpath:classes:test-classes" \
      dev.waylandcraft.desktop.PolicyManifestHarness
    java -ea -classpath "$classpath:classes:test-classes" \
      dev.waylandcraft.desktop.DesktopPolicyHarness
    java -ea -classpath "$classpath:classes:test-classes" \
      dev.waylandcraft.desktop.DesktopPolicyMixinPluginHarness

    jar --create \
      --date=1980-01-01T00:00:02Z \
      --file waylandcraft-desktop-policy-${finalAttrs.version}.jar \
      -C classes . \
      -C resources .

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm444 \
      waylandcraft-desktop-policy-${finalAttrs.version}.jar \
      "$out/share/waylandcraft/mods/waylandcraft-desktop-policy-${finalAttrs.version}.jar"
    runHook postInstall
  '';

  passthru.jarPath = "/share/waylandcraft/mods/waylandcraft-desktop-policy-${finalAttrs.version}.jar";

  meta = {
    description = "Desktop-session policy and global shortcuts for Waylandcraft";
    homepage = "https://github.com/mvanderloo/waylandcraft-desktop-nix";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
  };
})
