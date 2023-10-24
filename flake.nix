{
  description = "An environment for building a compiling typst documents with vscode, typst, and typst-lsp";

  # Nixpkgs / NixOS version to use.
  inputs.nixpkgs.url = "nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let

      # to work with older version of flakes
      lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";

      # Generate a user-friendly version number.
      version = builtins.substring 0 8 lastModifiedDate;

      # System types to support.
      supportedSystems = [ "x86_64-linux" "x86_64-darwin" "aarch64-linux" "aarch64-darwin" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; });

    in rec
    {

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        let
          pkgs = nixpkgsFor.${system};
        in
        {
          # grab the font
          atkinson = pkgs.stdenv.mkDerivation {
            buildInputs = with pkgs; [unzip];
            name = "atkinson";
            # https://brailleinstitute.org/wp-content/uploads/atkinson-hyperlegible-font/Atkinson-Hyperlegible-Font-Print-and-Web-2020-0514.zip
            src = builtins.fetchurl { 
              url ="https://brailleinstitute.org/wp-content/uploads/atkinson-hyperlegible-font/Atkinson-Hyperlegible-Font-Print-and-Web-2020-0514.zip";
              sha256 ="sha256:1qskrsxlck1b3g4sjphmyq723fjspw3qm58yg59q5p6s7pana6ly";
            };

            phases = ["unpackPhase" "installPhase"];
            unpackPhase = "mkdir extract && unzip -d extract/ $src";
            installPhase = "ls extract/ && mkdir -p $out/share/fonts && cp -R extract/Atkinson-Hyperlegible-Font-Print-and-Web-2020-0514/Web\\ Fonts/TTF $out/share/fonts";

          };
        # maybe I could use this to build the PDF?? not sure.
        
      });
      
      # Add dependencies that are only needed for development
      devShells = forAllSystems (system:
        let 
          pkgs = nixpkgsFor.${system};
        in
        {
          ci = pkgs.mkShell { 
            buildInputs = with pkgs; [typst packages.${system}.atkinson];

            shellHook = "
            export TYPST_FONT_PATHS=\"${packages.${system}.atkinson}/share/fonts/TTF\"
            ";

          };
          default = pkgs.mkShell {
            # typst for compilation.
            # starship for 
            buildInputs = with pkgs; [ typst starship watchexec ];

            shellHook = "
              eval \"$(starship init bash)\";
            ";
          };

          full = pkgs.mkShell {
            # typst for compilation.
            # starship for nice shells
            buildInputs = with pkgs; [ typst starship watchexec packages.${system}.atkinson ] ++ [(vscode-with-extensions.override {
                vscode = vscodium;
                vscodeExtensions = with vscode-extensions; [
                  nvarner.typst-lsp bbenoist.nix tomoki1207.pdf
                ];
                })
            ];

            shellHook = "
              eval \"$(starship init bash)\";
              export TYPST_FONT_PATHS=\"${packages.${system}.atkinson}/share/fonts/TTF\"
            ";
          };

      });
      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.

      # we might have a default later, but not right now. 
      # defaultPackage = forAllSystems (system: self.packages.${system}.go-hello);
    };
}
