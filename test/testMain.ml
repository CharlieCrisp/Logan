open OUnit

let test1 test_ctxt = assert_equal "x" "x";;

(* Name the test cases and group them together *)
let suite = "suite" >::: ["test1">:: test1];;

let _ =
  run_test_tt_main suite
;;