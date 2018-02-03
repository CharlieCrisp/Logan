# Edit this for your own project dependencies
PURPLE='\033[1;35m'
NC='\033[0m'

OPAM_DEPENDS="ocamlfind ounit re jbuilder ezirmin lwt core_extended"
	 
echo "yes" | sudo add-apt-repository ppa:avsm/ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam m4

export OPAMYES=1
opam init 
opam install ${OPAM_DEPENDS}
eval `opam config env`

echo -e "${PURPLE}Starting Compilation${NC}"
make
echo -e "${PURPLE}Completed Compilation${NC}"
