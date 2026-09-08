{
  nixpkgs = {
    revision = "17de0b976395537756f30a3e78f2f06e5cec89ed";
  };

  minecraft = {
    version = "26.1.2";
    # Mojang updates release metadata (including asset indexes) in place.
    # Use the content-addressed manifest instead of resolving the version.
    manifest = {
      url = "https://piston-meta.mojang.com/v1/packages/6a52e36bc9bf022a2eddb907dc4e725d87f33e4f/26.1.2.json";
      hash = "sha256-aO0So85yep6BkwG79XkrwnnC93KDQrCasiNbAY+CWg8=";
    };
    fabricLoader = "0.19.2";
    fabricApi = "0.147.0+26.1.2";
    sodium = "0.8.12+mc26.1.2";
  };

  runtime = {
    jdk = "25.0.4.1+1";
    portablemc = "5.0.3";
    cage = "0.3.1";
    xwaylandSatellite = "0.8.2";
    xwayland = "24.1.13";
    libxkbcommon = "1.13.2";
    wayland = "1.26.0";
    libdrm = "2.4.134";
    mesa = "26.2.2";
  };

  policyMod = {
    version = "0.3.0";
  };

  waylandcraft = {
    version = "2.0.3";
    url = "https://github.com/EVV1E/waylandcraft/releases/download/v2.0.3/waylandcraft-v2.0.3.jar";
    hash = "sha256-AZqND5MPLi4WUf0juLm1ch2q+d43psM9leb17PjG4VY=";
  };

  fabricApi = {
    url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/dZsorAUN/fabric-api-0.147.0%2B26.1.2.jar";
    hash = "sha512-fjwF394NLFXRTvaOQDisHTM17Ujfyk28+ym4c9aYrgaevYXyR9igtIQ35IRCJUmhf/XLv+c00VkVPDvA4AN0Fw==";
  };

  sodium = {
    url = "https://cdn.modrinth.com/data/AANobbMI/versions/eRJU33Hp/sodium-fabric-0.8.12%2Bmc26.1.2.jar";
    hash = "sha512-QCu5RdH4k6csFSwTfgj4oMBF1yWk1soq97z+kpxNgDONpQkJTP46jNFiNGt4xQadw88dV7+UobzlV/ZCXafnbw==";
  };
}
