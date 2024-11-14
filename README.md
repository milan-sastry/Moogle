# Assignment 5: Moogle

You may do this assignment in pairs. See the bottom of this document for the
restrictions that apply to pair programming, which may diverge from the default
COS126 collaboration policies.

## Objectives

The goal of this assignment is to build a small web search engine called
**Moogle**. This is really your first (somewhat) large-scale development project
in OCaml. In completing this assignment, you will demonstrate your understanding
of OCaml's module system. You are encouraged to work in pairs for this problem
set.

Your job is to implement some key components of Moogle, including efficient
abstractions for sets and dictionaries and the basic crawler that constructs the
web index. You will also implement a page-rank algorithm that can be used to
sort the links returned from a query so that more "important" links are returned
first.

The na&iuml;ve implementations of sets and dictionaries we provide won't scale
very well, so we're asking you to produce better implementations based on
balanced trees.

## Getting Started

To get started, run

```
git submodule update --init
```

from your Git root directory to fetch data files needed to complete this
assignment.

Within this repository, you will find a `Makefile` and a set of `.ml` files that
make up the project sources. Below is a brief description of the contents of
each file:
- `Makefile`: used to build the project&mdash;type `make all` at the command
    line to build the project.
- `order.ml`: definitions for an `order` datatype used to compare values.
- `myset.ml`: an interface and simple implementation of a set abstract datatype.
- `dict.ml`: an interface and simple implementation of a dictionary abstract
    datatype.
- `query.ml`: a datatype for Moogle queries and a function for evaluating a
    query given a web index.
- `util.ml`: includes an interface and the implementation of crawler services
    needed to build the web index. This includes definitions of link and page
    datatypes, a function for fetching a page given a link, and the values of
    the command line arguments (e.g., the initial link, the number of pages to
    search, and the server port.)
- `moogle.ml`: the main code for the Moogle server.
- `crawl.ml`: includes a stub for the crawler that you will need to complete.
- `graph.ml`: definitions for a graph abstract data type, including a graph
    signature, a node signature, and a functor for building graphs from a node
    module.
- `nodescore.ml`: definitions for node scores maps, which as part of the page-
    rank algorithm.
- `pagerank.ml`: skeleton code for the page-rank algorithm including a dummy
    indegree algorithm for computing page ranks. You will be editing this.
- `signature.txt`: You will record your sources here.

You will also find three directories of web pages that you can use for testing:
`data/simple-html`, `data/html`, and `data/wiki`, as described below.

## Testing

Testing for your functors will be required. All the functors you write will have
a `run_tests : unit -> unit` function. See the examples of tests in `dict.ml`
(the tests for `remove`), and see how to run them by scrolling to the very
bottom of `dict.ml`.

In addition to writing unit tests, we have provided three sample dumps of
webpages to test your crawler.
- `data/simple-html`: a directory containing a small list (7 pages) of pages to
    test your crawler.
- `data/html`: a directory containing the Ocaml manual (20 HTML pages).
- `data/wiki`: a larger set of pages you can use to test the performance of your
    final implementation. These pages have been scraped from Wikipedia, using
    `https://en.wikipedia.org/wiki/Teenage_Mutant_Ninja_Turtles` as our start
    point.

    Note: Even with optimized dictionaries and sets, indexing all the pages in
    the `data/wiki` directory may take several minutes. (But search is near
    instantaneous, which is the way Google would want it! We'll talk about how
    to parallelize web indexing in future classes.)

## Style

You must follow the proper style guide as mentioned in precept, previous
assignment comments, and in the online style guides
[here](https://www.cs.princeton.edu/courses/archive/fall23/cos326/style.php).

## Words of Warning

This project is significantly more difficult than previous problem sets because
you need to read and understand all of the code that we have given you, as well
as write new code. We HIGHLY recommend you start as early as possible. This is
not the kind of problem set you can expect to complete last minute.

As a warning, you shouldn't just point Moogle at an arbitrary web site and start
crawling it unless you understand the
*[robots.txt](https://en.wikipedia.org/wiki/Robots.txt)* protocol. This protocol
lets web sites tell crawlers (like Google's or Yahoo's or Bing's) which
subdirectories they are allowed to index, at what rate they can connect to the
server, how frequently they can index the material, etc. If you don't follow
this protocol, then you are likely to have some very angry people on your
doorsteps. So to be on the safe side, you should restrict your crawling to your
local disk (which is why we have set this to be the default).

Another word of warning: Setting up and configuring a real web server demands a
lot of knowledge about security. In particular, we do not recommend that you
poke holes in your machine's firewall so that you can talk to Moogle from a
remote destination. Rather, you should restrict your interaction to a local
machine.

## Build Moogle

This subsection explains how to build Moogle. Initially, Moogle won't do much
for you, but it will compile.

> Note: if you are using an OCaml version before 4.02, Moogle may complain about
the usage of some functions from the `Bytes` library, which was not standard
before this version. You may be able to use the functions these replaced, such
as the now-deprecated `String.create` by changing the few instances of them to
their String counterparts (and ignoring the ensuing warnings), but it is
recommended that you instead procure a more modern OCaml installation.

Once you implement the necessary routines in `crawl.ml`, you will be able index
small web sites (such as `data/simple-html`). To index and query larger sites,
you will need to implement more efficient data structures to manage sets and
dictionaries.

Compile Moogle via command line by typing `make all`. To start Moogle up from a
terminal or shell, type:

```
dune exec moogle 8080 42 data/simple-html/index.html
```

_(Optional note: You can write `dune exec --no-build moogle ...` if you want to skip the step of checking whether the ML files need to be recompiled and relinked.  And you can even just write `_build/install/default/bin/moogle` to directly run the executable.  You can browse the `_build` directory tree to see what Dune put in there, and compare to `lib/dune` and `main/dune` to see how the build is specified.)_

The first command line argument (`8080`) represents the *port* that your Moogle
server listens to. Unless you know what you are doing, you should generally
leave it as 8080, though you may need to try a different port (e.g., 8081, 8082,
etc.) to find a free one.

The second command line argument (`42`) represents the *number of pages to
index*. Moogle will index less than or equal to that number of pages.

The last command line argument (`data/simple-html/index.html`) indicates the
*page from which your crawler should start*. Moogle will only index pages that
are on your local file system (inside the `data/simple-html`, `data/html`, or
`data/wiki` directories.)

You should see that the server starts and then prints some debugging information
ending with the lines:

```
Starting Moogle on port 8080.
Press Ctrl-c to terminate Moogle.
```

Now try to connect to Moogle with your web-browser&mdash;Chrome
([here](https://www.google.com/intl/en/chrome/browser/)) seems rather reliable,
but we have experienced glitches with some versions of Firefox and Safari.
Connect to the following URL:

```
http://localhost:8080
```

Once you connect to the server, you should see a web page that has a PUgle logo.
You can try to type in a query and if you do, you'll probably see an empty
response (you'll see an empty response until you implement `crawl.ml`).

The Moogle home page lets you enter a search query. The query is either a word
(e.g., "moo"), a conjunctive query (e.g., "moo AND cow"), or a disjunctive query
(e.g., "moo OR cow"). By default, queries are treated as conjunctive so if you
write "moo cow", you should get back all of the pages that have both the word
"moo" and the word "cow".

The query is parsed and sent back to Moogle as an HTTP request. At this point,
Moogle computes the set of URLs (drawn from those pages we have indexed) whose
web pages satisfy the query. For instance, if we have a query "Greg OR cow",
then Moogle would compute the set of URLs of all pages that contain either
"Greg" or "cow".

After computing the set of URLs that satisfy the user's query, Moogle builds an
HTML page response and sends the page back to the user to display in their web-
browser.

Because crawling the actual web demands careful attention to protocols (in
particular
*[robots.txt](https://en.wikipedia.org/wiki/Robots_exclusion_standard)*),
we will be crawling web pages on your local hard-disk instead.

## 1. Implement the Crawler

Your first major task is to implement the web crawler and build the search
index. In particular, you need to replace the dummy `crawl` function in the file
`crawl.ml` with a function which builds a `WordDict.dict` (dictionary from words
to sets of links.)

You will find the definitions in the `CrawlerServices` module (in the file
`util.ml`) useful. For instance, you will notice that the initial URL provided
on the command line can be found in the variable `CrawlerServices.initial_link`.
You should use the function `CrawlerServices.get_page` to fetch a page given a
link. A page contains the URL for the page, a list of links that occur on that
page, and a list of words that occur on that page. You need to update your
`WordDict.dict` so that it maps each word on the page to a set that includes the
page's URL. Then you need to continue crawling the other links on the page
recursively. Of course, you need to figure out how to avoid an infinite loop
when one page links to another and vice versa, and for efficiency, you should
only visit a page at most once.

The variable `CrawlerServices.num_pages_to_search` contains the command-line
argument specifying how many unique pages you should crawl. So you'll want to
stop crawling after you've seen that number of pages, or you run out of links to
process.

The module `WordDict` provides operations for building and manipulating
dictionaries mapping words (strings) to sets of links. Note that it is defined
in `crawl.ml` by calling a functor and passing it an argument where keys are
defined to be strings, and values are defined to be `LinkSet.set`. The interface
for `WordDict` can be found in `dict.ml`.

The module `LinkSet` is defined in `pagerank.ml` and like `WordDict`, it is
built using a set functor, where the element type is specified to be a `link`.
The interface for `LinkSet` can be found in the `myset.ml` file.

Running the crawler in the top-level interpreter won't really be possible, so to
test and debug your crawler, you will want to compile via command line using
`make`, and add thorough testing code. One starting point is debugging code that
prints out the status of your program's execution: see the OCaml documentation
for the `Printf.printf` functions for how to do this, and note that all of our
abstract types (e.g., sets, dictionaries, etc.) provide operations for
converting values to strings for easy printing. We have provided you with three
sample sets of web pages to test your crawler. Once you are confident your
crawler works, run it on the small `data/html` directory:

```
./moogle.d.byte 8080 7 data/simple-html/index.html
```

`data/simple-html` contains 7 very small HTML files that you can inspect
yourself, and you should compare that against the output of your crawler. If you
attempt to run your crawler on the larger sets of pages, you may notice that
your crawler takes a very long time to build up your index. The dummy list
implementations of dictionaries and sets do not scale very well.

**Note:** Unless you do a tiny bit of extra work, your index will be case
sensitive. This is fine, but may be confusing when testing, so keep it in mind.

## 2. Sets as Dictionaries

A *set* is a data structure that stores *keys* where keys cannot be duplicated
(unlike a *list* which may store duplicates). For our purposes, insertion of a
key already in the set should replace the old key-value binding with the new
key-value binding. Moogle uses lots of sets. For example, our web index maps
words to sets of URLs, and our query evaluator manipulates sets of URLs. We also
want sets to be faster than the na&iuml;ve list-based implementation we have
provided. Here, we build sets of *ordered keys*, keys on which we can provide a
total ordering.

Instead of implementing sets from scratch, we want you to use what you already
have for dictionaries to build sets. To do so, you must write a functor, which,
when given a `COMPARABLE` module, produces a `SET` module by building and
adapting an appropriate `DICT` module. That way, we can just later implement
dictionaries efficiently without completely rewriting the infrastructure as well
as the underlying algorithm.

For this part, you will need to uncomment the `DictSet` functor in the file
`myset.ml`. The first step is to build a suitable dictionary `D` by calling
`Dict.Make`. The key question is: what can you pass in for the type definitions
of keys and values? Then you need to build the set definitions in terms of the
operations provided by `D : DICT`.

You should make sure to write a set of unit tests that exercise your
implementation, following the [Testing](#testing) section above. You must test
ALL your functions (except for the string functions). Finally, you should change
the `Make` functor at the bottom of `myset.ml` so that it uses the `DictSet`
functor instead of `ListSet`. Try your crawler on the `data/simple-html` and
`data/html` directories.

## 3: Dictionaries as Trees

The critical data structure in Moogle is the dictionary. A *dictionary* is a
data structure that maps *keys* to *values*. Each key in the dictionary has a
unique value, although multiple keys can have the same value. For example,
`WordDict` is a dictionary that maps words on a page to the set of links that
contain that word. At a high level, you can think of a dictionary as a set of
(key,value) pairs.

As you may have observed as you tested your crawler with your new set functor,
building dictionaries on top of association lists (which we have for you) does
not scale particularly well. The implementation we have provided in `dict.ml`
is pretty inefficient, as it is based on lists, so the asymptotic complexity of
operations, such as looking up the value associated with a key can take linear
time in the size of the dictionary.

For this part of the problem set, we are going to build a different
implementation of dictionaries using a kind of *balanced tree* called a *2-3
tree*. You studied many of the properties of 2-3 trees and their relationship to
red-black trees in COS 226; in this course, you will learn how to implement them
in a functional language. Since our trees are guaranteed to be balanced, then
the complexity for our insert, remove, and lookup functions will be logarithmic
in the number of keys in our dictionary.

> Before you start coding, please look
over these
[slides](https://www.cs.princeton.edu/courses/archive/fall23/cos326/ass/2-3-trees.pdf)
that explain the invariants in a 2-3 tree and how to implement `insert` and
`remove`. A
[powerpoint with narration](https://www.cs.princeton.edu/courses/archive/fall23/cos326/ass/a5-2-3-trees.pptx)
is also available.

In the file `dict.ml`, you will find a commented out functor `BTDict` which is
intended to build a `DICT` module from a `DICT_ARG` module. Here is the type
definition for a dictionary implemented as a 2-3 tree:

```
type pair = key * value

type dict =
    | Leaf
    | Two of dict * pair * dict
    | Three of dict * pair * dict * pair * dict
```

Notice the similarities between this type definition of a 2-3 tree and the type
definition of a binary search trees we have covered in lecture. Here, in
addition to nodes that contain two subtrees, we have a `Three` node which
contains two (key,value) pairs (k1,v1) and (k2,v2), and three subtrees left,
middle, and right. Below are the invariants as described in the
[powerpoint](https://www.cs.princeton.edu/courses/archive/fall23/cos326/ass/a5-2-3-trees.pptx):

**2-node: Two(left,(k1,v1),right)**
1. Every key k appearing in subtree left must be k < k1.
2. Every key k appearing in subtree right must be k > k1.
3. The length of the path from the 2-node to **every** leaf in its two subtrees
    must be the same.

**3-node: Three(left,(k1,v1),middle,(k2,v2),right)**
1. k1 < k2.
2. Every key k appearing in subtree left must be k < k1.
3. Every key k appearing in subtree right must be k > k2.
4. Every key k appearing in subtree middle must be k1 < k < k2.
5. The length of the path from the 3-node to **every** leaf in its three
    subtrees must be the same.

Note that for our dictionary, only a single copy of a key can only be stored.
The last invariants of both types of nodes imply that our tree is **balanced**,
that is, the length of the path from our root node to any Leaf node is the same.

Open up `dict.ml` and locate the commented out `BTDict` module.

## 3a: balanced

Locate the `balanced` function at the bottom of the `BTDict` implementation
(right before the tests):

```
balanced : dict -> bool
```

You must write this function which takes a dictionary (our 2-3 tree) and returns
true if and only if the tree is balanced. To do so, *you only need to check the
path length invariants, not the order of the keys*. In addition, your solution
must be efficient&mdash;our solution runs in O(n) where n is the size of the
dictionary. In a comment above the function, please explain carefully in English
how you are testing that the tree is balanced.

Once you have written this function, scroll down to `run_tests` and uncomment
`test_balanced();`. Next, scroll down to `IntStringBTDict` and uncomment those
two lines. All the tests should pass. Now that you are confident in your
`balanced` function, **you are required to use it on all your tests involving
insert**.

## 3b: strings, fold, lookup, member

Implement these functions according to their specification provided in `DICT`:

```
val fold : (key -> value -> 'a -> 'a) -> 'a -> dict -> 'a
val lookup : dict -> key -> value option
val height : dict -> int
val member : dict -> key -> bool
val string_of_key : key -> string
val string_of_value : value -> string
val string_of_dict : dict -> string
```

You may change the order in which the functions appear, but **you may not change
the signature of any of these functions (name, order of arguments, types)**. You
may add a `rec` to make it `let rec` if you feel that you need it.

## 3c: insert

Watch 2-3-trees video if you have not already done so. Insertion is handled by
the recursive function `insert_to_tree`, which takes as arguments a dictionary,
a key and a value. It returns a `(bool * dictionary)` tuple. The tree in this
tuple is a new balanced dictionary that contains all the elements of the old
tree as well as the new key-value pair. The boolean in this tuple reflects
whether the height of the returned tree has changed. If the boolean is true,
then the new tree has a height equal to exactly one greater than the old tree.
Otherwise, the old and new trees have equal heights.

```
val insert_to_tree dict -> key -> value -> (bool * dict)
```

The `insert_to_tree` function should first check if the current node d has a key
equal to the key being inserted. If it does, it simply changes the value of the
current node and returns (false, modified d). If not, it must use the key to
determine which of its subtrees to recursively call `insert_to_tree` on. It then
uses the boolean returned by this call to determine if it is necessary to
locally alter the structure of the tree to maintain equal height between the
branches. The rules for when and how the tree is rebalanced are described in the
2-3 trees powerpoint.

The `insert_to_tree` function should have special cases for when the subtrees of
a node are leaves, i.e., the end of the tree is reached. As described in the 2-3
trees powerpoint, a 2 node will immediately absorb the new value and return a
new 3 node and the boolean false. A 3 node will split into a 2 node with 2 nodes
as subtrees, and return the boolean true, as the height of the tree has
increased.

## 3d: remove

Removing a node from the tree follows a similar process, and uses a similar
function:

```
val remove_from_tree dict -> key -> (bool * dict)
```

Removal is handled by the recursive function `remove_from_tree`, which takes as
arguments a dictionary and a key. It returns a `(bool * dictionary)` tuple. The
tree in this tuple is a new balanced dictionary that contains all the elements
of the old tree except the key given as an argument. The boolean returned by
`remove_from_tree` indicates whether the tree has been reduced in height. If the
boolean is true, then the new tree has a height equal to exactly one less than
the old tree. Otherwise, the old and new trees have equal heights. The recursive
function operates in the same way as `insert_to_tree`, with 2 differences.
First, the rules for rebalancing the tree are different. See the powerpoint for
more details. Secondly, if the function is removing a node that is not in the
last level of the tree, it must instead replace the node it is deleting with
either the leftmost node of its right subtree, or the rightmost node of its
left subtree. The function then deletes the substituted node from the relevant
tree as usual. It is likely that you will find it necessary to write several
helper functions for this part of the assignment.

Once you have finished writing the `insert` and `remove` functions, uncomment
out the `test_remove_*` functions in `run_tests ()`. All the tests should pass.

## 3e: choose

Implement the function according to the specification in `DICT`:

`choose : dict -> (key * value * dict) option`

Write tests to test your choose function.

## 4. Try your crawler!

Finally, because we have properly factored out an interface, we can easily swap
in your tree-based dictionaries in place of the list-based dictionaries by
modifying the `Make` functor at the end of `dict.ml`. So make the change and try
out your new crawler on the three sets of webpages. Our startup code prints out
the crawling time, so you can see which implementation is faster. Try it on the
larger test set in the `data/wiki` directory in addition to the `data/html` and
`data/simple-html` directories with:

```
./moogle.d.byte 8080 45 data/wiki/Teenage_Mutant_Ninja_Turtles
```

If you are confident everything is working, try changing 45 to 200. (This may
take several minutes to crawl and index). You're done!

> *If your MacOSX complains about a `Unix.EMFILE` error because of the limit on
open files when running the crawler, you could try this shell command:*
>
> `ulimit -S -n 2560`

We've provided you with a debug flag at the top of `moogle.ml`, that can be set
to either true or false. If debug is set to true, Moogle prints out debugging
information using the string conversion functions defined in your dictionary and
set implementations. This is set to true by default.

## 5. PageRank

**Only do this part when you know for sure the rest of your problem set is
working. Making too many changes all at once is a recipe for disaster. Always
keep your code compiling and working correctly. Make changes one module at a
time.**

We will now apply our knowledge of ADTs and graphs to explore solutions to a
compelling problem: finding "important" nodes in graphs like the Internet, or
the set of pages that you're crawling with Moogle.

The concept of assigning a measure of importance to nodes is very useful in
designing search algorithms, such as those that many popular search engines rely
on. Early search engines often ranked the relevance of pages based on the number
of times that search terms appeared in the pages. However, it was easy for
spammers to game this system by including popular search terms many times,
propelling their results to the top of the list.

When you enter a search query, you really want the important pages: the ones
with valuable information, a property often reflected in the quantity and
quality of other pages *linking to them*. Better algorithms were eventually
developed that took into account the relationships between web pages, as
determined by links. (For more about the history of search engines, you can
check out
[this page](https://en.wikipedia.org/wiki/Web_search_engine).) These
relationships can be represented nicely by a graph structure, which is what
we'll be using here.

### NodeScore ADT

Throughout the assignment, we'll want to maintain associations of graph nodes to
their importance, or `NodeScore`: a value between 0 (completely unimportant) and
1 (the only important node in the graph).

In order to assign `NodeScores` to the nodes in a graph, we've provided a module
with an implementation of an ADT, `NODE_SCORE`, to hold such associations. The
module makes it easy to create, modify, normalize (to sum to 1), and display
`NodeScores`. You can find the module signature and implementation in
`nodescore.ml`.

### NodeScore Algorithms

In this section, you'll implement a series of `NodeScore` algorithms in
different modules: that is, functions rank that take a graph and return a
`node_score_map` on it. As an example, we've implemented a trivial `NodeScore`
algorithm in the `IndegreeRanker` module that gives all nodes a score equal to
the number of incoming edges.

You may realize that we need a better way of saying that nodes are popular or
unpopular. In particular, we need a method that considers global properties of
the graph and not just edges adjacent to or near the nodes being ranked. For
example, there could be an extremely relevant webpage that is several nodes
removed from the node we start at. That node might normally fare pretty low on
our ranking system, but perhaps it should be higher based on there being a high
probability that the node could be reached when browsing around on the internet.

So consider Sisyphus, doomed to crawl the Web for eternity: or more
specifically, doomed to start at some arbitrary page, and follow links randomly.
Let's say Sisyphus can take k steps after starting from a random node. We design
a system to determine node scores based off how likely Sisyphus reaches a
certain page. In other words, we ask: where will Sisyphus spend most of his
time? Sisyphus jumps to a random page whenever he reaches a page with no
outgoing links. Also, at every step Sisyphus has a small chance of jumping to a
random page at every step. This is to prevent Sisyphus from ever getting stuck
in a loop or being unable to proceed from a page with no outgoing links.

The na&iuml;ve method of implementing this ranking system would be to start at a
random page on the web, and at every iteration follow a random link to another
web page. A counter would track the number of times each page on the web is
visited. The program jumps to a random page with probability `d`, or when it
reaches a page with no outgoing links.

This method provides more meaningful results when compared to the
`IndegreeRanker`, as it gives more weight to links from important webpages.
However, it takes an extremely high number of iterations to produce meaningful
results.

Here's a better algorithm. Let's suppose Sisyphus is bitten by a radioactive
eigenvalue, giving him the power to subdivide himself arbitrarily and send parts
of himself off to multiple different nodes at once. We have him start evenly
spread out among all the nodes. Then, from each of these nodes, the pieces of
Sisyphus that start there will propagate outwards along the graph, dividing
themselves evenly among all outgoing edges of that node. If you are interested
you can find more information about eigenvalues
[here](https://en.wikipedia.org/wiki/Eigenvalues_and_eigenvectors), but you
should not find this necessary for the assignment.

So, let's say that at the start of a step, we have some fraction q of Sisyphus
at a node, and that node has 3 outgoing edges. Then q/3 of Sisyphus will
propagate outwards from that node along each edge. This will mean that nodes
with a lot of value will make their neighbors significantly more important at
each timestep, and also that in order to be important, a node must have a large
number of incoming edges continually feeding it importance.

Thus, our basic algorithm takes an existing graph and `NodeScore`, and updates
the `NodeScore` by propagating all of the value at each node to all of its
neighbors. However, there's one wrinkle: we want to include some mechanism to
simulate random jumping. The way that we do this is to use a parameter `d`. At
each step, each node propagates a fraction `1-d` of its value to its neighbors
as described above, but also a fraction `d` of its value to all nodes in the
graph. This will ensure that every node in the graph is always getting some
small amount of value, so that we never completely abandon nodes that are hard
to reach.

We can model this fairly simply. If each node distributes d times its value to
all nodes at each timestep, then at each timestep each node accrues (d/n) times
the overall value in this manner. Thus, we can model this effect by having the
base `NodeScore` at each timestep give (d/n) to every node.

This process can be represented by the following matrix equation:

```
Rₖ₊₁ = (d/N)U + (1-d)LRₖ

where d is the probability of jumping,
N is the number of web pages,
U is a vector of length N with every value equal to 1,
L is the NxN link matrix, and
R is the PageRank vector.
```

The R vector is a vector of length N in which each element represents the
probability of Sisyphus being at that particular node. For example the first
value of the vector is the probability of Sisyphus being at the first node of
the node list.

We begin with a vector of all equal probabilities, R₀. For each iteration, the
product of LR is a new probability vector in which each node has distributed
its value to its neighbors. The addition of (d/N)U takes into account the
probability of a random jump.

We will repeat this computation until the results converge. The R vector is
considered to have converged when the square of the Euclidean vector distance
between Rₖ and Rₖ₊₁ is less than 1/1000th the square of the magnitude of Rₖ. The
square of the magnitude of a vector is equal to the dot product of the vector
and itself. The Euclidean vector distance between vectors a and b is equal to
sqrt ((a₀ - b₀)² + (a₁ - b₁)² ... (aₙ - bₙ)²).

The Link matrix has a value at i j that expresses the probability of following a
link from node j to node i. Consider a list of all N pages in the internet,
called `Pages`. In the link matrix, the ith column of the matrix will have
positive values in every row j where there is a link from the ith website of
`Pages` to the jth website of `Pages`, and be zero otherwise. The value of every
positive value in a column of a matrix is equal to 1 divided by the number of
outgoing links in the site that column represents. Columns with no outgoing
links are treated as if they have an outgoing link to every other page on the
internet, to represent Sisyphus jumping to a random page.

Use a list of lists to represent a matrix for this part of the assignment.
Inside your implementation of the pagerank module you should have functions for
the dot product of two vectors, as well as multiplying a matrix by a vector. See
if you can use `List.fold` instead of iteration for those two functions.

This method is called an Eigenvalue solver because the final R vector will be an
Eigenvector of the link matrix. That is to say that when the link matrix is
multiplied by the final R vector, the result will have the same direction as the
R vector. Because the vector is normalized, the Eigenvalue associated with this
Eigenvector will be 1.

In the file `Pagerank.ml`, uncomment the signature `WALK_PARAMS` and the module
`EigenvalueRanker` and implement functions for `dot_product`, `multiply`, and
`rank`. The `WALK_PARAMS` signature contains the value `do_random_jumps`. When
`do_random_jumps` is None, there is no random jumping component. When
`do_random_jumps` is (Some d), the quantity d is the probability of jumping.

## 6: Partnership and Submission Guidelines

If you are completing this assignment with a partner, the overarching principle
is that each partner is responsible for equally sharing in all elements of the
assignment. This precludes "divide and conquer" approaches to the assignment. It
also requires introspection to prevent a situation in which you are "carrying"
your partner or allowing yourself to be "carried".

We believe that the
[COS126 partner collaboration policy](https://www.cs.princeton.edu/courses/archive/fall23/cos126/syllabus/index.html#course-collaboration-policy)
is a good guideline with lots of good advice.

NOTE: both students in a pair will receive the same grade on the assignment.
Following from this, both students in a pair must use the same number of
automatically waived late days. This means that a pair has available the minimum
number of free late days remaining between the two of them. (A partner with more
free late days available would retain the excess for future individual
assignments or assignments paired with another student with free late days
remaining.)

Your assignment will be automatically submitted every time you push your changes
to your GitHub repository. Within a couple minutes of your submission, the
autograder will make a comment on your commit listing the output of our testing
suite when run against your code. **Note that you will be graded only on your
changes to `crawl.ml`, `dict.ml`, `myset.ml`, and `pagerank.ml`**, and not on
your changes to any other files.

You may submit and receive feedback in this way as many times as you like,
whenever you like.


## 7: Extra Fun: Favicon

You web browser may request `favicon.ico` from the server (`moogle.ml`), but we
don't have a favicon. Just for fun, design a favicon for Moogle and submit it.
You may also want to modify `moogle.ml` so that it
knows how to serve the `favicon.ico` file. Look in `process_request` to compare
how it serves `PU-gle.jpg` versus how it serves `moogle.html`.
