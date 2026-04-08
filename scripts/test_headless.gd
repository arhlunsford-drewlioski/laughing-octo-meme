extends SceneTree

func _init() -> void:
	var player_roster := GoblinDatabase.full_roster().slice(0, 6)
	var opponent_roster := GoblinDatabase.opponent_roster()
	var home := GoblinDatabase.build_default_formation(player_roster)
	var away := GoblinDatabase.build_default_formation(opponent_roster)

	print("=== MATCH SIMULATION ===")
	print("HOME: ", ", ".join(home.get_all().map(func(g): return "%s [%s]" % [g.goblin_name, g.position])))
	print("AWAY: ", ", ".join(away.get_all().map(func(g): return "%s [%s]" % [g.goblin_name, g.position])))
	print("")

	var sim := MatchSimulation.new()
	var snapshot: Dictionary = sim.start_match(home, away)

	var shot_count: int = 0
	var goal_count: int = 0
	var event_counts: Dictionary = {}

	var tick_num: int = 0
	while not sim.is_match_over():
		snapshot = sim.tick()
		tick_num += 1
		if tick_num % 100 == 0:
			for g in snapshot["goblins"]:
				if g["has_ball"]:
					print("  t%d: %s at (%.2f,%.2f) team=%s" % [tick_num, g["name"], g["x"], g["y"], g["team"]])
					break
			if snapshot["ball"]["owner_name"] == "":
				print("  t%d: ball free at (%.2f,%.2f) state=%s" % [tick_num, snapshot["ball"]["x"], snapshot["ball"]["y"], snapshot["ball"]["state"]])
		var events: Array = snapshot["events"]
		for event: Dictionary in events:
			var etype2: String = str(event["type"])
			event_counts[etype2] = event_counts.get(etype2, 0) + 1
			var m: int = int(snapshot["clock"])
			var etype: String = str(event["type"])
			match etype:
				"goal":
					goal_count += 1
					var sc: Array = event["score"]
					print("%d' GOAL! %s! Score: %d-%d" % [m, event["goblin"], sc[0], sc[1]])
				"shot":
					shot_count += 1
					print("%d' Shot: %s (pwr:%.1f acc:%.1f)" % [m, event["goblin"], event["power"], event["accuracy"]])
				"save":
					print("%d' Save: %s stops %s" % [m, event["keeper"], event["shooter"]])
				"miss":
					print("%d' Miss: %s" % [m, event["goblin"]])
				"block":
					print("%d' Block: %s" % [m, event["goblin"]])
				"tackle":
					print("%d' Tackle: %s on %s" % [m, event["goblin"], event["victim"]])
				"foul":
					print("%d' FOUL: %s on %s" % [m, event["goblin"], event["victim"]])
				"dispossessed":
					print("%d' Dispossessed: %s by %s" % [m, event["goblin"], event["by"]])

	var sc: Array = snapshot["score"]
	print("")
	print("FULL TIME: %d - %d" % [sc[0], sc[1]])
	print("Shots: %d | Goals: %d" % [shot_count, goal_count])
	print("")
	print(sim.get_debug_summary())
	print("")
	print("Event counts:")
	for k in event_counts:
		print("  %s: %d" % [k, event_counts[k]])
	quit()
