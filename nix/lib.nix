let
  pins = import ./pins.nix;
in
{
  inherit pins;
  inherit (pins)
    minecraft
    nixpkgs
    policyMod
    runtime
    waylandcraft
    ;

}
