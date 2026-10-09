{
  description = "macOS-style per-workspace fullscreen for niri";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
      version = "0.1.0";
    in
    {
      packages = forAllSystems (pkgs:
        let
          fullscreen-niri = pkgs.stdenvNoCC.mkDerivation {
            pname = "fullscreen-niri";
            inherit version;
            src = pkgs.lib.cleanSource ./.;
            nativeBuildInputs = [ pkgs.makeWrapper pkgs.python3 ];
            dontConfigure = true;
            dontBuild = true;
            installPhase = ''
              runHook preInstall
              install -Dm755 fullscreen-niri $out/bin/fullscreen-niri
              patchShebangs $out/bin/fullscreen-niri
              wrapProgram $out/bin/fullscreen-niri \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.niri pkgs.python3 ]}
              runHook postInstall
            '';
            meta = {
              description = "Give each fullscreen window its own niri workspace, macOS style";
              license = pkgs.lib.licenses.mit;
              mainProgram = "fullscreen-niri";
              platforms = pkgs.lib.platforms.linux;
            };
          };
        in
        {
          inherit fullscreen-niri;
          default = fullscreen-niri;
        });

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${self.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/fullscreen-niri";
          meta.description = "macOS-style per-workspace fullscreen for niri";
        };
      });

      overlays.default = final: _prev: {
        fullscreen-niri = self.packages.${final.system}.default;
      };

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [ pkgs.python3 pkgs.niri ];
        };
      });
    };
}
