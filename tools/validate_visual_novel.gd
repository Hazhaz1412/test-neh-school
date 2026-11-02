extends "res://tools/validate_progression.gd"

func choose(view: Control, index: int) -> void:
	view.reveal()
	view.select_choice(index)

func key(view: Control, code: int) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = true
	view._input(event)

func shot(title: String) -> void:
	if DisplayServer.get_name()=="headless": return
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/"+title+".png")

func protocol_reply(quest: Node3D, passed: bool) -> void:
	quest.request.cancel_request()
	quest._received(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"request_id":quest.request_id,"source":"ai","scores":{"understanding":2 if passed else 0,"validation":2 if passed else 0,"support":2 if passed else 0},"unsafe":false,"feedback":"Protocol fixture only."}).to_utf8_buffer())

func validate() -> void:
	school = load("res://scenes/school_runtime.tscn").instantiate()
	school.play_opening_on_launch = false
	root.add_child(school)
	current_scene = school
	await frames(15)
	school.survival.start_run(false)
	school.player.set_physics_process(false)
	school.player.set_process_unhandled_input(false)
	school.survival.set_physics_process(false)
	story = school.progression
	story.set_physics_process(false)
	story.stage = story.Stage.GATE_INTERFERENCE
	story.stage_time = 3
	school.survival.begin_midnight()
	story.runner.active = false
	story.runner.room_hidden = true
	school.player.position = story.runner.refuge.to_global(Vector3(-5,.05,1))
	story.enter_lan_room()
	var view: Control = story.lan_view
	check(view.visible and not story.panel.visible and view.choices.get_child_count()==5,"Lan opens a visual novel with five independent questions rather than linear Next pages")
	check(view.is_typing() and view.choices.get_child(0).disabled,"Choices wait for the current line to be revealed")
	key(view,KEY_5)
	check(not view.is_typing() and story.lan_node=="hub","The first hotkey reveals text without accidentally selecting a question")
	await shot("night1-vn-lan-questions")
	key(view,KEY_5)
	check(story.lan_node=="question" and view.speaker.text=="Bạn" and view.speech.text==story.dialogue_data.lan.questions[4].question,"The player can ask the last question first using its keyboard shortcut")
	choose(view,0)
	check(view.speaker.text=="Lan" and view.speech.text.contains("gầm bàn"),"Lan answers the actual question chosen by the player")
	view.reveal()
	await shot("night1-vn-lan-answer")
	choose(view,0)
	story.advance_lan()
	check(story.stage==story.Stage.LAN_DIALOGUE and story.lan_seen.size()==1,"An escape question alone cannot skip the explanation of the curse")
	var knows_an := false
	for question in story.dialogue_data.lan.questions:
		var words: String = (question.question+question.answer).to_lower()
		if words.contains("nguyễn") or words.contains("bé an") or words.contains("sân thượng") or words.contains("cuốn vở"): knows_an = true
	check(not knows_an and not story.dialogue_data.lan.required.has("an"),"Lan knows the curse and trapped souls, not An, the clues or An's location")
	story.close()
	check(not story.panel_visible() and view.portrait_viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED and not view.actor.is_processing(),"Closing Lan hides the dialogue and stops all portrait rendering/rig updates")
	check(await approach(story.lan,1.0) and story.lan.interact(school.player) and story.lan_seen.has("escape"),"Actual E resumes Lan while keeping questions already heard")
	finish_lan_dialogue()
	check(story.stage==story.Stage.TABLE_ESCAPE and not story.lan_view.visible and story.runner.table.get_node("Interaction").collision_layer==16,"Choosing the final player response unlocks the real table only after the required explanations")
	story.bypass_for_test()
	var quest: Node3D = school.soul_quest
	for i in range(quest.memories.size()): story.record_evidence(i)
	school.player.position = quest.SOUL_APPROACH
	school.player.camera.look_at(quest.soul.global_position+Vector3.UP)
	await frames(3)
	check(quest.begin_comfort(school.player),"A real E ray opens An's visual novel after the three clues")
	view = quest.dialog
	check(not quest.reply.visible and view.choices.get_child_count()==4,"An offers questions instead of a visible text-entry form")
	check(school.simulation_active() and not school.test_cheats.enabled,"Dialogue retains the normal running clock without enabling cheats")
	view.reveal()
	await shot("night1-vn-an-questions")
	choose(view,2)
	choose(view,0)
	check(quest.topic==2 and quest.dialogue_phase=="answers" and view.choices.get_child_count()==4 and view.speech.text.contains("viết"),"The notebook can be discussed first and produces its own answer and three reply choices")
	view.reveal()
	await shot("night1-vn-an-replies")
	choose(view,2)
	var selected: String = quest.reply.text
	check(view.speaker.text=="Bạn" and selected==quest._topic_data(2).replies[2] and quest.accepted.is_empty(),"Choosing a reply displays the player's exact line and grants no automatic trust")
	# Local protocol fixtures only; this never contacts a live AI provider.
	school.comfort_ai_url = "http://127.0.0.1:1/comfort"
	choose(view,0)
	check(quest.pending and quest.dialogue_phase=="waiting","Confirming a choice starts the existing AI request")
	quest.ask_topic(0)
	check(quest.topic==2,"A pending response cannot be switched to another memory")
	protocol_reply(quest,false)
	check(quest.accepted.is_empty() and view.speech.text==quest._topic_data(2).retry_line,"A rejected reply changes An's reaction without advancing rescue")
	choose(view,0)
	choose(view,1)
	choose(view,0)
	protocol_reply(quest,true)
	check(quest.accepted.has(2) and quest.accepted.size()==1 and view.speech.text==quest._topic_data(2).accepted_line,"Accepted replies change the character's reaction and only the chosen memory")
	view.reveal()
	await shot("night1-vn-an-reaction")
	choose(view,0)
	choose(view,0)
	choose(view,0)
	choose(view,0)
	choose(view,0)
	var canceled: String = quest.request_id
	school.player.invulnerable_time = 0
	school.player.take_damage(5)
	check(not view.visible and not quest.pending and quest.accepted.size()==1,"Damage closes the visual novel and cancels pending dialogue while preserving earned trust")
	quest._received(HTTPRequest.RESULT_SUCCESS,200,[],JSON.stringify({"request_id":canceled,"source":"ai","scores":{"understanding":2,"validation":2,"support":2},"unsafe":false,"feedback":"late"}).to_utf8_buffer())
	check(quest.accepted.size()==1,"A response arriving after closing cannot accept another memory")
	check(quest.begin_comfort(school.player),"An's conversation can be resumed after interruption")
	for index in [1,0]:
		choose(view,index)
		choose(view,0)
		choose(view,0)
		choose(view,0)
		protocol_reply(quest,true)
		choose(view,0)
	check(quest.dialogue_phase=="farewell" and view.visible and not school.survival.soul_rescued,"An's farewell remains visible until the player chooses to say goodbye")
	view.reveal()
	await shot("night1-vn-an-farewell")
	choose(view,0)
	check(school.survival.soul_rescued and not view.visible and not school.survival.won,"Acknowledging the farewell frees An while the night continues")
	school.survival.active = false
	school.survival.start_run(false)
	check(story.lan_seen.is_empty() and quest.accepted.is_empty() and not view.visible and not story.lan_view.visible,"Restart clears dialogue choices, trust and both visual novel views")
	var file := FileAccess.open("res://docs/visual-novel-validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"ai":"local protocol fixtures, not live grading"},"\t"))
	file.close()
	print("RESULT / visual novel ",checks," checks, ",failures," failures")
	school.queue_free()
	await frames(5)
	await create_timer(.2).timeout
	quit(1 if failures else 0)
