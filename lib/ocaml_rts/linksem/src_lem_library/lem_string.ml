(*Generated by Lem from string.lem.*)


open Lem_bool
open Lem_basic_classes
open Lem_list
open Xstring

(* ------------------------------------------- *)
(* translations between strings and char lists *)
(* ------------------------------------------- *)

(*val toCharList : string -> list char*)

(*val toString : list char -> string*)


(* ----------------------- *)
(* generating strings      *)
(* ----------------------- *)

(*val makeString : nat -> char -> string*)
(*let makeString len c = toString (replicate len c)*)

(* ----------------------- *)
(* length                  *)
(* ----------------------- *)

(*val stringLength : string -> nat*)

(* ----------------------- *)
(* string concatenation    *)
(* ----------------------- *)

(*val ^ [stringAppend] : string -> string -> string*)


(* ----------------------------*)
(* setting up pattern matching *)
(* --------------------------- *)

(*val string_case : forall 'a. string -> 'a -> (char -> string -> 'a) -> 'a*)

(*let string_case s c_empty c_cons = 
  match (toCharList s) with
    | [] -> c_empty
    | c :: cs -> c_cons c (toString cs)
  end*)

(*val empty_string : string*)

(*val cons_string : char -> string -> string*)
