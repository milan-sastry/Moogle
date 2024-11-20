open Util ;;    
open CrawlerServices ;;
open Order ;;
open Nodescore ;;
open Graph ;;


(* Dictionaries mapping links to their ranks. Higher is better. *)
module RankDict = Dict.Make(
  struct 
    type key = link
    type value = float
    let compare = link_compare
    let string_of_key = string_of_link
    let string_of_value = string_of_float
    let gen_key () = {host=""; port=0; path=""}
    let gen_key_gt x () = gen_key ()
    let gen_key_lt x () = gen_key ()
    let gen_key_random () = gen_key ()
    let gen_key_between x y () = None
    let gen_value () = 0.0
    let gen_pair () = (gen_key(),gen_value())
  end)

module PageSet = Myset.Make(
  struct 
    type t = page
    let compare = (fun a b -> link_compare (a.url) (b.url))
    let string_of_t = string_of_page
    let gen () = {url={host=""; port=0; path=""}; links=[]; words=[]}
    let gen_lt x () = gen ()
    let gen_gt y () = gen ()
    let gen_random () = gen ()
    let gen_between x y () = None
  end)

module LinkSet = Myset.Make(
  struct 
    type t = link
    let compare = link_compare
    let string_of_t = string_of_link
    let gen () = {host=""; port=0; path=""}
    let gen_lt x () = gen ()
    let gen_gt y () = gen ()
    let gen_random () = gen ()
    let gen_between x y () = None
  end)

module PageGraph = Graph (
  struct
    type node = link
    let compare = link_compare
    let string_of_node = string_of_link
    let gen () = {host=""; port=0; path=""}
  end)

module PageScore = NodeScore (
  struct
    type node = link
    let string_of_node = string_of_link
    let compare = link_compare
    let gen () = {host=""; port=0; path=""}
  end)

(* Given a bunch of pages, convert them to a graph *)
let graph_of_pages (pages : PageSet.set) : PageGraph.graph =
  (* Only want graph nodes for pages we actually crawled *)
  let crawled_links = 
    PageSet.fold (fun page s -> LinkSet.insert page.url s)
      LinkSet.empty pages 
  in
  let add_links page graph =
    let add_link g dst =
      if LinkSet.member crawled_links dst then
        PageGraph.add_edge g page.url dst
      else g 
    in
      List.fold_left add_link graph page.links
  in
    PageSet.fold add_links PageGraph.empty pages
      
(* The rest of the world wants a RankDict, not a NodeScore. *)

let dict_of_ns (ns : PageScore.node_score_map) : RankDict.dict =
  PageScore.fold (fun node score r -> RankDict.insert r node score) 
    RankDict.empty ns

(* A type for modules that can compute nodescores from graphs *)
module type RANKER = 
sig
  module G: GRAPH
  module NS: NODE_SCORE
  val rank : G.graph -> NS.node_score_map
end


(* Each node's rank is equal to the number of pages that link to it. *)
module InDegreeRanker  (GA: GRAPH) (NSA: NODE_SCORE with module N = GA.N) : 
  (RANKER with module G = GA with module NS = NSA) =
struct
  module G = GA
  module NS = NSA
  let rank (g : G.graph) = 
    let add_node_edges ns node =
      let neighbors = match G.neighbors g node with
        | None -> []
        | Some xs -> xs
      in
        List.fold_left (fun ns' neighbor -> NS.add_score ns' neighbor 1.0) 
          ns neighbors 
    in
    let nodes = (G.nodes g) in
      List.fold_left add_node_edges (NS.zero_node_score_map nodes) nodes
end



(*****************************************************************)
(* Eigenvalue Ranker                                            *)
(*****************************************************************)


module type WALK_PARAMS =
sig
  (* Should we randomly jump somewhere else occasionally? 
    if no, this should be None.  Else it should be the probability of 
    jumping on each step *)
  val do_random_jumps : float option
end

module EigenvalueRanker (GA: GRAPH) (NSA: NODE_SCORE with module N = GA.N) 
  (P : WALK_PARAMS) : 
  (RANKER with module G = GA with module NS = NSA) =
struct
  module G = GA
  module NS = NSA

  let dot_product v1 v2 = 
    List.fold_left2 (fun acc x y -> acc +. (x *. y)) 0. v1 v2
  
  (* let _ = Printf.printf "dot_product: %f\n" (dot_product [1.0;2.0;3.0] [4.0;5.0;6.0]) *)
  
  let multiply (v:float list) (m:float list list) =
    List.map (fun row -> dot_product v row) m
  
  let print_float_list lst =
        let rec aux = function
          | [] -> ()
          | [x] -> Printf.printf "%f\n" x
          | x :: xs -> Printf.printf "%f; " x; aux xs
        in
        Printf.printf "[";
        aux lst;
        Printf.printf "]\n"
  
  let print_matrix matrix =
    List.iter (fun row -> print_float_list row) matrix
    
  let transpose matrix =
    let rec aux acc = function
      | [] -> List.rev acc
      | [] :: _ -> List.rev acc
      | matrix -> aux (List.map List.hd matrix :: acc) (List.map List.tl matrix)
    in
    aux [] matrix

  let rank (g : G.graph) =
    let d = 
      match P.do_random_jumps with
        | None -> 0.0
        | Some x -> x
    in

    let nodes = (G.nodes g) in

    let n = (List.length nodes) in

    let link_matrix = 
      transpose (List.rev (List.map (fun node -> 
        let edges = 
          match G.outgoing_edges g node with 
          | None -> []
          | Some xs -> xs
        in
        (* if no links, treat as if links to all *)
        if edges = [] then 
          List.init n (fun _ -> 1.0 /. float_of_int n)
        else 
          (* each outgoing link gets 1/(num of outgoing links) *)
          List.rev (List.map (fun node2 -> 
            if (List.mem (node,node2) edges) then 
              1.0 /. float_of_int (List.length edges)
            else
              0.0) nodes)
        ) nodes))
    in

    (* let _ = print_matrix link_matrix in *)

    let unit_vector = List.init n (fun _ -> 1.0) in
    
    let r_0 = List.init n (fun _ -> 1.0 /. float_of_int n) in

    let find_next_r r_last = 
      (* (d/N)U *)
      let random_jumps = List.map (fun x -> x *. (d /. float_of_int n)) unit_vector in
      (* (1-d)LRₖ *)
      let link = 
        List.map (fun x -> x *. (1.0 -. d)) (multiply r_last (link_matrix)) in
      
      List.map2 (fun x y -> x +. y) random_jumps link in
    
    (* calculates next rank vector step and checks for convergence *)
    let rec iterate r_last = 
      let r = find_next_r r_last in
      let has_converged =
        let vector_distance v1 v2 = 
          List.fold_left2 (fun acc x y -> acc +. ((x -. y) ** 2.0)) 0.0 v1 v2 in
        let square_magnitude = 
          dot_product r_last r_last in
        (vector_distance r r_last) < (0.0001 *. square_magnitude)
        in
      (* let _ = Printf.printf "%b\n" has_converged in *)
      (* let _ = print_float_list r in *)
      if has_converged then r else iterate r
    in

    (* updates score map with final rank vector *)
    let final_r = List.rev (iterate r_0) in
    let score_map = List.fold_left2 (fun ns node score -> NS.set_score ns node score) 
      (NS.zero_node_score_map nodes) nodes final_r in
    NS.normalize score_map
end

(*******************  TESTS BELOW  *******************)

module TestInDegreeRanker =
struct 
  module G = NamedGraph
  let g = G.add_edge G.empty "a" "b";;
  let g2 = G.add_edge g "a" "c";;
  
  module NS = NodeScore (struct
                           type node = string 
                           let compare = string_compare
                           let string_of_node = fun x -> x
                           let gen () = ""
                         end);;

  module Ranker = InDegreeRanker (G) (NS);;
  let ns = Ranker.rank g2;;
  (* let _ = Printf.printf "NS: %s\n" (NS.string_of_node_score_map ns) ;; *)
  assert ((NS.get_score ns "a") = Some 0.0);;
  assert ((NS.get_score ns "b") = Some 1.0);;
  assert ((NS.get_score ns "c") = Some 1.0);;
  assert ((NS.get_score ns "d") = None);;

  let g3 = G.add_edge g2 "b" "c";;
  let ns2 = Ranker.rank g3;;
  assert ((NS.get_score ns2 "a") = Some 0.0);;
  assert ((NS.get_score ns2 "b") = Some 1.0);;
  assert ((NS.get_score ns2 "c") = Some 2.0);;

end


module TestEigenvalueRanker =
struct 
  module G = NamedGraph
  let g = G.from_edges  [
    ("a","b");("b","c");("b","a");("c","d");("d","a")
  ]

                       
  module NS = NodeScore (struct
                           type node = string 
                           let compare = string_compare
                           let string_of_node = fun x -> x
                           let gen () = ""
                         end);;

  module Ranker = EigenvalueRanker (G) (NS) 
    (struct
       let do_random_jumps = Some 0.0
     end)

  let ns = Ranker.rank g
  let _ = Printf.printf "Testing EigenvalueRanker:\n NS: %s\n" 
    (NS.string_of_node_score_map ns) 

  let () =
    assert ((NS.get_score ns "a") = Some 0.333984375);
    assert ((NS.get_score ns "b") = Some 0.33203125);
    assert ((NS.get_score ns "c") = Some 0.166015625);
    assert ((NS.get_score ns "d") = Some 0.16796875);
    assert ((NS.get_score ns "e") = None);
    Printf.printf "All tests passed!\n"

  (* let _ = Printf.printf "%s" (G.string_of_graph g) *)
  
end



