extends Control

const Rules = preload("res://scripts/tetris_game.gd")
const BG := Color("090f19")
const PANEL := Color("121e2c")
const INK := Color("e5edf2")
const MUTED := Color("7f95a7")
const PALETTES := [
	[Color("5bb9f0"), Color("4764d7"), Color("dbedf7")],
	[Color("73d6a2"), Color("21947b"), Color("e4f4c8")],
	[Color("c198ef"), Color("7752bd"), Color("f3dcff")],
	[Color("ed9c5c"), Color("c65d47"), Color("fff1c9")],
	[Color("ee88aa"), Color("ac426a"), Color("ffe2eb")],
	[Color("62d4d5"), Color("267fba"), Color("d6fff4")],
	[Color("c7ce59"), Color("6b9a43"), Color("f7f4c7")],
	[Color("8b9ff4"), Color("5157aa"), Color("e5e7ff")],
	[Color("e97862"), Color("9f4662"), Color("ffdab5")],
	[Color("c4d5e5"), Color("647f9b"), Color("ffffff")],
]
const AUDIO_DIR := "res://UI Sci-Fi SFXs Confirm Pack Vol 1/"
const BOARD_ORIGIN := Vector2(26,172)
const CELL := 28.0
const BUTTONS := {
	"left": Rect2(26,774,91,66), "down": Rect2(127,774,91,66),
	"right": Rect2(228,774,91,66),
	"ccw": Rect2(26,852,141,64), "cw": Rect2(177,852,142,64),
	"drop": Rect2(333,774,121,142),
	"pause": Rect2(372,36,82,44), "mute": Rect2(282,36,80,44),
	"minus": Rect2(100,510,60,48), "plus": Rect2(320,510,60,48),
	"primary": Rect2(80,586,320,62), "menu": Rect2(80,666,320,48),
}
var game := Rules.new()
var font: Font = ThemeDB.fallback_font
var view_scale := 1.0
var view_offset := Vector2.ZERO
var touches: Dictionary = {}
var keys: Dictionary = {}
var last_direction := 0
var repeat_time := 0.0
var selected_level := 0
var best := 0
var muted := false
var screen := "title"
var new_record := false
var sound_players: Dictionary = {}
var saved_score := 0

func _ready() -> void:
	get_tree().auto_accept_quit = false
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		best = int(config.get_value("game","best",0))
		muted = bool(config.get_value("game","muted",false))
	game.changed.connect(_on_changed)
	game.sound_requested.connect(_play_sound)
	for event in ["Hard drop","Score single","Score double","Score triple","Score tetris","Game over","New highscore"]:
		var player := AudioStreamPlayer.new()
		player.stream = load(AUDIO_DIR + event + ".wav")
		player.volume_db = -9.0
		add_child(player)
		sound_players[event] = player
	resized.connect(queue_redraw)
	_update_transform()

func _update_transform() -> void:
	# Fit the complete playfield into the OS safe area, including cutouts.
	var available := Rect2(Vector2.ZERO,size)
	if OS.has_feature("mobile"):
		var safe := DisplayServer.get_display_safe_area()
		var window_size := Vector2(DisplayServer.window_get_size())
		if window_size.x > 0 and window_size.y > 0:
			available = Rect2(Vector2(safe.position) * size / window_size,Vector2(safe.size) * size / window_size)
	view_scale = minf(available.size.x / 480.0,available.size.y / 960.0)
	view_offset = available.position + (available.size - Vector2(480,960) * view_scale) / 2.0

func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("game","best",best)
	config.set_value("game","muted",muted)
	config.save("user://settings.cfg")

func _play_sound(event: String) -> void:
	if not muted and sound_players.has(event):
		sound_players[event].play()

func _on_changed() -> void:
	if game.score > best:
		best = game.score
		if not new_record:
			new_record = true
			_play_sound("New highscore")
	if game.score != saved_score:
		saved_score = game.score
		_save()
	if game.game_over:
		screen = "over"
		_clear_controls()
	queue_redraw()

func _clear_controls() -> void:
	touches.clear()
	keys.clear()
	last_direction = 0
	repeat_time = 0.0

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		if screen == "play":
			_pause()
	elif what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if screen == "play":
			_pause()
		elif screen == "pause":
			_resume()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
		get_tree().quit()

func _pause() -> void:
	game.paused = true
	screen = "pause"
	_clear_controls()
	_save()
	queue_redraw()

func _resume() -> void:
	game.paused = false
	screen = "play"
	_clear_controls()
	queue_redraw()

func _start() -> void:
	_clear_controls()
	new_record = false
	saved_score = 0
	screen = "play"
	game.start(selected_level)

func _held(action: String) -> bool:
	return touches.values().has(action) or keys.values().has(action)

func _process(delta: float) -> void:
	if screen != "play":
		return
	var direction := int(_held("right")) - int(_held("left"))
	if direction != last_direction:
		last_direction = direction
		repeat_time = 16.0 / 60.0
		if direction != 0:
			game.move(direction)
	elif direction != 0:
		repeat_time -= delta
		while repeat_time <= 0.0:
			game.move(direction)
			repeat_time += 6.0 / 60.0
	game.tick(delta,_held("down"))
	if game.entry_time > 0.0:
		queue_redraw()

func _action_at(point: Vector2) -> String:
	var allowed: Array = ["left","right","down","cw","ccw","drop","pause","mute"] if screen == "play" else ["primary","menu","mute"]
	if screen == "title":
		allowed.append_array(["minus","plus"])
	for action: String in allowed:
		if BUTTONS[action].has_point(point):
			return action
	return ""

func _activate(action: String) -> void:
	match action:
		"cw": game.rotate_piece(1)
		"ccw": game.rotate_piece(-1)
		"drop": game.hard_drop()
		"pause": _pause()
		"primary":
			if screen == "pause": _resume()
			else: _start()
		"menu":
			if screen != "title":
				screen = "title"
				game.active = false
				_clear_controls()
		"minus": selected_level = maxi(0,selected_level - 1)
		"plus": selected_level = mini(19,selected_level + 1)
		"mute":
			muted = not muted
			if muted:
				for player: AudioStreamPlayer in sound_players.values(): player.stop()
			_save()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo:
			return
		var mapping := {KEY_LEFT:"left", KEY_A:"left", KEY_RIGHT:"right", KEY_D:"right", KEY_DOWN:"down", KEY_S:"down", KEY_UP:"cw", KEY_X:"cw", KEY_Z:"ccw", KEY_SPACE:"drop"}
		if event.pressed:
			if event.keycode in [KEY_ESCAPE,KEY_P]:
				if screen == "play": _pause()
				elif screen == "pause": _resume()
			elif event.keycode == KEY_ENTER and screen != "play":
				_activate("primary")
			elif event.keycode == KEY_M:
				_activate("mute")
			elif screen == "play" and mapping.has(event.keycode):
				keys[event.keycode] = mapping[event.keycode]
				_activate(mapping[event.keycode])
		else:
			keys.erase(event.keycode)
		queue_redraw()
	elif event is InputEventScreenTouch:
		_pointer(event.index,event.position,event.pressed)
	elif event is InputEventScreenDrag:
		# Sliding off a held control releases it; sliding onto another moves it.
		if touches.has(event.index):
			var action := _action_at((event.position - view_offset) / view_scale)
			var old: String = touches[event.index]
			touches[event.index] = action if action in ["left","right","down"] else ""
			if old != touches[event.index]: queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer(-1,event.position,event.pressed)
	elif event is InputEventMouseMotion and touches.has(-1):
		var point: Vector2 = (event.position - view_offset) / view_scale
		if touches[-1] != "" and not BUTTONS[touches[-1]].has_point(point):
			touches[-1] = ""
			queue_redraw()

func _pointer(id: int, at: Vector2, pressed: bool) -> void:
	if pressed:
		var action := _action_at((at - view_offset) / view_scale)
		touches[id] = action
		_activate(action)
	else:
		touches.erase(id)
	queue_redraw()

func _text(value: String, at: Vector2, font_size: int = 16, color: Color = INK) -> void:
	draw_string(font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _center(value: String, rect: Rect2, font_size: int = 18, color: Color = INK) -> void:
	var measured := font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size)
	_text(value,rect.position + Vector2((rect.size.x - measured.x)/2.0,(rect.size.y + font_size * 0.70)/2.0),font_size,color)

func _accent() -> Color:
	return PALETTES[game.level % 10][0]

func _block(at: Vector2, kind: int, cell_size: float = CELL) -> void:
	var palette: Array = PALETTES[game.level % 10]
	var color: Color = palette[[2,2,0,1,1,0,0][kind]]
	draw_rect(Rect2(at + Vector2.ONE,Vector2.ONE * (cell_size - 2)),color)
	draw_rect(Rect2(at + Vector2(4,4),Vector2.ONE * (cell_size - 8)),color.darkened(0.18))
	draw_line(at + Vector2(3,3),at + Vector2(cell_size-4,3),color.lightened(0.25),2)

func _button(action: String, label: String, highlight: bool = false, font_size: int = 20) -> void:
	var rect: Rect2 = BUTTONS[action]
	var held := _held(action)
	var color := _accent() if highlight or held else PANEL
	draw_rect(rect,color)
	draw_rect(rect,_accent() if highlight or held else Color("304356"),false,1)
	_center(label,rect,font_size,BG if highlight or held else INK)

func _draw() -> void:
	_update_transform()
	draw_rect(Rect2(Vector2.ZERO,size),BG)
	draw_set_transform(view_offset,0,Vector2.ONE * view_scale)
	_text("MY TETRIS",Vector2(26,62),30)
	_text("CLASSIC / MARATHON",Vector2(27,87),12,MUTED)
	_button("pause","II",false,22)
	draw_line(Vector2(26,109),Vector2(454,109),Color("2a3b4d"),1)
	_text("SCORE",Vector2(26,136),12,MUTED)
	_text("%07d" % game.score,Vector2(26,160),24)
	_text("BEST",Vector2(226,136),12,MUTED)
	_text("%07d" % best,Vector2(226,160),24,_accent())
	draw_rect(Rect2(BOARD_ORIGIN - Vector2(2,2),Vector2(284,564)),Color("354b61"),false,2)
	draw_rect(Rect2(BOARD_ORIGIN,Vector2(280,560)),Color("080c13"))
	for y in 20:
		for x in 10:
			var at := BOARD_ORIGIN + Vector2(x,y) * CELL
			draw_rect(Rect2(at,Vector2.ONE * CELL),Color("131d29"),false,0.5)
			if game.board[y][x] >= 0:
				_block(at,game.board[y][x])
	if game.entry_time <= 0.0 and (game.active or game.game_over):
		for cell in game.cells(game.piece,game.rotation):
			_block(BOARD_ORIGIN + Vector2(game.position + cell) * CELL,game.piece)
	for y in game.clear_rows:
		var flash := Color(1,1,1,0.3 + 0.3 * sin(game.entry_time * 45))
		draw_rect(Rect2(BOARD_ORIGIN + Vector2(0,y * CELL),Vector2(280,CELL)),flash)
	_text("NEXT",Vector2(333,195),13,MUTED)
	draw_rect(Rect2(333,211,121,103),PANEL)
	if screen != "title":
		var preview := game.cells(game.next_piece,0)
		var low := Vector2i(99,99)
		var high := Vector2i(-99,-99)
		for cell in preview:
			low = low.min(cell)
			high = high.max(cell)
		var dimensions := Vector2(high - low + Vector2i.ONE) * 23
		var origin := Vector2(393.5,262.5) - dimensions / 2
		for cell in preview: _block(origin + Vector2(cell - low) * 23,game.next_piece,23)
	_text("LEVEL",Vector2(333,356),13,MUTED)
	_text("%02d" % game.level,Vector2(333,393),34,_accent())
	_text("LINES",Vector2(333,443),13,MUTED)
	_text("%03d" % game.lines,Vector2(333,480),34)
	var progress := game.lines % 10
	for i in 10:
		draw_rect(Rect2(333 + i * 12,500,8,5),_accent() if i < progress else PANEL)
	_text(game.last_clear,Vector2(333,547),16,_accent())
	_text("10 x 20",Vector2(333,618),13,MUTED)
	_text("NO LIMIT",Vector2(333,640),13,MUTED)
	_button("mute","SFX OFF" if muted else "SFX ON",false,14)
	_text("MOVE / SOFT DROP",Vector2(26,759),12,MUTED)
	_text("HARD DROP",Vector2(333,759),12,MUTED)
	_button("left","<",false,28)
	_button("down","v",false,28)
	_button("right",">",false,28)
	_button("ccw","Z  /  LEFT",false,15)
	_button("cw","X  /  RIGHT",false,15)
	_button("drop","DROP",true,22)
	_center("ROTATE",Rect2(26,918,293,22),11,MUTED)
	if screen != "play":
		_draw_overlay()

func _draw_overlay() -> void:
	draw_rect(Rect2(14,164,452,572),Color(0.02,0.04,0.07,0.96))
	draw_rect(Rect2(54,258,372,442),PANEL)
	draw_rect(Rect2(54,258,372,4),_accent())
	var title := "READY TO STACK"
	var subtitle := "A classic, one square at a time."
	var primary := "PLAY"
	if screen == "pause":
		title = "PAUSED"
		subtitle = "Take your time. Your stack can wait."
		primary = "RESUME"
	elif screen == "over":
		title = "GAME OVER"
		subtitle = "NEW HIGH SCORE" if new_record else "One more round?"
		primary = "PLAY AGAIN"
	_center(title,Rect2(54,289,372,50),28)
	_center(subtitle,Rect2(54,346,372,30),15,MUTED)
	if screen == "title":
		_center("10 x 20   /   NEXT PIECE   /   CLASSIC SPEED",Rect2(54,395,372,30),12,_accent())
		_center("START LEVEL",Rect2(54,466,372,30),13,MUTED)
		_center("%02d" % selected_level,Rect2(180,507,120,52),32)
		_button("minus","-",false,24)
		_button("plus","+",false,24)
	else:
		_center("SCORE   %07d" % game.score,Rect2(54,404,372,45),24,_accent())
		_center("LEVEL %02d     /     %d LINES" % [game.level,game.lines],Rect2(54,467,372,30),16,MUTED)
	_button("primary",primary,true,20)
	if screen != "title":
		_button("menu","MAIN MENU",false,14)
	else:
		_center("HOLD ARROWS TO MOVE  /  TAP TO ROTATE",Rect2(54,658,372,30),11,MUTED)
		_center("SFX: Paolo Migliorisi - Urizen Composer / OGA-BY 4.0",Rect2(14,936,452,12),10,MUTED)
		_center("opengameart.org/content/sci-fi-ui-sfx",Rect2(14,948,452,12),9,MUTED)
