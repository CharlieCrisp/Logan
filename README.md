[![Build Status](https://travis-ci.com/CharlieCrisp/Logan.svg?token=jFEDSGqrpzsJd3nc1tVx&branch=master)](https://travis-ci.com/CharlieCrisp/Logan)

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

## Using a Config File
In order to save time, you can set up a config file in whatever directory you run in with the following contents 
```bash
user=user@host #Your machine in the format user@host
leader=leaderuser@leaderhost #Leader machine in the format user@host
id=5 #Your machnine id - an integer
participants=(user1@host1 user@host2)#list of participants in the format user@host. Must go within brackets separated by spaces
```