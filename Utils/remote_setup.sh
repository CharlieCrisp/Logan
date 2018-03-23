# Edit this for your own project dependencies
PURPLE='\033[1;35m'
NC='\033[0m'

OPAM_DEPENDS="ocamlfind ounit re=1.7.1 cppo=1.6.2 jbuilder=1.0+beta17 lwt core"
	 
echo "yes" | sudo add-apt-repository ppa:avsm/ppa
sudo apt-get update -qq
sudo apt-get install -qq ocaml ocaml-native-compilers camlp4-extra opam m4 zlib1g-dev libgmp-dev bash-completion

export OPAMYES=1
opam init 
opam switch 4.05.0
opam install ${OPAM_DEPENDS}
eval `opam config env`

if [ ! -f ~/.bash_profile ]; then
    echo "eval `opam config env`" > ~/.bash_profile
fi

# If ~./inputrc doesn't exist yet, first include the original /etc/inputrc so we don't override it
if [ ! -a ~/.inputrc ]; then echo '$include /etc/inputrc' > ~/.inputrc; fi

# Add option to ~/.inputrc to enable case-insensitive tab completion
echo 'set completion-ignore-case On' >> ~/.inputrc
export PATH=$PATH:~/PartIIProject/bin
