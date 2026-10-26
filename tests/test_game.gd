extends SceneTree
const Rules = preload("res://scripts/tetris_game.gd")
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var game := Rules.new()
	game.rng.seed = 42
	game.start()
	check(game.board.size() == 20 and game.board[0].size() == 10,"10x20 board")
	for kind in 7:
		for turn in 4:
			var cells := game.cells(kind,turn)
			check(cells.size() == 4,"Four squares per piece")
			var unique := {}
			for cell in cells: unique[cell] = true
			check(unique.size() == 4,"Rotation does not overlap squares")
	game.piece = 1
	game.position = Vector2i(0,18)
	game.rotation = 0
	check(not game.move(-1),"Left wall blocks movement")
	game.position.x = 8
	check(not game.move(1),"Right wall blocks movement")
	game.rotate_piece(1)
	check(game.cells(1,0) == game.cells(1,1),"Square stays fixed when rotated")
	game.paused = true
	var before := game.position
	game.tick(10,true)
	game.hard_drop()
	check(game.position == before and game.entry_time == 0,"Pause freezes gravity and controls")
	game.paused = false
	game.start()
	game.tick(0.7)
	var initial_y: int = game.position.y
	game.tick(0.001,true)
	check(game.position.y == initial_y + 1,"Soft-drop tap moves one row despite accumulated gravity")
	game.tick(0.05,true)
	check(game.position.y == initial_y + 1,"Short soft-drop hold does not repeat early")
	game.tick(0.071,true)
	check(game.position.y == initial_y + 2,"Soft drop repeats after 0.12 seconds")
	game.tick(0.24,true)
	check(game.position.y == initial_y + 4,"Sustained soft drop uses the slower repeat rate")
	game.tick(0.001,false)
	check(game.soft_points == 0,"Releasing soft drop ends continuous drop scoring")
	game.tick(0.001,true)
	check(game.position.y == initial_y + 5,"A fresh soft-drop tap moves exactly one row")
	game.start(19)
	initial_y = game.position.y
	game.tick(0.04,true)
	check(game.position.y == initial_y + 2,"Soft drop never slows high-level gravity")
	for count in range(1,5):
		game.start()
		# A vertical I fills the remaining column in 1–4 full rows.
		for y in range(20-count,20):
			for x in 10: game.board[y][x] = 2 if x != 4 else -1
		game.piece = 0
		game.rotation = 1
		game.position = Vector2i(4,16)
		game.hard_drop()
		check(game.clear_rows.size() == count,"Detect %d-line clear" % count)
		check(game.score == Rules.CLEAR_POINTS[count],"Classic scoring for %d lines" % count)
		game.tick(0.5)
		check(game.lines == count and game.board.size() == 20,"Compact %d-line clear" % count)
		check(game.board[19][0] == -1,"Cleared rows are removed")
	game.start()
	game.lines = 9
	for x in 10: game.board[19][x] = 3 if x != 4 else -1
	game.piece = 0
	game.rotation = 1
	game.position = Vector2i(4,16)
	game.hard_drop()
	check(game.score == 40,"Transition scores at pre-clear level")
	game.tick(0.5)
	check(game.level == 1 and game.lines == 10,"Level increases after ten lines")
	game.start(18)
	game.lines = 129
	game.clear_rows.assign([19])
	game.finish_clear()
	check(game.level == 19,"NES high-start transition threshold")
	game.start(9)
	check(is_equal_approx(game.gravity_interval(),0.1),"Level 9 gravity")
	game.start(19)
	check(is_equal_approx(game.gravity_interval(),2.0/60.0),"Level 19 gravity")
	game.level = 29
	check(is_equal_approx(game.gravity_interval(),1.0/60.0),"Level 29 gravity")
	game.start()
	game.piece = 1
	game.next_piece = 1
	game.position = Vector2i(4,18)
	game.board[1][4] = 2
	game.hard_drop()
	game.tick(0.5)
	check(game.game_over and not game.active,"Blocked spawn ends game")
	game.start()
	check(not game.game_over and game.score == 0 and game.lines == 0,"Restart resets game")
	# Seeded play stress test: random moves, rotations, drops, and restarts.
	for i in 2000:
		if game.game_over: game.start(i % 20)
		game.move(game.rng.randi_range(-1,1))
		game.rotate_piece(game.rng.randi_range(-1,1))
		game.hard_drop()
		game.tick(0.5)
		check(game.board.size() == 20,"Board stays 20 rows during stress play")
	print("Rules: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
