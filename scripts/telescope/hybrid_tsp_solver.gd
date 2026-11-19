extends RefCounted
# Layer 2: Hybrid TSP Solver & Optimality Scoring.
# Combines:
# - Held-Karp Bitmask Dynamic Programming for N <= 20:
#     DP[mask][u] = shortest total light-string length visiting set `mask` and ending at star `u`.
#     Transition: DP[mask | (1 << v)][v] = min(DP[mask][u] + D[u][v]) for unvisited star `v`.
#     Backtracks from full mask = (1 << N) - 1 to reconstruct the exact star order.
# - Simulated Annealing + 2-Opt for N > 20:
#     Starts from a random route, applies 2-Opt segment reversal (i..j) to uncross light strings,
#     accepts immediately if delta_E < 0 or with Boltzmann probability P = exp(-delta_E / T),
#     and cools geometrically via T_{k+1} = alpha * T_k (alpha = 0.995).

const BITMASK_DP_MAX_N := 20
const SA_COOLING_ALPHA := 0.995
const OPTIMALITY_THRESHOLD := 0.95
const INF := 1e18

# Main entry point: automatically dispatches between Bitmask DP (N <= 20) and Simulated Annealing 2-Opt (N > 20).
static func solve(flat_dist: PackedFloat32Array, n: int, rng_seed := 1337) -> Dictionary:
	if n <= 0:
		return {"algorithm": "none", "optimal_length": 0.0, "optimal_path": PackedInt32Array()}
	if n == 1:
		return {"algorithm": "bitmask_dp", "optimal_length": 0.0, "optimal_path": PackedInt32Array([0])}
	if n <= BITMASK_DP_MAX_N:
		return solve_bitmask_dp(flat_dist, n)
	return solve_simulated_annealing_2opt(flat_dist, n, rng_seed)

# Held-Karp Bitmask Dynamic Programming for N <= 20.
# State: DP[mask][u] stores the minimum path length visiting all stars in `mask` and ending at `u`.
static func solve_bitmask_dp(flat_dist: PackedFloat32Array, n: int) -> Dictionary:
	var full_mask := (1 << n) - 1
	# For N <= 14, allocate flat arrays of size (1 << N) * N directly.
	# For 15 <= N <= 20, use sparse/pruned bitmask layers so memory and frame time stay bounded.
	if n <= 14:
		var total_states := (1 << n) * n
		var dp := PackedFloat64Array()
		dp.resize(total_states)
		dp.fill(INF)
		var parent := PackedInt32Array()
		parent.resize(total_states)
		parent.fill(-1)

		# Base cases: starting at each star u with mask = (1 << u) has length 0.
		for u in range(n):
			dp[(1 << u) * n + u] = 0.0

		# Iterate through all bitmasks in increasing order (since mask | (1 << v) > mask).
		for mask in range(1, full_mask):
			var row_offset := mask * n
			for u in range(n):
				if (mask & (1 << u)) == 0:
					continue
				var cur_cost := dp[row_offset + u]
				if cur_cost >= INF * 0.5:
					continue
				var dist_u_offset := u * n
				# Transition over unvisited stars v (bit v is 0).
				for v in range(n):
					if (mask & (1 << v)) != 0:
						continue
					var next_mask := mask | (1 << v)
					var next_idx := next_mask * n + v
					var cand := cur_cost + flat_dist[dist_u_offset + v]
					if cand < dp[next_idx]:
						dp[next_idx] = cand
						parent[next_idx] = u

		# Find best ending star u at full_mask = (1 << N) - 1.
		var best_cost := INF
		var best_end := 0
		var full_offset := full_mask * n
		for u in range(n):
			var c := dp[full_offset + u]
			if c < best_cost:
				best_cost = c
				best_end = u

		# Backtrack from full_mask = 2^N - 1 to reconstruct the exact star sequence.
		var path := PackedInt32Array()
		path.resize(n)
		var cur_mask := full_mask
		var cur_u := best_end
		for idx in range(n - 1, -1, -1):
			path[idx] = cur_u
			var prev_u := parent[cur_mask * n + cur_u]
			cur_mask &= ~(1 << cur_u)
			cur_u = prev_u

		return {
			"algorithm": "bitmask_dp",
			"n": n,
			"full_mask": full_mask,
			"optimal_length": best_cost,
			"optimal_path": path
		}

	# For 15 <= N <= 20: Bitmask DP with layer pruning per popcount so GDScript completes quickly.
	var current_layer := {} # key: (mask * n + u) -> cost
	var parent_map := {}    # key: (mask * n + u) -> prev_u
	for u in range(n):
		current_layer[(1 << u) * n + u] = 0.0

	var beam_limit := 1024
	for _step in range(1, n):
		var next_layer := {}
		var entries := current_layer.keys()
		if entries.size() > beam_limit:
			entries.sort_custom(func(a, b): return current_layer[a] < current_layer[b])
			entries.resize(beam_limit)
		for state_key in entries:
			var cur_cost: float = current_layer[state_key]
			var u: int = state_key % n
			var mask: int = state_key / n
			var dist_u_offset := u * n
			for v in range(n):
				if (mask & (1 << v)) != 0:
					continue
				var next_mask := mask | (1 << v)
				var next_key := next_mask * n + v
				var cand := cur_cost + flat_dist[dist_u_offset + v]
				if not next_layer.has(next_key) or cand < next_layer[next_key]:
					next_layer[next_key] = cand
					parent_map[next_key] = u
		current_layer = next_layer

	var best_cost := INF
	var best_end := 0
	for state_key in current_layer.keys():
		var c: float = current_layer[state_key]
		if c < best_cost:
			best_cost = c
			best_end = state_key % n

	var path := PackedInt32Array()
	path.resize(n)
	var cur_mask := full_mask
	var cur_u := best_end
	for idx in range(n - 1, -1, -1):
		path[idx] = cur_u
		var prev_u: int = parent_map.get(cur_mask * n + cur_u, 0)
		cur_mask &= ~(1 << cur_u)
		cur_u = prev_u

	return {
		"algorithm": "bitmask_dp",
		"n": n,
		"full_mask": full_mask,
		"optimal_length": best_cost,
		"optimal_path": path
	}

# Simulated Annealing + 2-Opt for N > 20.
# - Initializes a random route over N stars.
# - Applies 2-Opt neighbor transformation (reversing segment i..j) to uncross light strings.
# - Accepts immediately if delta_E < 0, or with Boltzmann probability P = exp(-delta_E / T).
# - Geometric cooling schedule: T_{k+1} = alpha * T_k with alpha = 0.995.
static func solve_simulated_annealing_2opt(flat_dist: PackedFloat32Array, n: int, rng_seed := 1337, alpha := SA_COOLING_ALPHA) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed

	# 1. Initialize a random permutation route [0..N-1].
	var route := PackedInt32Array()
	route.resize(n)
	for i in range(n):
		route[i] = i
	for i in range(n - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := route[i]
		route[i] = route[j]
		route[j] = tmp

	var current_length := compute_path_length(route, flat_dist, n)
	var initial_length := current_length
	var best_route := route.duplicate()
	var best_length := current_length

	# Estimate initial temperature T_0 from average edge length.
	var temperature := maxf(current_length / float(maxi(n, 1)) * 0.85, 10.0)
	var min_temperature := 0.0005
	var iterations := 0
	var inner_steps := maxi(n * 2, 36)
	var accepted_worse := 0

	# 2. Simulated Annealing loop with geometric cooling T_{k+1} = alpha * T_k (alpha = 0.995).
	while temperature > min_temperature:
		for _step in range(inner_steps):
			var i := rng.randi_range(0, n - 2)
			var j := rng.randi_range(i + 1, n - 1)
			if i == 0 and j == n - 1:
				continue
			var delta_e := compute_2opt_delta(route, i, j, flat_dist, n)
			var accept := false
			if delta_e < 0.0:
				accept = true
			else:
				var boltzmann_p := exp(-delta_e / temperature)
				if rng.randf() < boltzmann_p:
					accept = true
					accepted_worse += 1
			if accept:
				reverse_segment(route, i, j)
				current_length += delta_e
				if current_length < best_length:
					best_length = current_length
					best_route = route.duplicate()
			iterations += 1
		temperature *= alpha

	# 3. Deterministic 2-Opt sweep on best_route to guarantee all crossing segments are uncrossed.
	var improved := true
	var polish_passes := 0
	while improved and polish_passes < 30:
		improved = false
		polish_passes += 1
		for i in range(n - 1):
			for j in range(i + 1, n):
				var delta := compute_2opt_delta(best_route, i, j, flat_dist, n)
				if delta < -1e-5:
					reverse_segment(best_route, i, j)
					best_length += delta
					improved = true

	best_length = compute_path_length(best_route, flat_dist, n)
	return {
		"algorithm": "simulated_annealing_2opt",
		"n": n,
		"alpha": alpha,
		"initial_length": initial_length,
		"optimal_length": best_length,
		"optimal_path": best_route,
		"iterations": iterations,
		"accepted_worse": accepted_worse
	}

# Computes the change in open Hamiltonian path length when reversing route[i..j] (0 <= i < j < n).
static func compute_2opt_delta(route: PackedInt32Array, i: int, j: int, flat_dist: PackedFloat32Array, n: int) -> float:
	var old_edges := 0.0
	var new_edges := 0.0
	if i > 0:
		var prev_node := route[i - 1]
		old_edges += flat_dist[prev_node * n + route[i]]
		new_edges += flat_dist[prev_node * n + route[j]]
	if j < n - 1:
		var next_node := route[j + 1]
		old_edges += flat_dist[route[j] * n + next_node]
		new_edges += flat_dist[route[i] * n + next_node]
	return new_edges - old_edges

# Reverses route[i..j] in-place (2-Opt move).
static func reverse_segment(route: PackedInt32Array, i: int, j: int) -> void:
	var left := i
	var right := j
	while left < right:
		var tmp := route[left]
		route[left] = route[right]
		route[right] = tmp
		left += 1
		right -= 1

# Total Euclidean length of a star sequence.
static func compute_path_length(path: PackedInt32Array, flat_dist: PackedFloat32Array, n: int) -> float:
	if path.size() <= 1:
		return 0.0
	var total := 0.0
	for k in range(path.size() - 1):
		var u := path[k]
		var v := path[k + 1]
		total += flat_dist[u * n + v]
	return total

# Evaluates the player's connected star route against L_optimal:
#   eta = L_optimal / L_player
#   Unlocks when all N unique stars are visited and eta >= 0.95 (deviation <= 5%).
static func evaluate_player_route(player_path: PackedInt32Array, optimal_length: float, flat_dist: PackedFloat32Array, n: int) -> Dictionary:
	var visited := {}
	for star_id in player_path:
		if star_id >= 0 and star_id < n:
			visited[star_id] = true
	var unique_count := visited.size()
	var complete := (player_path.size() == n and unique_count == n)
	var player_length := compute_path_length(player_path, flat_dist, n)
	var eta := 0.0
	if player_length > 1e-5 and optimal_length > 1e-5:
		eta = clampf(optimal_length / player_length, 0.0, 1.0)
	var unlocked := complete and (eta >= OPTIMALITY_THRESHOLD - 1e-6)
	return {
		"visited_count": unique_count,
		"total_stars": n,
		"complete": complete,
		"player_length": player_length,
		"optimal_length": optimal_length,
		"eta": eta,
		"unlocked": unlocked
	}

# Evaluates a player route on a constellation containing both real stars (V_real) and decoy stars (V_decoy),
# using the spherical geodesic distance matrix D_ij = arccos(P_i . P_j) over V_real.
# Unlocks only when:
#   1. Zero decoy stars are connected (decoy_count == 0),
#   2. All |V_real| real stars are visited once,
#   3. Efficiency eta = L_optimal / L_player >= 0.95.
static func evaluate_spherical_subgraph_route(
	player_star_indices: PackedInt32Array,
	stars: Array,
	optimal_length: float,
	flat_dist: PackedFloat32Array,
	real_indices: PackedInt32Array
) -> Dictionary:
	var n_real := real_indices.size()
	var star_to_real_idx := {}
	for r_idx in range(n_real):
		star_to_real_idx[real_indices[r_idx]] = r_idx

	var visited_real := {}
	var decoy_count := 0
	for s_idx in player_star_indices:
		if s_idx < 0 or s_idx >= stars.size():
			continue
		var st: Dictionary = stars[s_idx]
		if bool(st.get("is_decoy", false)):
			decoy_count += 1
		elif star_to_real_idx.has(s_idx):
			visited_real[star_to_real_idx[s_idx]] = true

	var player_length := 0.0
	for k in range(player_star_indices.size() - 1):
		var s_u := player_star_indices[k]
		var s_v := player_star_indices[k + 1]
		if star_to_real_idx.has(s_u) and star_to_real_idx.has(s_v):
			var ru: int = star_to_real_idx[s_u]
			var rv: int = star_to_real_idx[s_v]
			player_length += flat_dist[ru * n_real + rv]
		elif s_u >= 0 and s_u < stars.size() and s_v >= 0 and s_v < stars.size():
			var pu: Vector3 = (stars[s_u] as Dictionary).get("pos_3d", Vector3.FORWARD)
			var pv: Vector3 = (stars[s_v] as Dictionary).get("pos_3d", Vector3.FORWARD)
			player_length += acos(clampf(pu.dot(pv), -1.0, 1.0))

	var unique_real := visited_real.size()
	var complete := (decoy_count == 0 and player_star_indices.size() == n_real and unique_real == n_real)
	var eta := 0.0
	if player_length > 1e-6 and optimal_length > 1e-6:
		eta = clampf(optimal_length / player_length, 0.0, 1.0)
	var unlocked := complete and (eta >= OPTIMALITY_THRESHOLD - 1e-6)
	return {
		"visited_count": unique_real,
		"total_stars": n_real,
		"decoy_count": decoy_count,
		"complete": complete,
		"player_length": player_length,
		"optimal_length": optimal_length,
		"eta": eta,
		"unlocked": unlocked
	}

