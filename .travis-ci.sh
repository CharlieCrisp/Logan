# Edit this for your own project dependencies
PURPLE='\033[1;35m'
NC='\033[0m'

OPAM_DEPENDS="ocamlfind ounit re jbuilder ezirmin lwt cohttp cohttp-lwt-unix"
	 
echo "yes" | sudo add-apt-repository ppa:avsm/ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam

export OPAMYES=1
opam init 
opam install ${OPAM_DEPENDS}
eval `opam config env`

echo -e "${PURPLE}Starting Compilation${NC}"
jbuilder build src/Leader/LeaderServer.exe
echo -e "${PURPLE}Completed Compilation${NC}"

# echo -e "${PURPLE}Starting Unit Tests${NC}"
# _build/default/src/Leader/LeaderServer.exe
# echo -e "${PURPLE}Completed Unit Tests${NC}"