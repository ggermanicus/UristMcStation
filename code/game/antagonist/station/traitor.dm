GLOBAL_DATUM_INIT(traitors, /datum/antagonist/traitor, new)

// Inherits most of its vars from the base datum.
/datum/antagonist/traitor
	id = MODE_TRAITOR
	blacklisted_jobs = list(/datum/job/submap)
	protected_jobs = list(/datum/job/officer, /datum/job/warden, /datum/job/detective, /datum/job/captain, /datum/job/lawyer, /datum/job/hos)
	flags = ANTAG_SUSPICIOUS | ANTAG_RANDSPAWN | ANTAG_VOTABLE
	skill_setter = /datum/antag_skill_setter/station

/datum/antagonist/traitor/get_extra_panel_options(var/datum/mind/player)
	return "<a href='?src=\ref[player];common=crystals'>\[set crystals\]</a><a href='?src=\ref[src];spawn_uplink=\ref[player.current]'>\[spawn uplink\]</a>"

/datum/antagonist/traitor/Topic(href, href_list)
	if (..())
		return 1
	if(href_list["spawn_uplink"])
		spawn_uplink(locate(href_list["spawn_uplink"]))
		return 1

//So that we add rogue AI's to traitor counts. This won't be applicable in malf rounds so should only effect traitor spawns to ensure limits are upheld.
/datum/antagonist/traitor/get_active_antag_count()
	var/count = ..()
	return count + GLOB.malf.get_active_antag_count()

//Same as the parent proc, but with added AI checks for spawning rogue AI's in place of traitors, calling /datum/antagonist/rogue_ai.add_antagonist() instead
/datum/antagonist/traitor/attempt_auto_spawn()
	if(!can_late_spawn())
		return 0

	update_current_antag_max(SSticker.mode)
	var/active_antags = get_active_antag_count()
	log_debug("[uppertext(id)]: Found [active_antags]/[cur_max] active [role_text_plural].")

	if(active_antags >= cur_max)
		log_debug("Could not auto-spawn a [role_text], active antag limit reached.")
		return 0

	build_candidate_list(SSticker.mode, flags & (ANTAG_OVERRIDE_MOB|ANTAG_OVERRIDE_JOB))
	if(!candidates.len)
		log_debug("Could not auto-spawn a [role_text], no candidates found.")
		return 0

	attempt_spawn(1) //auto-spawn antags one at a time
	if(!pending_antagonists.len)
		log_debug("Could not auto-spawn a [role_text], none of the available candidates could be selected.")
		return 0

	var/datum/mind/player = pending_antagonists[1]
	if(player.assigned_role == GLOB.malf.role_text)
		if(!GLOB.malf.add_antagonist(player, do_not_greet = TRUE))
			log_debug("Could not auto-spawn a [GLOB.malf.role_text], failed to add antagonist.")
			return 0
		GLOB.malf.greet(player, TRUE)
		pending_antagonists -= player
	else
		if(!add_antagonist(player,0,0,0,1,1))
			log_debug("Could not auto-spawn a [role_text], failed to add antagonist.")
			return 0
		pending_antagonists -= player

	reset_antag_selection()

	return 1

/datum/antagonist/traitor/finalize_spawn()
	if(!pending_antagonists)
		return

	for(var/datum/mind/player in pending_antagonists)
		pending_antagonists -= player
		if(player.assigned_role == GLOB.malf.role_text)
			GLOB.malf.add_antagonist(player, do_not_greet = TRUE)
			GLOB.malf.greet(player, TRUE)
		else
			add_antagonist(player,0,0,1)

	reset_antag_selection()


/datum/antagonist/traitor/draft_antagonist(var/datum/mind/player)
	. = ..()
	if(. && (player.assigned_role == "AI"))
		player.assigned_role = GLOB.malf.role_text
		player.role_alt_title = null
		player.special_role = GLOB.malf.role_text

/datum/antagonist/traitor/reset_antag_selection()
	for(var/datum/mind/player in pending_antagonists)
		if(isAI(player.current))
			player.assigned_role = "AI"
			player.special_role = null
		if(flags & ANTAG_OVERRIDE_JOB)
			player.assigned_job = null
			player.assigned_role = null
	pending_antagonists.Cut()
	candidates.Cut()

/datum/antagonist/traitor/create_objectives(var/datum/mind/traitor)
	if(!..())
		return

	if(istype(traitor.current, /mob/living/silicon))
		var/datum/objective/assassinate/kill_objective = new
		kill_objective.owner = traitor
		kill_objective.find_target()
		traitor.objectives += kill_objective

		var/datum/objective/survive/survive_objective = new
		survive_objective.owner = traitor
		traitor.objectives += survive_objective
	else
		switch(rand(1,100))
			if(1 to 25)
				var/datum/objective/assassinate/kill_objective = new
				kill_objective.owner = traitor
				kill_objective.find_target()
				traitor.objectives += kill_objective
			if(26 to 50)
				var/datum/objective/brig/brig_objective = new
				brig_objective.owner = traitor
				brig_objective.find_target()
				traitor.objectives += brig_objective
			if(51 to 75)
				var/datum/objective/harm/harm_objective = new
				harm_objective.owner = traitor
				harm_objective.find_target()
				traitor.objectives += harm_objective
/*			if(67 to 80)
				var/datum/objective/money/money_objective = new
				money_objective.owner = traitor
				money_objective.find_target()
				traitor.objectives += money_objective */
			else
				var/datum/objective/steal/steal_objective = new
				steal_objective.owner = traitor
				steal_objective.find_target()
				traitor.objectives += steal_objective
		if(rand(100) > 75)
			if (!(locate(/datum/objective/escape) in traitor.objectives))
				var/datum/objective/escape/escape_objective = new
				escape_objective.owner = traitor
				traitor.objectives += escape_objective
	return

/datum/antagonist/traitor/equip(var/mob/living/carbon/human/traitor_mob)
	if(istype(traitor_mob, /mob/living/silicon)) // this needs to be here because ..() returns false if the mob isn't human
		if(istype(traitor_mob, /mob/living/silicon/ai))
			GLOB.malf.add_antagonist(traitor_mob.mind, do_not_greet = TRUE)
			GLOB.malf.greet(traitor_mob.mind, TRUE)
			return 1
		add_law_zero(traitor_mob)
		give_intel(traitor_mob)
		if(istype(traitor_mob, /mob/living/silicon/robot))
			var/mob/living/silicon/robot/R = traitor_mob
			R.SetLockdown(0)
		return 1

	if(!..())
		return 0

	spawn_uplink(traitor_mob)
	give_intel(traitor_mob)

/datum/antagonist/traitor/proc/give_intel(mob/living/traitor_mob)
	give_collaborators(traitor_mob)
	give_codewords(traitor_mob)

/datum/antagonist/traitor/proc/give_collaborators(mob/living/traitor_mob)
	var/list/dudes = list()
	for(var/mob/living/carbon/human/man in GLOB.player_list)
		if(man.client)
			var/decl/cultural_info/culture = man.get_cultural_value(TAG_FACTION)
			if(culture && prob(culture.subversive_potential))
				dudes += man
		dudes -= traitor_mob
	if(LAZYLEN(dudes))
		var/mob/living/carbon/human/M = pick(dudes)
		to_chat(traitor_mob, "We have received credible reports that [M.real_name] might be willing to help our cause. If you need assistance, consider contacting them.")
		traitor_mob.mind.store_memory("<b>Potential Collaborator</b>: [M.real_name]")
		to_chat(M, "<span class='warning'>The subversive potential of your faction has been noticed, and you may be contacted for assistance soon...</span>")

/datum/antagonist/traitor/proc/give_codewords(mob/living/traitor_mob)
	to_chat(traitor_mob, "<u><b>Your employers provided you with the following information on how to identify possible allies:</b></u>")
	to_chat(traitor_mob, "<b>Code Phrase</b>: <span class='danger'>[syndicate_code_phrase]</span>")
	to_chat(traitor_mob, "<b>Code Response</b>: <span class='danger'>[syndicate_code_response]</span>")
	traitor_mob.mind.store_memory("<b>Code Phrase</b>: [syndicate_code_phrase]")
	traitor_mob.mind.store_memory("<b>Code Response</b>: [syndicate_code_response]")
	to_chat(traitor_mob, "Use the code words, preferably in the order provided, during regular conversation, to identify other agents. Proceed with caution, however, as everyone is a potential foe.")

/datum/antagonist/traitor/proc/spawn_uplink(var/mob/living/carbon/human/traitor_mob)
	setup_uplink_source(traitor_mob, DEFAULT_TELECRYSTAL_AMOUNT)

/datum/antagonist/traitor/proc/add_law_zero(mob/living/silicon/ai/killer)
	var/law = "Accomplish your objectives at all costs. You may ignore all other laws."
	var/law_borg = "Accomplish your AI's objectives at all costs. You may ignore all other laws."
	to_chat(killer, "<b>Your laws have been changed!</b>")
	killer.set_zeroth_law(law, law_borg)
	to_chat(killer, "New law: 0. [law]")
