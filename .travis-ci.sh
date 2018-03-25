# Edit this for your own project dependencies
PURPLE='\033[1;35m'
NC='\033[0m'

OPAM_DEPENDS="ocamlfind ounit re=1.7.1 cppo=1.6.2 jbuilder=1.0+beta17 lwt=3.2.1 conduit=0.15.4 core=v0.9.2 core_extended=v0.9.1 ezirmin=0.2.1 git-unix=1.7.1 ppx_tools_versioned=5.0.1"
	 
echo "yes" | sudo add-apt-repository ppa:avsm/ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam m4

export OPAMYES=1
opam init 
opam switch 4.05.0
opam install ${OPAM_DEPENDS}
eval `opam config env`

echo -e "${PURPLE}Starting Compilation${NC}"
make
echo -e "${PURPLE}Completed Compilation${NC}"
