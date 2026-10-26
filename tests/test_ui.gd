extends SceneTree
var failures := 0
var app: Control

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func touch(id: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = app.view_offset + point * app.view_scale
	event.pressed = pressed
	app._input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	await process_frame
	check(app.screen == "title","Starts on title screen")
	# Mute during automation, and preserve existing player settings.
	var original_best: int = app.best
	var original_muted: bool = app.muted
	app.muted = true
	touch(0,Vector2(350,534),true)
	touch(0,Vector2(350,534),false)
	check(app.selected_level == 1,"Touch level selection")
	touch(0,Vector2(240,617),true)
	touch(0,Vector2(240,617),false)
	check(app.screen == "play" and app.game.level == 1,"Touch starts selected level")
	touch(0,Vector2(70,800),true)
	touch(1,Vector2(240,880),true)
	check(app._held("left") and app._held("cw"),"Independent multitouch controls")
	app._process(0.01)
	check(app.game.position.x == 3,"Held touch moves piece")
	touch(0,Vector2(70,800),false)
	touch(1,Vector2(240,880),false)
	check(not app._held("left"),"Touch release clears movement")
	touch(0,Vector2(410,58),true)
	check(app.screen == "pause" and app.game.paused,"Pause button")
	touch(0,Vector2(410,58),false)
	touch(0,Vector2(240,617),true)
	touch(0,Vector2(240,617),false)
	check(app.screen == "play" and not app.game.paused,"Resume button")
	app._notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(app.screen == "pause" and app.touches.is_empty(),"Focus loss pauses and clears touches")
	app._resume()
	app.set_process(false) # Freeze a representative stack for the screenshot.
	app.game.active = true
	for y in range(15,20):
		for x in range(10):
			if x != 6 and (y >= 18 or x < 3 or x > 7):
				app.game.board[y][x] = (x + y) % 7
	app.best = maxi(original_best,18720)
	app.game.score = 12480
	app.game.lines = 27
	app.game.level = 2
	app.game.piece = 2
	app.game.position = Vector2i(5,10)
	app.game.next_piece = 0
	app.queue_redraw()
	await process_frame
	await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/gameplay.png")
		app.screen = "title"
		app.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://builds/title.png")
	# Resize to a short and a tall phone; all controls must fit.
	for dimensions in [Vector2i(360,640),Vector2i(412,915),Vector2i(540,1200)]:
		root.size = dimensions
		await process_frame
		app._update_transform()
		var bottom_right: Vector2 = app.view_offset + Vector2(480,960) * app.view_scale
		check(bottom_right.x <= app.size.x + 1 and bottom_right.y <= app.size.y + 1,"Portrait layout fits %s" % dimensions)
	app.best = original_best
	app.muted = original_muted
	app._save()
	print("UI: %d failures" % failures)
	quit(1 if failures else 0)
