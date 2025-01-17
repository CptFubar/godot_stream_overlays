extends Node2D

export var character_scene: PackedScene = preload("res://scenes/characters_overlay/character.tscn")
export var channel_name: String = "mreliptik"
export var window_title: String = "Characters overlay"

onready var characters = $Characters

onready var gift = $Gift
onready var users = $Users

var credentials = null

var commands_list = "Welcome! I'm eliptikbot, at your service!\nTo control your avatar, whisper me a command.\nCommands available:\n!color #h3h3h3\n!jump\n!speed 500\n!say something"


func _ready() -> void:
	OS.set_window_title(window_title)
	# Connecting to twitch with the websocket, no credentials required
	gift.connect_to_twitch()
	yield(gift, "twitch_connected")
	print("CONNECTED!")
	
	credentials = read_crendentials()
	
	$Polygon2D.polygon = $StaticBody2D.global_transform.xform($StaticBody2D/CollisionPolygon2D.polygon)
	get_tree().get_root().set_transparent_background(true)
#	get_twitch_viewers()

	users.load_users()

func read_crendentials() -> Dictionary:
	var credentials = {"username": "", "oauth": ""}
	var file = File.new()
	file.open("res://twitch_credentials.txt", File.READ)

	var index = 0
	while not file.eof_reached(): # iterate through all lines until the end of file is reached
		var line = file.get_line()
		if index == 0:
			credentials["username"] = line
		elif index == 1:
			credentials["oauth"] = line
			
		index += 1

	file.close()
	
	return credentials
	
func spawn_viewers(viewers):
	var children = $Characters.get_children()
	var viewer_names = []
	for child in children:
		viewer_names.append(child.username)
		
	for i in range(viewers.size()):
		var viewer = viewers[i]
		if viewer in viewer_names: continue
		var instance = character_scene.instance()
		characters.call_deferred("add_child", instance)
		yield(instance, "ready")
		instance.set_username(viewer)
		instance.global_position = Vector2(rand_range(40, 1800), 1080/2)
		instance.initial_pos = instance.global_position
		gift.chat(commands_list)
		if !users.user_exist(viewer):
			users.create_user(viewer, instance.color, true)
		else:
			instance.set_color(users.get_user_color(viewer))
			users.update_user(viewer, null, true)
	users.save_users()
		
func despawn_viewers(viewers):
	var children = $Characters.get_children()
	var viewer_names = []
	for child in children:
		viewer_names.append(child.username)
		
	for viewer in viewers:
		if !viewer in viewer_names: continue
		var idx = viewer_names.find(viewer)
		if idx == -1: continue
		$Characters.get_child(idx).call_deferred("queue_free")
		if !users.user_exist(viewer):
			return
		users.update_user(viewer, null, false)
	users.save_users()
		
func change_viewer_color(user, arg_arr):
	var new_color: Color
	
	var children = $Characters.get_children()
	var viewer_names = []
	var viewer: String
	for child in children:
		viewer_names.append(child.username)
		
	var idx = viewer_names.find(user)
	viewer = viewer_names[idx]
	if idx == -1: return
	
	if arg_arr.size() == 0:
		# Random color
		children[idx].set_random_color()
	else:
		var color_arg: String = arg_arr[0]
		if color_arg.begins_with("#"):
			# Assume its hex code
			new_color = Color(color_arg)
			print(new_color)
			if !new_color: return
			children[idx].set_color(new_color)
			users.update_user(viewer, new_color, null)
			users.save_users()
		else:
			return

func change_viewer_speed(user, arg_arr):
	var children = $Characters.get_children()
	var viewer_names = []
	for child in children:
		viewer_names.append(child.username)
		
	var idx = viewer_names.find(user)
	if idx == -1: return
	
	if arg_arr.size() == 0:
		pass
	else:
		var speed = arg_arr[0].to_float()
		if !speed: return
		children[idx].set_speed(speed)
		
func viewer_say(user, arg_arr):
	var children = $Characters.get_children()
	var viewer_names = []
	for child in children:
		viewer_names.append(child.username)
		
	var idx = viewer_names.find(user)
	if idx == -1: return
	
	print(arg_arr.size())
	if arg_arr.size() == 0:
		pass
	else:
		children[idx].say(arg_arr.join(" "))
		
func viewer_jump(user):
	var children = $Characters.get_children()
	var viewer_names = []
	for child in children:
		viewer_names.append(child.username)
		
	var idx = viewer_names.find(user)
	if idx == -1: return
	
	children[idx].jump()

func reset_viewer(user):
	var children = $Characters.get_children()
	var viewer_names = []
	for child in children:
		viewer_names.append(child.username)
		
	var idx = viewer_names.find(user)
	if idx == -1: return
	
	children[idx].reset()


############### GIFT SIGNALS ##################
func _on_Gift_user_join(sender_data) -> void:
	if !users.is_viewer_joining(sender_data.user): return
	spawn_viewers([sender_data.user])

func _on_Gift_user_part(sender_data) -> void:
	if !users.is_viewer_joining(sender_data.user): return
	despawn_viewers([sender_data.user])

func on_viewer_join(cmd_info : CommandInfo):
	spawn_viewers([cmd_info.sender_data.user])
	
func on_viewer_leave(cmd_info : CommandInfo):
	despawn_viewers([cmd_info.sender_data.user])
	
func on_viewer_reset(cmd_info : CommandInfo):
	reset_viewer(cmd_info.sender_data.user)
	
func on_viewer_color(cmd_info : CommandInfo, arg_arr : PoolStringArray):
	change_viewer_color(cmd_info.sender_data.user, arg_arr)

func on_viewer_jump(cmd_info : CommandInfo):
	viewer_jump(cmd_info.sender_data.user)
	
func on_viewer_speed(cmd_info : CommandInfo, arg_arr : PoolStringArray):
	change_viewer_speed(cmd_info.sender_data.user, arg_arr)
	
func on_viewer_say(cmd_info : CommandInfo, arg_arr : PoolStringArray):
	viewer_say(cmd_info.sender_data.user, arg_arr)

func _on_ChatConnection_connect_pressed(nick_text, auth_text) -> void:
	if credentials["username"] != "" && credentials["oauth"] != "":
		gift.authenticate_oauth(credentials["username"], credentials["oauth"])
	else:
		gift.authenticate_oauth(nick_text, auth_text)
	if(yield(gift, "login_attempt") == false):
		print("Invalid username or token.")
		return
	print("AUTHENTICATED")
	$CanvasLayer/ChatConnection.visible = false
	
	gift.join_channel("mreliptik")
	gift.add_command("join", self, "on_viewer_join")
	gift.add_command("leave", self, "on_viewer_leave")
	gift.add_command("reset", self, "on_viewer_reset", 0, 0, 
		gift.PermissionFlag.EVERYONE, gift.WhereFlag.WHISPER)
	gift.add_command("color", self, "on_viewer_color", 1, 1, 
		gift.PermissionFlag.EVERYONE, gift.WhereFlag.WHISPER)
	gift.add_command("jump", self, "on_viewer_jump", 0, 0, 
		gift.PermissionFlag.EVERYONE, gift.WhereFlag.WHISPER)
	gift.add_command("speed", self, "on_viewer_speed", 1, 1, 
		gift.PermissionFlag.EVERYONE, gift.WhereFlag.WHISPER)
	gift.add_command("say", self, "on_viewer_say", 10, 1, 
		gift.PermissionFlag.EVERYONE, gift.WhereFlag.WHISPER)

func _on_Gift_whisper_message(sender_data, message) -> void:
	print(sender_data.user + ": " + message)

func _on_Gift_chat_message(sender_data, message) -> void:
	pass
