# sawbot.gd - the tree-cutter: ignores the player, walks to the nearest tree and
# saws it down. Health, dying and path-walking come from enemy.gd.
class_name Sawbot
extends Enemy
## A rogue machine that eats the forest.
##
## WHY IT EXISTS (from the design): it makes the forest something to defend, and
## it stops the arena from silting up with trees. It never attacks the player.
##
## WHAT IT DOES, every physics step:
##   1. If a grown tree is within reach, stand still and saw it: one bite of
##      damage every sawbot_saw_interval seconds until the tree falls.
##   2. Otherwise walk towards the nearest grown tree.
##   3. No grown trees at all: wait by the nearest sapling, or failing that
##      drift to the middle of the arena.
## Rule 1 uses "any tree in reach", not "my chosen tree". So if its chosen tree
## is buried behind others, it simply cuts its way in through the outer ones.
##
## Like every machine, a downed Sawbot roots and becomes a tree itself.

const FALLBACK_COLOR: Color = Color(0.60, 0.64, 0.66)
## Tint while the blade is biting (values above 1.0 brighten).
const SAWING_TINT: Color = Color(1.5, 1.3, 0.8)

## True while it is sawing a tree. Public so the tests can watch it.
var is_sawing: bool = false

## Seconds until the next bite of damage.
var _saw_time_left: float = 0.0
## Where it is walking to right now (a tree, a sapling, or the arena centre).
var _destination: Vector2 = Vector2.ZERO


## _ready runs once when the Sawbot enters the scene.
func _ready() -> void:
	_configure_body(CONFIG.sawbot_hp, CONFIG.sawbot_radius_cells, CONFIG.sawbot_texture, FALLBACK_COLOR)


## _physics_process runs 60 times per second: saw if a tree is in reach,
## otherwise walk towards the next one.
func _physics_process(delta: float) -> void:
	if _grid == null:
		return
	if _tick_bound(delta):
		return  # tied up by the vine: do nothing this step

	var reach: float = CONFIG.sawbot_reach_cells * CONFIG.cell_size
	# `false` = measure the REAL distance. (The Heart Tree's lure makes it count
	# as nearer than it is; used here, that let a Sawbot cut it from two cells off.)
	var in_reach: ForestTree = _nearest_tree(ForestTree.Stage.GROWN, reach, false)
	if in_reach != null:
		_saw(in_reach, delta)
		return
	if is_sawing:
		is_sawing = false
		modulate = Color.WHITE  # white = "no tint"

	if _repath_due(delta, CONFIG.sawbot_repath_interval):
		_destination = _choose_destination()
		_path_to(_grid.world_to_cell(_destination))
	# Close enough to a place where there is nothing to cut: just wait there.
	if global_position.distance_to(_destination) <= reach:
		velocity = Vector2.ZERO
		return
	_walk_towards(_next_goal(_destination), CONFIG.sawbot_speed)


## Overrides Enemy._on_bound: being tied up stops the saw. (When the binding
## ends it has to line up and start its cut again.)
func _on_bound() -> void:
	is_sawing = false


## Stands still, faces the tree, and takes a bite out of it on a timer.
func _saw(tree: ForestTree, delta: float) -> void:
	velocity = Vector2.ZERO
	_sprite.rotation = global_position.direction_to(tree.global_position).angle() + PI / 2.0
	if not is_sawing:
		is_sawing = true
		modulate = SAWING_TINT
		_saw_time_left = CONFIG.sawbot_saw_interval  # the first bite takes a moment
	_saw_time_left -= delta
	if _saw_time_left <= 0.0:
		_saw_time_left = CONFIG.sawbot_saw_interval
		Sfx.play(&"saw")
		tree.take_damage(CONFIG.sawbot_saw_damage)  # at 0 HP the tree fells itself


## Where to walk: the nearest grown tree; else the nearest sapling (to wait for
## it to grow); else the middle of the arena.
func _choose_destination() -> Vector2:
	var tree: ForestTree = _nearest_tree(ForestTree.Stage.GROWN, INF)
	if tree == null:
		tree = _nearest_tree(ForestTree.Stage.SAPLING, INF)
	if tree != null:
		return tree.global_position
	return _grid.cell_to_world(_grid.center_cell())


## The nearest tree at the given stage within `max_distance` pixels, or null.
## (INF, infinity, as the distance means "no limit".)
## `lured` false switches the Heart Tree's lure off, for "can my blade touch it?".
func _nearest_tree(stage: ForestTree.Stage, max_distance: float, lured: bool = true) -> ForestTree:
	var best: ForestTree = null
	var best_distance: float = max_distance
	# Every tree adds itself to the "trees" group, so this loop sees all of them.
	for node: Node in get_tree().get_nodes_in_group(ForestTree.GROUP):
		var tree := node as ForestTree
		if tree == null or tree.stage != stage:
			continue
		var distance: float = global_position.distance_to(tree.global_position)
		# The Heart Tree LURES Sawbots: it counts as nearer than it really is.
		if tree.is_heart and lured:
			distance *= CONFIG.heart_tree_lure
		if distance <= best_distance:
			best = tree
			best_distance = distance
	return best
