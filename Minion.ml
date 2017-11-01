open Printf
type minion = 
  { 
    name : string;
    age : int;
    favouriteColor: string;
  }
module MinionFuncs = struct 
  (*This is a use of pattern matching*)
  let printMinion { 
                    name = n;
                    age = a;
                    favouriteColor = fc;
                  } = 
      printf "Name : %s, age: %s, favourite colour: %s\n" n (string_of_int a) fc
  end