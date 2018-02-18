![Travis Build](https://travis-ci.com/CharlieCrisp/PartIIProject.svg?token=jFEDSGqrpzsJd3nc1tVx&branch=master)

# PartIIProject 
Cambridge CST Part II Project - Building a Blockchain Library for OCaml

This project creates a blockchain using Irmin and a leader-based consensus protocol. 

## Building the project
To build the project, navigate to the root of the repository and type...
```bash
make
```
...and to rebuild the project, type...
```bash
make flush
```

## Running the example
In the `/Examples` directory, is a sample program which will run a blockchain leader. The executable takes a list of remote addresses on the the command line, of the form `user@host`. The leader will then pull and merge any updates made on these 'workers'. A typical command would be...
```bash
_build/default/src/Examples/LeaderDemo.exe user1@host1 user2@host2
```

There is also a corresponding demo to run the workers. The program accepts the location of the leader on the command line. For example...
```bash
_build/default/src/Examples/ParticipantDemo.exe -r leaderuser@leaderhost
```

## Setup scripts
There are a couple of scripts to help with setting up machines.
To set up a remote machine, type...
```bash
bash src/Utils/remote_setup.sh
```

To sync a participants mempool with the leader's, before running a participant, type...
```bash
bash src/Utils/sync_git.sh
```
