# Edit this for your own project dependencies
OPAM_DEPENDS="ocamlfind ounit re jbuilder"
	 
echo "yes" | sudo add-apt-repository ppa:avsm/ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam

export OPAMYES=1
opam init 
opam install ${OPAM_DEPENDS}
eval `opam config env`

#ocamlfind list
echo "Starting Compilation"
jbuilder build testfile.exe
echo "Completed Compilation"

echo "Starting Tests"
jbuilder build test/testMain.exe
_build/default/test/testMain.exe
echo "Completed Tests"