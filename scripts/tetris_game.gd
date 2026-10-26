class_name TetrisGame
extends RefCounted
## Deterministic, renderer-independent classic falling-block rules.
signal sound_requested(event: String)
signal changed

const WIDTH := 10
const HEIGHT := 20
# NES-style spawn orientations and pivots. No wall kicks.
const SHAPES := [
	[Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0), Vector2i(2,0)], # I
	[Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(1,1)], # O
	[Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0), Vector2i(0,-1)], # T
	[Vector2i(-1,-1), Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)], # J
	[Vector2i(1,-1), Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)], # L
	[Vector2i(0,-1), Vector2i(1,-1), Vector2i(-1,0), Vector2i(0,0)], # S
	[Vector2i(-1,-1), Vector2i(0,-1), Vector2i(0,0), Vector2i(1,0)], # Z
]
const GRAVITY := [48,43,38,33,28,23,18,13,8,6,5,5,5,4,4,4,3,3,3,2,2,2,2,2,2,2,2,2,2,1]
const CLEAR_POINTS := [0,40,100,300,1200]
const SOFT_DROP_INTERVAL := 0.12
var board: Array = []
var rng := RandomNumberGenerator.new()
var piece := 0
var next_piece := 0
var previous_piece := -1
var rotation := 0
var position := Vector2i(4,1)
var score := 0
var lines := 0
var level := 0
var start_level := 0
var game_over := false
var active := false
var paused := false
var gravity_time := 0.0
var entry_time := 0.0
var clear_rows: Array[int] = []
var last_clear := ""
var soft_points := 0
var soft_held := false

func _init() -> void:
	rng.randomize()
	reset_board()

func reset_board() -> void:
	board.clear()
	for y in HEIGHT:
		var row: Array[int] = []
		row.resize(WIDTH)
		row.fill(-1)
		board.append(row)

func start(selected_level: int = 0) -> void:
	reset_board()
	score = 0
	lines = 0
	start_level = clampi(selected_level,0,19)
	level = start_level
	game_over = false
	paused = false
	active = true
	previous_piece = -1
	clear_rows.clear()
	last_clear = ""
	entry_time = 0.0
	next_piece = roll_piece()
	spawn()
	changed.emit()

func roll_piece() -> int:
	var candidate := rng.randi_range(0,7)
	if candidate == 7 or candidate == previous_piece:
		candidate = rng.randi_range(0,6)
	previous_piece = candidate
	return candidate

func cells(kind: int, turn: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell: Vector2i in SHAPES[kind]:
		var p := cell
		if kind != 1:
			# I/S/Z have two states in the classic rotation system.
			var turns := posmod(turn,2) if kind in [0,5,6] else posmod(turn,4)
			for i in turns:
				p = Vector2i(-p.y,p.x)
		result.append(p)
	return result

func fits(at: Vector2i, turn: int) -> bool:
	for cell in cells(piece,turn):
		var p := at + cell
		if p.x < 0 or p.x >= WIDTH or p.y >= HEIGHT or p.y < 0:
			return false
		if board[p.y][p.x] >= 0:
			return false
	return true

func spawn() -> void:
	piece = next_piece
	next_piece = roll_piece()
	rotation = 0
	position = Vector2i(4,1)
	gravity_time = 0.0
	soft_points = 0
	soft_held = false
	if not fits(position,rotation):
		game_over = true
		active = false
		sound_requested.emit("Game over")
	changed.emit()

func can_control() -> bool:
	return active and not paused and entry_time <= 0.0

func move(direction: int) -> bool:
	if can_control() and fits(position + Vector2i(direction,0),rotation):
		position.x += direction
		changed.emit()
		return true
	return false

func rotate_piece(direction: int) -> void:
	if not can_control():
		return
	var turn := posmod(rotation + direction,4)
	if fits(position,turn):
		rotation = turn
		changed.emit()

func step_down(soft: bool = false) -> bool:
	if not can_control():
		return false
	if fits(position + Vector2i.DOWN,rotation):
		position.y += 1
		if soft:
			soft_points += 1
		changed.emit()
		return true
	lock_piece()
	return false

func hard_drop() -> void:
	if not can_control():
		return
	while fits(position + Vector2i.DOWN,rotation):
		position.y += 1
	# Convenience addition; hard drop earns no extra points in this classic mode.
	sound_requested.emit("Hard drop")
	lock_piece()

func lock_piece() -> void:
	score += soft_points
	soft_points = 0
	for cell in cells(piece,rotation):
		var p := position + cell
		board[p.y][p.x] = piece
	clear_rows.clear()
	for y in HEIGHT:
		if not board[y].has(-1):
			clear_rows.append(y)
	if not clear_rows.is_empty():
		score += CLEAR_POINTS[clear_rows.size()] * (level + 1)
		last_clear = ["", "SINGLE", "DOUBLE", "TRIPLE", "TETRIS!"][clear_rows.size()]
		sound_requested.emit(["", "Score single", "Score double", "Score triple", "Score tetris"][clear_rows.size()])
		entry_time = 0.45
	else:
		last_clear = ""
		entry_time = 0.18
	changed.emit()

func finish_clear() -> void:
	var count := clear_rows.size()
	# Remove from bottom to top, then insert empty rows at the top.
	for i in range(count - 1,-1,-1):
		board.remove_at(clear_rows[i])
	for i in count:
		var row: Array[int] = []
		row.resize(WIDTH)
		row.fill(-1)
		board.push_front(row)
	lines += count
	var first_transition := mini((start_level + 1) * 10,maxi(100,start_level * 10 - 50))
	var new_level := start_level
	if lines >= first_transition:
		new_level += 1 + int((lines - first_transition) / 10.0)
	level = new_level
	clear_rows.clear()

func gravity_interval() -> float:
	return GRAVITY[mini(level,29)] / 60.0

func tick(delta: float, soft: bool = false) -> void:
	if not active or paused:
		return
	if entry_time > 0.0:
		entry_time -= delta
		if entry_time <= 0.0:
			finish_clear()
			spawn()
		return
	if soft != soft_held:
		soft_held = soft
		# Switching speeds must not spend accumulated gravity time in a burst.
		gravity_time = 0.0
		if soft and not step_down(true):
			return
	if not soft:
		soft_points = 0 # Only the final continuous soft-drop run scores.
	gravity_time += delta
	var interval := minf(gravity_interval(),SOFT_DROP_INTERVAL) if soft else gravity_interval()
	while gravity_time >= interval and can_control():
		gravity_time -= interval
		if not step_down(soft):
			break
