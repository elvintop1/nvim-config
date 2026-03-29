# CP Snippets

Canonical trigger format:

- `ds_*` data structures
- `gr_*` graph / tree / flow
- `mt_*` math / number theory
- `str_*` string
- `tc_*` techniques / DP / offline
- `geo_*` geometry

## Data structures

- `ds_dsu` — DSU: Disjoint set union with union by size and path compression
- `ds_dsu_rb` — DSU Rollback: Rollback DSU for offline dynamic connectivity
- `ds_bit` — Fenwick Tree: Fenwick tree for point add and range sum
- `ds_bit_rr` — Fenwick Range Add Range Sum: Two Fenwick trees for range add and range sum
- `ds_bit2` — Fenwick Tree 2D: 2D Fenwick tree for point add and rectangle sum
- `ds_seg` — Segment Tree: Iterative segment tree with customizable monoid
- `ds_lseg` — Lazy Segment Tree: Lazy segment tree for range add and range sum
- `ds_pseg` — Persistent Segment Tree: Persistent segment tree for frequency versions and kth queries
- `ds_sparse` — Sparse Table: Sparse table for idempotent range queries
- `ds_trie` — Trie: Lowercase trie with terminal counts
- `ds_xtrie` — Binary XOR Trie: Binary trie supporting insert, erase, and maximum xor
- `ds_cht` — Convex Hull Trick Deque: Monotone CHT for minimum queries with monotone slopes and queries
- `ds_lichao` — Li Chao Tree: Li Chao tree for minimum of lines on integer domain
- `ds_treap` — Implicit Treap: Implicit treap for sequence operations

## Graph / tree / flow

- `gr_dij` — Dijkstra: Shortest paths on non-negative weighted graph
- `gr_bfs01` — 0-1 BFS: Shortest paths on graph with edge weights 0 or 1
- `gr_bellman` — Bellman Ford: Bellman-Ford with reachable negative cycle detection
- `gr_floyd` — Floyd Warshall: All-pairs shortest paths
- `gr_topo` — Topological Sort: Kahn topological sort, empty result means cycle
- `gr_scc` — Strongly Connected Components: Kosaraju SCC decomposition
- `gr_bcc` — Bridges and Articulation Points: Tarjan bridges and articulation points on undirected graph
- `gr_2sat` — 2-SAT: 2-SAT solver with implication graph
- `gr_kruskal` — Kruskal MST: Kruskal minimum spanning tree
- `gr_lca` — LCA Binary Lifting: Lowest common ancestor with binary lifting
- `gr_hld` — Heavy Light Decomposition: Heavy-light decomposition with path decomposition callbacks
- `gr_centroid` — Centroid Decomposition: Centroid decomposition on tree
- `gr_euler` — Directed Euler Trail: Hierholzer algorithm for directed Euler trail
- `gr_dinic` — Dinic Max Flow: Dinic maximum flow
- `gr_mcmf` — Min Cost Max Flow: Successive shortest augmenting path min-cost max-flow
- `gr_hk` — Hopcroft Karp: Hopcroft-Karp maximum matching on bipartite graph

## Math / number theory

- `mt_modint` — ModInt: Modint template with compile-time MOD
- `mt_sieve` — Linear Sieve SPF: Linear sieve with primes and smallest prime factor
- `mt_phi_mu` — Phi Mu Sieve: Linear sieve for phi and mobius
- `mt_comb` — Combinatorics Factorials: Factorials and binomial coefficients modulo mod
- `mt_extgcd` — Extended GCD and Mod Inverse: Extended Euclid and modular inverse
- `mt_crt` — Chinese Remainder Theorem: Merge congruences, returns {remainder, modulus} or {0,-1}
- `mt_matpow` — Matrix Exponentiation: Matrix multiplication and fast exponentiation modulo mod
- `mt_xbasis` — XOR Basis: Linear basis over xor
- `mt_miller` — Miller Rabin 64 bit: Deterministic Miller-Rabin primality test for uint64
- `mt_pollard` — Pollard Rho: Pollard-Rho factorization for 64-bit integers
- `mt_fft` — FFT Convolution: Complex FFT convolution on doubles/integers
- `mt_ntt` — NTT 998244353: NTT convolution modulo 998244353
- `mt_fwht` — FWHT XOR Convolution: Fast Walsh-Hadamard transform for xor convolution
- `mt_gauss` — Gaussian Elimination: Gaussian elimination over doubles, returns rank or -1 if inconsistent
- `mt_bsgs` — Baby Step Giant Step: Discrete logarithm for gcd(a, mod) = 1
- `mt_floor_sum` — Floor Sum: AtCoder floor_sum: sum_{i=0}^{n-1} floor((a*i+b)/m)

## String

- `str_pi` — Prefix Function: Prefix function for KMP
- `str_kmp` — KMP Search: Find all occurrences of pattern in text with KMP
- `str_z` — Z Function: Z-function
- `str_hash` — Rolling Hash: Unsigned 64-bit polynomial rolling hash
- `str_manacher` — Manacher: Palindrome radii for odd and even centers
- `str_aho` — Aho Corasick: Aho-Corasick automaton for lowercase strings
- `str_sa` — Suffix Array and LCP: Suffix array O(n log n) with LCP
- `str_sam` — Suffix Automaton: Suffix automaton
- `str_eertree` — Eertree: Palindromic tree
- `str_booth` — Booth Minimum Rotation: Lexicographically minimum string rotation
- `str_duval` — Duval Lyndon Factorization: Lyndon factorization by Duval algorithm

## Techniques / DP

- `tc_compress` — Coordinate Compression: Coordinate compression helper
- `tc_mo` — Mo Ordering: Mo algorithm query ordering
- `tc_sack` — DSU on Tree Skeleton: DSU on tree (sack) skeleton
- `tc_reroot` — Rerooting DP: Generic rerooting DP on trees
- `tc_dnc_dp` — Divide and Conquer DP: Divide and conquer DP optimization skeleton
- `tc_knuth` — Knuth Optimization: Knuth optimization for interval DP
- `tc_sos` — SOS DP: Subset and superset zeta transforms
- `tc_submask` — Submask Enumeration: Submask and supermask iteration idioms
- `tc_lis` — LIS: Longest increasing subsequence length and one reconstruction
- `tc_mitm` — Meet in the Middle Subset Sum: Meet-in-the-middle subset sums

## Geometry

- `geo_point` — Point Geometry Primitives: 2D point primitives with long double
- `geo_segment` — Segment Intersection: Segment intersection test with endpoint inclusion
- `geo_line` — Line Intersection: Line intersection point for non-parallel lines
- `geo_area` — Polygon Area: Signed polygon area
- `geo_hull` — Convex Hull: Monotonic chain convex hull
- `geo_calipers` — Rotating Calipers Diameter: Diameter squared of convex polygon in CCW order
- `geo_closest` — Closest Pair of Points: Closest pair distance squared in O(n log n)
