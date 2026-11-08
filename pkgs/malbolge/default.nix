{ stdenv, lib }:

# ben olmstead's 1998 reference malbolge interpreter (public domain).
# bounded 3^10-cell machine, so not turing complete; standard esolang variant.
stdenv.mkDerivation {
  pname = "malbolge";
  version = "1.0";

  src = ./.;

  # -w: the reference source triggers a maybe-uninitialized warning on 'x'
  # under the '\n' == 10 path (all such branches compile out on linux).
  buildPhase = ''
    $CC -O2 -w -o malbolge malbolge.c
  '';

  installPhase = ''
    install -Dm755 malbolge $out/bin/malbolge
  '';

  meta = with lib; {
    description = "Reference interpreter for the Malbolge esoteric language";
    homepage = "https://esolangs.org/wiki/Malbolge";
    license = licenses.publicDomain;
    platforms = platforms.all;
    mainProgram = "malbolge";
  };
}
