![Travis Build](https://travis-ci.com/CharlieCrisp/PartIIProject.svg?token=jFEDSGqrpzsJd3nc1tVx&branch=master)

# Logan 
Cambridge CST Part II Project - Building a Blockchain Library for OCaml

This project creates a blockchain using Irmin and a leader-based consensus protocol. 

## Building Logan
To build the project, navigate to the root of the repository and type...
```bash
make
```
There are a few helper executables in the `/Code/Tests` directory which can be build with
```bash
make test
``` 
To remove any blockchain or mempool without removing generated executables:
```bash
make clear
```
To remove everything, including executables, logs and blockchains:
```bash
make clean
```

## Setting up Logan
The script `logan` in the `/Utils` directory can be used to access the executables that come with Logan. 
Use `make` and `make test` to build these and then it is recommended that you add the following directories to your path:
```bash
export PATH=$PATH:path-to-repository/bin:path-to-repository/Utils
```
Now you should be able to run `logan --help` to see what subcommands you can run. 
If you are ever unsure of how to use a subcommand, then `logan subcommand --help` should help you out!
