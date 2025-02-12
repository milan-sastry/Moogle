(* Interfaces and implementations of dictionaries.  A dictionary
 * is used to associate a value with a key.  In our case, we will
 * be using a dictionary to build an index for the web, associating
 * a set of URLs with each word that we find as we crawl the web.
 *)
exception TODO
exception UNEXPECTED_LEAF
exception INVALID_DIRECTION
exception NOT_FOUND

type direction = Left | Mid | Right ;;

module type DICT = 
sig
  type key   
  type value 
  type dict

  (* An empty dictionary *)
  val empty : dict 

  (* Reduce the dictionary using the provided function f and base case u. 
   * Our reducing function f must have the type:
   *      key -> value -> 'a -> 'a
   * and our base case u has type 'a.
   * 
   * If our dictionary is the (key,value) pairs (in any order)
   *      (k1,v1), (k2,v2), (k3,v3), ... (kn,vn)
   * then fold should return:
   *      f k1 v1 (f k2 v2 (f k3 v3 (f ... (f kn vn u))))
   *)
  val fold : (key -> value -> 'a -> 'a) -> 'a -> dict -> 'a

  (* Returns as an option the value associated with the provided key. If
   * the key is not in the dictionary, return None. *)
  val lookup : dict -> key -> value option

  (* Returns true if and only if the key is in the dictionary. *)
  val member : dict -> key -> bool

  (* Inserts a (key,value) pair into our dictionary. If the key is already
   * in our dictionary, update the key to have the new value. *)
  val insert : dict -> key -> value -> dict

  (* Removes the given key from the dictionary. If the key is not present,
   * return the original dictionary. *)
  val remove : dict -> key -> dict

  (* Return an arbitrary key, value pair along with a new dict with that
   * pair removed. Return None if the input dict is empty *)
  val choose : dict -> (key * value * dict) option

  (* functions to convert our types to strings for debugging and logging *)
  val string_of_key: key -> string
  val string_of_value : value -> string
  val string_of_dict : dict -> string

  (* Runs all the tests. see "Testing" in the assignment web page *)
  val run_tests : unit -> unit
end



(* Argument module signature to our DICT functors *)
module type DICT_ARG =
sig
  type key
  type value
  val compare : key -> key -> Order.order
  val string_of_key : key -> string
  val string_of_value : value -> string

  (* Use these functions for testing--see "Testing" in the assignment web page *)

  (* Generate a key. The same key is always returned *)
  val gen_key : unit -> key

  (* Generate a random key. *)
  val gen_key_random : unit -> key

  (* Generates a key greater than the argument. *)
  val gen_key_gt : key -> unit -> key

  (* Generates a key less than the argument. *)
  val gen_key_lt : key -> unit -> key

  (* Generates a key between the two arguments. Return None if no such
   * key exists. *)
  val gen_key_between : key -> key -> unit -> key option

  (* Generates a random value. *)
  val gen_value : unit -> value

  (* Generates a random (key,value) pair *)
  val gen_pair : unit -> key * value
end



(* An example implementation of our DICT_ARG signature. Use this struct
 * for testing. *)
module IntStringDictArg : DICT_ARG =
struct
  open Order
  type key = int
  type value = string
  let compare x y = if x < y then Less else if x > y then Greater else Eq
  let string_of_key = string_of_int
  let string_of_value v = v
  let gen_key () = 0
  let gen_key_gt x () = x + 1
  let gen_key_lt x () = x - 1
  let gen_key_between x y () = 
    let (lower, higher) = (min x y, max x y) in
    if higher - lower < 2 then None else Some (higher - 1)
  let gen_key_random =
    let _ = Random.self_init () in
    (fun () -> Random.int 10000)

  (* returns the nth string in lst, or "cow" n > length of list *)
  let rec lst_n (lst: string list) (n: int) : string =
    match lst with
      | [] -> "cow"
      | hd::tl -> if n = 0 then hd else lst_n tl (n-1)

  (* list of possible values to generate *)
  let possible_values = ["a";"c";"d";"e";"f";"g";"h";"i";"j";"k";"m";"n";
                         "o";"p";"q";"r";"s";"t";"u";"v";"w";"x";"y";"z";
                         "zzzzzz";"cheese";"foo";"bar";"baz";"quux";"42"]
  let num_values = List.length possible_values
  (* gen_value will return the string at this current index *)
  let current_index = ref 0
  let gen_value () =
    let index = !current_index in
    if index >= num_values then
      (current_index := 0; lst_n possible_values index)
    else
      (current_index := index + 1; lst_n possible_values index)
  let gen_pair () = (gen_key_random(), gen_value())
end



(* An association list implementation of our DICT signature. *)
module AssocListDict(D:DICT_ARG) : (DICT with type key = D.key
  with type value = D.value) = 
struct
  open Order
  type key = D.key
  type value = D.value
  type dict = (key * value) list

  (* INVARIANT: sorted by key, no duplicates *)

  let empty = []

  let fold f u = List.fold_left (fun a (k,v) -> f k v a) u

  let rec lookup d k = 
    match d with 
      | [] -> None
      | (k1,v1)::d1 -> 
        (match D.compare k k1 with
          | Eq -> Some v1
          | Greater -> lookup d1 k 
          | _ -> None)

  let member d k = 
    match lookup d k with 
      | None -> false 
      | Some _ -> true

  let rec insert d k v = 
    match d with 
      | [] -> [(k,v)]
      | (k1,v1)::d1 -> 
        (match D.compare k k1 with 
          | Less -> (k,v)::d
          | Eq -> (k,v)::d1
          | Greater -> (k1,v1)::(insert d1 k v))

  let rec remove d k = 
    match d with 
      | [] -> []
      | (k1,v1)::d1 ->
	(match D.compare k k1 with 
          | Eq -> d1
          | Greater -> (k1,v1)::(remove d1 k)
          | _ -> d)
	  
  let choose d = 
    match d with 
      | [] -> None
      | (k,v)::rest -> Some(k,v,rest)

  let string_of_key = D.string_of_key
  let string_of_value = D.string_of_value
  let string_of_dict (d: dict) : string = 
    let f = (fun y (k,v) -> y ^ "\n key: " ^ D.string_of_key k ^ 
      "; value: (" ^ D.string_of_value v ^ ")") in
    List.fold_left f "" d

  (****************************************************************)
  (* Tests for our AssocListDict functor                          *)
  (* These are just examples of tests, your tests should be a lot *)
  (* more thorough than these.                                    *)
  (****************************************************************)

  (* adds a list of (key,value) pairs in left-to-right order *)
  let insert_list (d: dict) (lst: (key * value) list) : dict = 
    List.fold_left (fun r (k,v) -> insert r k v) d lst

  (* adds a list of (key,value) pairs in right-to-left order *)
  let insert_list_reversed (d: dict) (lst: (key * value) list) : dict =
    List.fold_right (fun (k,v) r -> insert r k v) lst d

  (* generates a (key,value) list with n distinct keys in increasing order *)
  let generate_pair_list (size: int) : (key * value) list =
    let rec helper (size: int) (current: key) : (key * value) list =
      if size <= 0 then []
      else 
        let new_current = D.gen_key_gt current () in
        (new_current, D.gen_value()) :: (helper (size - 1) new_current)
    in
    helper size (D.gen_key ())

  (* generates a (key,value) list with keys in random order *)
  let rec generate_random_list (size: int) : (key * value) list =
    if size <= 0 then []
    else 
      (D.gen_key_random(), D.gen_value()) :: (generate_random_list (size - 1))

  let test_insert () =
    let pairs1 = generate_pair_list 26 in
    let d1 = insert_list empty pairs1 in
    List.iter (fun (k,v) -> assert(lookup d1 k = Some v)) pairs1 ;
    ()

  let test_remove () =
    let pairs1 = generate_pair_list 26 in
    let d1 = insert_list empty pairs1 in
    List.iter 
      (fun (k,v) -> 
        let r = remove d1 k in
        List.iter 
          (fun (k2,v2) ->
            if k = k2 then assert(lookup r k2 = None)
            else assert(lookup r k2 = Some v2)
          ) pairs1
      ) pairs1 ;
    ()

  let test_lookup () =
    ()

  let test_choose () =
    ()

  let test_member () =
    ()

  let test_fold () =
    ()

  let run_tests () = 
    test_insert() ;
    test_remove() ;
    test_lookup() ;
    test_choose() ;
    test_member() ;
    test_fold() ;
    ()

end    



(******************************************************************)
(* BTDict: a functor that implements our DICT signature           *)
(* using a balanced tree (2-3 trees)                              *)
(******************************************************************)

module BTDict(D:DICT_ARG) : (DICT with type key = D.key
with type value = D.value) =
struct
  open Order

  type key = D.key
  type value = D.value

  (* A dictionary entry is a (key,value) pair. We compare two (key,value)
   * pairs with the provided key-comparison function D.compare. For example,
   * we may choose to keep a dictionary mapping links to their ranks. In this
   * case, our (key,value) pairs will be (link,rank) pairs, and we compare
   * links using string comparison. *)
  type pair = key * value

  (* Type definition for dictionary, which we choose to represent as a 2-3 Tree.
   * This is almost the same as the binary search tree definition from pset4 and
   * lecture, except we add one more case: a Three-node. 
   *
   * A Three-node contains two pairs and three subtrees: left, middle, and 
   * right, represented by the 3 dicts in the definition below. *)
  type dict = 
    | Leaf
    | Two of dict * pair * dict
    | Three of dict * pair * dict * pair * dict

  (* INVARIANTS: 
   * 2-node: Two(left,(k1,v1),right) 
   * (1) Every key k appearing in subtree left must be k < k1.
   * (2) Every key k appearing in subtree right must be k > k1. 
   * (3) The length of the path from the 2-node to
   *     every leaf in its two subtrees must be the same.  
   * 
   * 3-node: Three(left,(k1,v1),middle,(k2,v2),right) 
   * (1) k1 < k2.
   * (2) Every key k appearing in subtree left must be k < k1. 
   * (3) Every key k appearing in subtree right must be k > k2. 
   * (4) Every key k appearing in subtree middle must be k1 < k < k2.
   * (5) The length of the path from the 3-node to every leaf in its three 
   *     subtrees must be the same. 
   *)


  (* How do we represent an empty dictionary with 2-3 trees? *)
  let empty : dict = Leaf

  (* TODO:
   * Implement fold. Read the specification in the DICT signature above. *)
  let rec fold (f: key -> value -> 'a -> 'a) (u: 'a) (d: dict) : 'a =
    match d with
    | Leaf -> u
    | Two (l, (k, v), r) ->
      let ul = fold f u l in
      let ur = fold f ul r in
      f k v ur
    | Three (l, (k1, v1), m, (k2, v2), r) ->
      let ul = fold f u l in
      let um = fold f ul m in
      let ur = fold f um r in
      f k1 v1 (f k2 v2 ur)

  (* TODO:
   * Implement these to-string functions
   * of_key and of_value are given as anonymous functions to avoid 
   * crashing the program if run while not implemented even if they 
   * are not called (cf of_dict, which is already a function). When 
   * you implement them, you can remove the function wrappers *)
  let string_of_key = D.string_of_key
  let string_of_value = D.string_of_value
      
  (* Debugging function. This will print out the tree in text format.
   * Use this function to see the actual structure of your 2-3 tree. *
   *
   * e.g.      (4,d)   (6,f)
   *         /       |       \
   *      (2,b)    (4,d)     Leaf
   *      /  \     /   \
   *   Leaf  Leaf Leaf  Leaf
   *
   * string_of_tree will output:
   * Three(Two(Leaf,(2,b),Leaf),(4,d),Two(Leaf,(5,e),Leaf),(6,f),Leaf)
   *
   * Note that this tree is NOT balanced, because all the paths from (6,f)
   * to its leaves do NOT all have the same length. *)
  let rec string_of_tree (d: dict) : string = 
    match d with
      | Leaf -> "Leaf"
      | Two(left,(k,v),right) -> "Two(" ^ (string_of_tree left) 
        ^ ",(" ^ (string_of_key k) ^ "," ^ (string_of_value v) ^ "),"
        ^ (string_of_tree right) ^ ")"
      | Three(left,(k1,v1),middle,(k2,v2),right) -> 
        "Three(" ^ (string_of_tree left)
        ^ ",(" ^ (string_of_key k1) ^ "," ^ (string_of_value v1) ^ "),"
        ^ (string_of_tree middle) ^ ",(" ^ (string_of_key k2) ^ "," 
        ^ (string_of_value v2) ^ ")," ^ (string_of_tree right) ^ ")"

  let string_of_dict = string_of_tree

  (* balance a 2-node after one of its children possibly grew. *)
  let balance_2_grow (dir: direction) (grow: bool) (l: dict) (k1: key) 
  (v1: value) (r: dict) : (bool * dict) =
    if not grow then false, Two (l, (k1, v1), r)
    else 
    match dir with
    | Left -> 
      (match l with
      | Two (l', (k1', v1'), r') ->
        false, Three (l', (k1', v1'), r', (k1, v1), r)
      | Three (l', (k1', v1'), m', (k2', v2'), r') -> 
        true, Two (Two (l', (k1', v1'), m'), (k2', v2'), Two (r', (k1, v1), r))
      | Leaf -> raise UNEXPECTED_LEAF)
    | Right ->
      (match r with 
      | Two (l', (k1', v1'), r') ->
        false, Three (l, (k1, v1), l', (k1', v1'), r')
      | Three (l', (k1', v1'), m', (k2', v2'), r') ->
        true, Two (Two (l, (k1, v1), l'), (k1', v1'), Two (m', (k2', v2'), r'))
      | Leaf -> raise UNEXPECTED_LEAF)
    | _ -> raise INVALID_DIRECTION

  (* balance a 3-node after one of its children possibly grew. *)
  let balance_3_grow (dir: direction) (grow: bool) (l: dict) (k1: key)
  (v1: value) (m: dict) (k2: key) (v2: value) (r: dict) : (bool * dict) =
    if not grow then false, Three (l, (k1, v1), m, (k2, v2), r)
    else
    match dir with
    | Left ->
      true, Two (l, (k1, v1), Two (m, (k2, v2), r))
    | Mid ->
      (match m with
      | Two (l', (k1', v1'), r') ->
        true, Two (Two (l, (k1, v1), l'), (k1', v1'), Two (r', (k2, v2), r))
      | Three (l', (k1', v1'), m', (k2', v2'), r') ->
        true, Two (Two (l, (k1', v1'), l'), (k1', v1'), Three (m', (k2', v2'), r', (k2, v2), r))
      | _ -> raise UNEXPECTED_LEAF)
    | Right ->
      true, Two (Two(l, (k1, v1), m), (k2, v2), r)

  (*When insert_to_tree d k v = (grow,d'), that means:
 * d' is a balanced 2-3 tree containing every element of d as well
 * as the element (k,v).  If grow then height(d') = height(d)+1 else
 * height(d') = height(d).
 *)
  let rec insert_to_tree (d: dict) (k: key) (v: value) : (bool * dict) =
    match d with
    | Leaf -> true, Two (Leaf, (k, v), Leaf)
    | Two (Leaf, (k1, v1), Leaf) -> 
      (match D.compare k k1 with
      | Eq -> false, Two (Leaf, (k, v), Leaf)
      | Less -> balance_2_grow Left true (Two(Leaf, (k, v), Leaf)) k1 v1 Leaf
      | Greater -> balance_2_grow Right true (Leaf) k1 v1  (Two(Leaf, (k, v), Leaf)))
    | Three (Leaf, (k1, v1), Leaf, (k2, v2), Leaf) ->
      (match D.compare k k1 with
      | Eq -> false, Three (Leaf, (k, v), Leaf, (k2, v2), Leaf)
      | Less -> balance_3_grow Left true (Two(Leaf, (k, v), Leaf)) k1 v1 (Leaf) k2 v2 Leaf
      | Greater -> 
        (match D.compare k k2 with
        | Less -> balance_3_grow Mid true (Leaf) k1 v1 (Two(Leaf, (k, v), Leaf)) k2 v2 Leaf
        | Eq -> false, Three (Leaf, (k1, v1), Leaf, (k, v), Leaf)
        | Greater -> balance_3_grow Right true (Leaf) k1 v1 (Leaf) k2 v2 (Two(Leaf, (k, v), Leaf))))
    | Two (l, (k1, v1), r) ->
      (match D.compare k k1 with
        | Eq -> false, Two (l, (k1, v), r)
        | Less -> 
          let grow, l' = insert_to_tree l k v in
          balance_2_grow Left grow l' k1 v1 r
        | Greater -> 
          let grow, r' = insert_to_tree r k v in
          balance_2_grow Right grow l k1 v1 r')
    | Three (l, (k1, v1), m, (k2, v2), r) ->
      (match D.compare k k1 with
        | Eq -> false, Three (l, (k, v), m, (k2, v2), r)
        | Less ->
          let grow, l' = insert_to_tree l k v in
          balance_3_grow Left grow l' k1 v1 m k2 v2 r
        | Greater ->
          (match D.compare k k2 with
          | Eq -> false, Three (l, (k1, v1), m, (k, v), r)
          | Less ->
            let grow, m' = insert_to_tree m k v in
            balance_3_grow Mid grow l k1 v1 m' k2 v2 r
          | Greater ->
            let grow, r' = insert_to_tree r k v in
            balance_3_grow Right grow l k1 v1 m k2 v2 r'))

  (* Given a 2-3 tree d, return a new 2-3 tree which
 * additionally contains the pair (k,v)
 * The boolean in insert_to_tree records whether the tree
 * is the same height as the original tree, and is
 * unused here.
 *)
  let insert (d: dict) (k: key) (v: value) : dict =
    snd (insert_to_tree d k v)

  (* balance a 2-node after one of its children possibly shrank.
  dir is the direction of the child that possibly shrank *)
  let balance_2_shrink (dir: direction) (shrink: bool) (l: dict) (k1: key) 
  (v1: value) (r: dict) : (bool * dict) =
  if shrink = false then false, Two (l, (k1, v1), r) 
  else
  match dir with
  | Left ->
    (match r with
    | Two (l', (k1', v1'), r') ->
      true, Three (l, (k1, v1), l', (k1', v1'), r')
    | Three (l', (k1', v1'), m', (k2', v2'), r') ->
      false, Two (Two (l, (k1, v1), l'), (k1', v1'), Two (m', (k2', v2'), r'))
    | _ -> raise UNEXPECTED_LEAF)
  | Right ->
    (match l with
    | Two (l', (k1', v1'), r') ->
      true, Three (l', (k1', v1'), r', (k1, v1), r)
    | Three (l', (k1', v1'), m', (k2', v2'), r') ->
      false, Two (Two (l', (k1', v1'), m'), (k2', v2'), Two (r', (k1, v1), r))
    | _ -> raise UNEXPECTED_LEAF)
  | _ -> raise INVALID_DIRECTION

  (* balance a 3-node after one of its children possibly shrank.
  dir is the direction of the child that possibly shrank *)
  let balance_3_shrink (dir: direction) (shrink: bool) (l: dict) (k1: key)
  (v1: value) (m: dict) (k2: key) (v2: value) (r: dict) =
  if shrink = false then false, Three (l, (k1, v1), m, (k2, v2), r) 
  else
  match dir with
  | Left ->
    (match m with
    | Two (l', (k1', v1'), r') ->
      false, Two (Three (l, (k1, v1), l', (k1', v1'), r'), (k2, v2), r)
    | Three (l', (k1', v1'), m', (k2', v2'), r') ->
      false, Three (Two (l, (k1, v1), l'), (k1', v1'), Two (m', (k2', v2'), r'), (k2, v2), r)
    | _ -> raise UNEXPECTED_LEAF)
  | Mid ->
    (match l with
    | Two (l', (k1', v1'), r') ->
      false, Two (Three (l', (k1', v1'), r', (k1, v1), m), (k2, v2), r)
    | Three (l', (k1', v1'), m', (k2', v2'), r') ->
      false, Three (Two (l', (k1', v1'), m'), (k2', v2'), Two (r', (k1, v1), m), (k2, v2), r)
    | _ -> raise UNEXPECTED_LEAF)
  | Right ->
    (match m with
    | Two (l', (k1', v1'), r') ->
      false, Two (l, (k1, v1), Three (l', (k1', v1'), r', (k2, v2), r))
    | Three (l', (k1', v1'), m', (k2', v2'), r') ->
      false, Three (l, (k1, v1), Two (l', (k1', v1'), m'), (k2', v2'), Two (r', (k2, v2), r))
    | _ -> raise UNEXPECTED_LEAF)

  (* remove leftmost node of a 2-3 tree, returning its (key,value) pair along
  with the updated tree *)
  let rec choose_leftmost (d: dict) : (bool * key * value * dict) =
    match d with
    | Leaf -> raise NOT_FOUND
    | Two (Leaf, (k1, v1), Leaf) -> true, k1, v1, Leaf
    | Three (Leaf, (k1, v1), Leaf, (k2, v2), Leaf) -> 
      false, k1, v1, Two (Leaf, (k2, v2), Leaf)
    | Two (l, (k1, v1), r) ->
      let shrink, k1', v1', l' = choose_leftmost l in
      (match balance_2_shrink Left shrink l' k1 v1 r with
      | (fst, snd) -> fst , k1', v1', snd)
    | Three (l, (k1, v1), m, (k2, v2), r) ->
      let shrink, k1', v1', l' = choose_leftmost l in
      (match balance_3_shrink Left shrink l' k1 v1 m k2 v2 r with
      | (fst, snd) -> fst, k1', v1', snd)

  (* When remove_from_tree d k v = (shrink, d'), that means:
 * if shrink then height(d') = height(d)-1 else height(d') = height(d);
 * and d' is a balanced 2-3 tree containing every element of d except
 * the element (k,v).
 *)
  let rec remove_from_tree (d: dict) (k: key) : (bool * dict) =
    (* go down until you find k *)
    (* once you found k, call choose_leftmost on k's right subtree. use the 
    returned values to 1) update the current k,v, 2) set shrink to the correct
    thing, and 3) replace k's right subtree with the one returned by 
    choose_leftmost. After thatt, return in the callstack and rebalance at
    each level. *)
    match d with
    | Leaf -> false, Leaf
    | Two (Leaf, (k1, v1), Leaf) ->
      (match D.compare k k1 with
      | Eq -> true, Leaf
      | _ -> false, d)
    | Three (Leaf, (k1, v1), Leaf, (k2, v2), Leaf) ->
      (match D.compare k k1 with
      | Eq -> false, Two (Leaf, (k2, v2), Leaf)
      | Less -> false, d
      | Greater ->
        (match D.compare k k2 with
        | Eq -> false, Two (Leaf, (k1, v1), Leaf)
        | _ -> false, d))
    | Two (l, (k1, v1), r) ->
      (match D.compare k k1 with
      | Eq ->
        let shrink, k1', v1', r' = choose_leftmost r in
        balance_2_shrink Right shrink l k1' v1' r'
      | Less -> 
        let shrink, l' = remove_from_tree l k in
        balance_2_shrink Left shrink l' k1 v1 r
      | Greater ->
        let shrink, r' = remove_from_tree r k in
        balance_2_shrink Right shrink l k1 v1 r')
    | Three (l, (k1, v1), m, (k2, v2), r) ->
      (match D.compare k k1 with
      | Eq ->
        let shrink, k1', v1', m' = choose_leftmost m in
        balance_3_shrink Mid shrink l k1' v1' m' k2 v2 r
      | Less ->
        let shrink, l' = remove_from_tree l k in
        balance_3_shrink Left shrink l' k1 v1 m k2 v2 r
      | Greater ->
        (match D.compare k k2 with
        | Eq ->
          let shrink, k2', v2', r' = choose_leftmost r in
          balance_3_shrink Right shrink l k1 v1 m k2' v2' r'
        | Less ->
          let shrink, m' = remove_from_tree m k in
          balance_3_shrink Mid shrink l k1 v1 m' k2 v2 r
        | Greater ->
          let shrink, r' = remove_from_tree r k in
          balance_3_shrink Right shrink l k1 v1 m k2 v2 r'))

(* given a 2-3 tree d, return a 2-3 without element k *)
  let remove (d: dict) (k: key) : dict =
    snd (remove_from_tree d k)

  (* TODO:
   * Write a lookup function that returns the value of the given key
   * in our dictionary and returns it as an option, or return None
   * if the key is not in our dictionary. *)
  let rec lookup (d: dict) (k: key) : value option =
    match d with
    | Leaf -> None
    | Two (l, (k1, v1), r) -> 
      (match D.compare k k1 with
      | Less -> lookup l k
      | Eq -> Some v1
      | Greater -> lookup r k)
    | Three (l, (k1, v1), m, (k2, v2), r) -> 
      (match D.compare k k1 with
      | Less -> lookup l k
      | Eq -> Some v1
      | Greater -> 
        match D.compare k k2 with
        | Less -> lookup m k
        | Eq -> Some v2
        | Greater -> lookup r k)

  (* TODO:
   * Write a height function that takes a dictonary as an argument and
   * returns the distance between the top of the tree and a leaf. A tree
   * consisting of just a leaf should have height 0.*)
  let rec height (d: dict) : int =
    match d with 
    | Leaf -> 0
    | Two (l, _, _) -> height l + 1
    | Three (l, _, _, _, _) -> height l + 1

  (* TODO:
   * Write a function to test whether a given key is in our dictionary *)
  let rec member (d: dict) (k: key) : bool =
    match lookup d k with
    | None -> false
    | Some _ -> true

  (* TODO:
   * Write a function that removes any (key,value) pair from our 
   * dictionary (your choice on which one to remove), and returns
   * as an option this (key,value) pair along with the new dictionary. 
   * If our dictionary is empty, this should return None. *)
  let choose (d: dict) : (key * value * dict) option =
    match d with
    | Leaf -> None
    | _ -> let (_, k, v, d') = choose_leftmost d in
    Some (k, v, d')

  (* TODO:
   * Write a function that when given a 2-3 tree (represented by our
   * dictionary d), returns true if and only if the tree is "balanced", 
   * where balanced means that the given tree satisfies the 2-3 tree
   * invariants stated above and in the 2-3 tree handout. *)

  (* How are you testing that you tree is balanced? 
   * ANSWER: 
   *    Recursively calculate the heights of the left, middle (if applicable),
   *    and right subtrees. If at any point the heights of any two children
   *    are different, return false. Otherwise return true.
   *    Note that every node is accessed once, so complexity is O(n).
   *)
  let rec balanced (d: dict) : bool =
    let rec height_aux (d: dict) : int = 
      match d with
      | Leaf -> 0
      | Two (l, _, r) -> 
        let hl = height_aux l in
        let hr = height_aux r in
        if (hl = hr) && (hl != -1) then hl + 1
        else -1
      | Three (l, _, m, _, r) -> 
        let hl = height_aux l in
        let hm = height_aux m in
        let hr = height_aux r in
        if (hl = hm) && (hl = hr) && (hl != -1) then hl + 1
        else -1
    in
    height_aux d != -1


  (********************************************************************)
  (*       TESTS                                                      *)
  (* You must write more comprehensive tests, using our remove tests  *)
  (* below as an example                                              *)
  (********************************************************************)

  (* adds a list of (key,value) pairs in left-to-right order *)
  let insert_list (d: dict) (lst: (key * value) list) : dict = 
    List.fold_left (fun r (k,v) -> insert r k v) d lst

  (* adds a list of (key,value) pairs in right-to-left order *)
  let insert_list_reversed (d: dict) (lst: (key * value) list) : dict =
    List.fold_right (fun (k,v) r -> insert r k v) lst d

  (* generates a (key,value) list with n distinct keys in increasing order *)
  let generate_pair_list (size: int) : (key * value) list =
    let rec helper (size: int) (current: key) : (key * value) list =
      if size <= 0 then []
      else 
        let new_current = D.gen_key_gt current () in
        (new_current, D.gen_value()) :: (helper (size - 1) new_current)
    in
    helper size (D.gen_key ())

  (* generates a (key,value) list with keys in random order *)
  let rec generate_random_list (size: int) : (key * value) list =
    if size <= 0 then []
    else 
      (D.gen_key_random(), D.gen_value()) :: (generate_random_list (size - 1))


  let test_balance () =
    let d1 = Leaf in
    assert(balanced d1) ;

    let d2 = Two(Leaf,D.gen_pair(),Leaf) in
    assert(balanced d2) ;

    let d3 = Three(Leaf,D.gen_pair(),Leaf,D.gen_pair(),Leaf) in
    assert(balanced d3) ;

    let d4 = Three(Two(Two(Two(Leaf,D.gen_pair(),Leaf),D.gen_pair(),
                           Two(Leaf,D.gen_pair(),Leaf)),
                       D.gen_pair(),Two(Two(Leaf,D.gen_pair(),Leaf),
                                        D.gen_pair(),
                                        Two(Leaf,D.gen_pair(),Leaf))),
                   D.gen_pair(),
                   Two(Two(Two(Leaf,D.gen_pair(),Leaf),D.gen_pair(),
                           Two(Leaf,D.gen_pair(),Leaf)),D.gen_pair(),
                       Two(Two(Leaf,D.gen_pair(),Leaf),D.gen_pair(),
                           Two(Leaf,D.gen_pair(),Leaf))),D.gen_pair(),
                   Two(Two(Two(Leaf,D.gen_pair(),Leaf),D.gen_pair(),
                           Two(Leaf,D.gen_pair(),Leaf)),D.gen_pair(),
                       Three(Two(Leaf,D.gen_pair(),Leaf),D.gen_pair(),
                             Two(Leaf,D.gen_pair(),Leaf),D.gen_pair(),
                             Three(Leaf,D.gen_pair(),Leaf,D.gen_pair(),Leaf))))
    in
    assert(balanced d4) ;

    let d5 = Two(Leaf,D.gen_pair(),Two(Leaf,D.gen_pair(),Leaf)) in
    assert(not (balanced d5)) ;

    let d6 = Three(Leaf,D.gen_pair(),
                   Two(Leaf,D.gen_pair(),Leaf),D.gen_pair(),Leaf) in
    assert(not (balanced d6)) ;

    let d7 = Three(Three(Leaf,D.gen_pair(),Leaf,D.gen_pair(),Leaf),
                   D.gen_pair(),Leaf,D.gen_pair(),Two(Leaf,D.gen_pair(),Leaf))
    in
    assert(not (balanced d7)) ;
    ()


  let test_remove_nothing () =
    let pairs1 = generate_pair_list 26 in
    let d1 = insert_list empty pairs1 in
    assert(balanced d1) ;
    let r2 = remove d1 (D.gen_key_lt (D.gen_key()) ()) in
    List.iter (fun (k,v) -> assert(lookup r2 k = Some v)) pairs1 ;
    assert(balanced r2) ;
    ()

  let test_remove_from_nothing () =
    let d1 = empty in
    let r1 = remove d1 (D.gen_key()) in
    assert(r1 = empty) ;
    assert(balanced r1) ;
    ()

  let test_remove_in_order () =
    let pairs1 = generate_pair_list 26 in
    let d1 = insert_list empty pairs1 in
    assert(balanced d1) ;
    List.iter 
      (fun (k,v) -> 
        let r = remove d1 k in
        let _ = List.iter 
          (fun (k2,v2) ->
            if k = k2 then assert(lookup r k2 = None)
            else assert(lookup r k2 = Some v2)
          ) pairs1 in
        assert(balanced r)
      ) pairs1 ;
    ()

  let test_remove_reverse_order () =
    let pairs1 = generate_pair_list 26 in
    let d1 = insert_list_reversed empty pairs1 in
    assert(balanced d1) ;
    List.iter 
      (fun (k,v) -> 
        let r = remove d1 k in
        let _ = List.iter 
          (fun (k2,v2) ->
            if k = k2 then assert(lookup r k2 = None)
            else assert(lookup r k2 = Some v2)
          ) pairs1 in
        assert(balanced r)
      ) pairs1 ;
    ()

  let test_remove_random_order () =
    let pairs5 = generate_random_list 100 in
    let d5 = insert_list empty pairs5 in
    assert(balanced d5) ;
    let r5 = List.fold_right (fun (k,_) d -> remove d k) pairs5 d5 in
    List.iter (fun (k,_) -> assert(not (member r5 k))) pairs5 ;
    assert(r5 = empty) ;
    assert(balanced r5) ;
    ()

  let test_insert_single_pair () =
    let k = D.gen_key () in
    let v = D.gen_value () in
    let d = empty in
    let d' = insert d k v in
    assert(lookup d' k = Some v);
    assert(balanced d');
    assert(height d' = 1);
    ()
  
  let test_lookup_empty_tree () =
    let k = D.gen_key () in
    let d = empty in
    assert(lookup d k = None);
    ()
  
  let test_member_empty_tree () =
    let k = D.gen_key () in
    let d = empty in
    assert(not (member d k));
    ()
  
  let test_insert_list () =
    let pairs = generate_pair_list 10 in
    let d = insert_list empty pairs in
    List.iter (fun (k, v) -> assert(lookup d k = Some v)) pairs;
    assert(balanced d);
    ()
  
  let test_choose_empty_tree () =
    let d = empty in
    assert(choose d = None);
    ()
  
  let test_choose () =
    let pairs = generate_pair_list 10 in
    let d = insert_list empty pairs in
    match choose d with
    | Some (k, v, d') ->
        assert(lookup d' k = None);
        assert(balanced d');
    | None -> 
    ()
  
  let test_height () =
    let d = empty in
    assert(height d = 0);
    let pairs = generate_pair_list 10 in
    let d = insert_list empty pairs in
    let expected_height = 3 in
    assert(height d = expected_height);
    ()
  
  let test_member () =
    let pairs = generate_pair_list 10 in
    let d = insert_list empty pairs in
    List.iter (fun (k, _) -> assert(member d k)) pairs;
    let k = D.gen_key_lt (fst (List.hd pairs)) () in
    assert(not (member d k));
    ()
  
  let test_lookup () =
    let pairs = generate_pair_list 10 in
    let d = insert_list empty pairs in
    List.iter (fun (k, v) -> assert(lookup d k = Some v)) pairs;
    let k = D.gen_key_lt (fst (List.hd pairs)) () in
    assert(lookup d k = None);
    ()

  let run_tests () = 
    test_balance();
    test_remove_nothing();
    test_remove_from_nothing();
    test_remove_in_order();
    test_remove_reverse_order();
    test_remove_random_order();
    test_insert_single_pair();
    test_lookup_empty_tree();
    test_member_empty_tree();
    test_insert_list();
    test_choose_empty_tree();
    test_choose();
    test_height();
    test_member();
    test_lookup();
    ()

end




(******************************************************************)
(* Run our tests.                                                 *)
(******************************************************************)

(* Create a dictionary mapping ints to strings using our 
 * AssocListDict functor and run the tests *)
module IntStringListDict = AssocListDict(IntStringDictArg) ;;
IntStringListDict.run_tests();;

(* Create a dictionary mapping ints to strings using our 
 * BTDict functor and run the tests.
 * 
 * Uncomment out the lines below when you are ready to test your
 * 2-3 tree implementation. *)

module IntStringBTDict = BTDict(IntStringDictArg) ;;
IntStringBTDict.run_tests();;




(******************************************************************)
(* Make: a functor that creates a DICT by calling our             *)
(* AssocListDict or BTDict functors                               *)
(******************************************************************)
module Make (D:DICT_ARG) : (DICT with type key = D.key
  with type value = D.value) = 
  (* Change this line to the BTDict implementation when you are
   * done implementing your 2-3 trees. *)
  (* AssocListDict(D) *)
  BTDict(D)

