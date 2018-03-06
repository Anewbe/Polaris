//DO NOT CALL handle_statuses() from this proc, it's called from living/Life() as long as this returns a true value.
/mob/living/carbon/human/handle_regular_status_updates()
	if(!handle_some_updates())
		return 0

	if(status_flags & GODMODE)	return 0

	//SSD check, if a logged player is awake put them back to sleep!
	if(species.get_ssd(src) && !client && !teleop)
		Sleeping(2)
	if(stat == DEAD)	//DEAD. BROWN BREAD. SWIMMING WITH THE SPESS CARP
		blinded = 1
		silent = 0
	else				//ALIVE. LIGHTS ARE ON
		updatehealth()	//TODO

		if(health <= config.health_threshold_dead || (should_have_organ("brain") && !has_brain()))
			death()
			blinded = 1
			silent = 0
			return 1

		//UNCONSCIOUS. NO-ONE IS HOME
		if((getOxyLoss() > (species.total_health/2)) || (health <= config.health_threshold_crit))
			Paralyse(3)

		if(hallucination)
			if(hallucination >= 20 && !(species.flags & (NO_POISON|IS_PLANT|NO_HALLUCINATION)) )
				if(prob(3))
					fake_attack(src)
				if(!handling_hal)
					spawn handle_hallucinations() //The not boring kind!
				if(client && prob(5))
					client.dir = pick(2,4,8)
					spawn(rand(20,50))
						client.dir = 1

			hallucination = max(0, hallucination - 2)
		else
			for(var/atom/a in hallucinations)
				qdel(a)

		//Brain damage from Oxyloss
		if(should_have_organ("brain"))
			var/brainOxPercent = 0.015		//Default 1.5% of your current oxyloss is applied as brain damage, 50 oxyloss is 1 brain damage
			if(CE_STABLE in chem_effects)
				brainOxPercent = 0.008		//Halved in effect
			if(oxyloss >= 20 && prob(5))
				adjustBrainLoss(brainOxPercent * oxyloss)

		if(halloss >= species.total_health)
			src << "<span class='notice'>You're in too much pain to keep going...</span>"
			src.visible_message("<B>[src]</B> slumps to the ground, too weak to continue fighting.")
			Paralyse(10)
			setHalLoss(species.total_health - 1)

		if(paralysis || sleeping)
			blinded = 1
			set_stat(UNCONSCIOUS)
			animate_tail_reset()
			adjustHalLoss(-3)

			if(sleeping)
				handle_dreams()
				if (mind)
					//Are they SSD? If so we'll keep them asleep but work off some of that sleep var in case of stoxin or similar.
					if(client || sleeping > 3)
						AdjustSleeping(-1)
				if( prob(2) && health && !hal_crit )
					spawn(0)
						emote("snore")
		//CONSCIOUS
		else
			set_stat(CONSCIOUS)

		//Periodically double-check embedded_flag
		if(embedded_flag && !(life_tick % 10))
			var/list/E
			E = get_visible_implants(0)
			if(!E.len)
				embedded_flag = 0

		//Eyes
		//Check rig first because it's two-check and other checks will override it.
		if(istype(back,/obj/item/weapon/rig))
			var/obj/item/weapon/rig/O = back
			if(O.helmet && O.helmet == head && (O.helmet.body_parts_covered & EYES))
				if((O.offline && O.offline_vision_restriction == 2) || (!O.offline && O.vision_restriction == 2))
					blinded = 1

		// Check everything else.

		//Periodically double-check embedded_flag
		if(embedded_flag && !(life_tick % 10))
			if(!embedded_needs_process())
				embedded_flag = 0
		//Vision
		var/obj/item/organ/vision
		if(species.vision_organ)
			vision = internal_organs_by_name[species.vision_organ]

		if(!species.vision_organ) // Presumably if a species has no vision organs, they see via some other means.
			SetBlinded(0)
			blinded =    0
			eye_blurry = 0
		else if(!vision || vision.is_broken())   // Vision organs cut out or broken? Permablind.
			SetBlinded(1)
			blinded =    1
			eye_blurry = 1
		else //You have the requisite organs
			if(sdisabilities & BLIND) 	// Disabled-blind, doesn't get better on its own
				blinded =    1
			else if(eye_blind)		  	// Blindness, heals slowly over time
				AdjustBlinded(-1)
				blinded =    1
			else if(istype(glasses, /obj/item/clothing/glasses/sunglasses/blindfold))	//resting your eyes with a blindfold heals blurry eyes faster
				eye_blurry = max(eye_blurry-3, 0)
				blinded =    1

			//blurry sight
			if(vision.is_bruised())   // Vision organs impaired? Permablurry.
				eye_blurry = 1
			if(eye_blurry)	           // Blurry eyes heal slowly
				eye_blurry = max(eye_blurry-1, 0)

		//Ears
		if(sdisabilities & DEAF)	//disabled-deaf, doesn't get better on its own
			ear_deaf = max(ear_deaf, 1)
		else if(ear_deaf)			//deafness, heals slowly over time
			ear_deaf = max(ear_deaf-1, 0)
		else if(get_ear_protection() >= 2)	//resting your ears with earmuffs heals ear damage faster
			ear_damage = max(ear_damage-0.15, 0)
			ear_deaf = max(ear_deaf, 1)
		else if(ear_damage < 25)	//ear damage heals slowly under this threshold. otherwise you'll need earmuffs
			ear_damage = max(ear_damage-0.05, 0)

		//Resting
		if(resting)
			dizziness = max(0, dizziness - 15)
			jitteriness = max(0, jitteriness - 15)
			adjustHalLoss(-3)
		else
			dizziness = max(0, dizziness - 3)
			jitteriness = max(0, jitteriness - 3)
			adjustHalLoss(-1)

		if (drowsyness)
			drowsyness--
			eye_blurry = max(2, eye_blurry)
			if (prob(5))
				sleeping += 1
				Paralyse(5)

		confused = max(0, confused - 1)

		// If you're dirty, your gloves will become dirty, too.
		if(gloves && germ_level > gloves.germ_level && prob(10))
			gloves.germ_level += 1

	return 1

/mob/living/carbon/human/proc/set_stat(var/new_stat)
	stat = new_stat
	if(stat)
		update_skin(1)

/mob/living/carbon/human/handle_disabilities()
	..()

	if(stat != CONSCIOUS) //Let's not worry about tourettes if you're not conscious.
		return

	if (disabilities & EPILEPSY)
		if ((prob(1) && paralysis < 1))
			src << "<font color='red'>You have a seizure!</font>"
			for(var/mob/O in viewers(src, null))
				if(O == src)
					continue
				O.show_message(text("<span class='danger'>[src] starts having a seizure!</span>"), 1)
			Paralyse(10)
			make_jittery(1000)
	if (disabilities & COUGHING)
		if ((prob(5) && paralysis <= 1))
			drop_item()
			spawn( 0 )
				emote("cough")
				return
	if (disabilities & TOURETTES)
		if ((prob(10) && paralysis <= 1))
			Stun(10)
			spawn( 0 )
				switch(rand(1, 3))
					if(1)
						emote("twitch")
					if(2 to 3)
						say("[prob(50) ? ";" : ""][pick("SHIT", "PISS", "FUCK", "CUNT", "COCKSUCKER", "MOTHERFUCKER", "TITS")]")
				make_jittery(100)
				return
	if (disabilities & NERVOUS)
		if (prob(10))
			stuttering = max(10, stuttering)

	var/rn = rand(0, 200)
	if(getBrainLoss() >= 5)
		if(0 <= rn && rn <= 3)
			custom_pain("Your head feels numb and painful.", 10)
	if(getBrainLoss() >= 15)
		if(4 <= rn && rn <= 6) if(eye_blurry <= 0)
			src << "<span class='warning'>It becomes hard to see for some reason.</span>"
			eye_blurry = 10
	if(getBrainLoss() >= 35)
		if(7 <= rn && rn <= 9) if(get_active_hand())
			src << "<span class='danger'>Your hand won't respond properly, you drop what you're holding!</span>"
			drop_item()
	if(getBrainLoss() >= 45)
		if(10 <= rn && rn <= 12)
			if(prob(50))
				src << "<span class='danger'>You suddenly black out!</span>"
				Paralyse(10)
			else if(!lying)
				src << "<span class='danger'>Your legs won't respond properly, you fall down!</span>"
				Weaken(10)

/mob/living/carbon/human/handle_random_events()
	if(inStasisNow())
		return

	// Puke if toxloss is too high
	if(!stat)
		if (getToxLoss() >= 30 && isSynthetic())
			if(!confused)
				if(prob(5))
					to_chat(src, "<span class='danger'>You lose directional control!</span>")
					Confuse(10)
		if (getToxLoss() >= 45)
			spawn vomit()


	//0.1% chance of playing a scary sound to someone who's in complete darkness
	if(isturf(loc) && rand(1,1000) == 1)
		var/turf/T = loc
		if(T.get_lumcount() <= LIGHTING_SOFT_THRESHOLD)
			playsound_local(src,pick(scarySounds),50, 1, -1)

/mob/living/carbon/human/handle_stunned()
	if(!can_feel_pain())
		stunned = 0
		return 0
	return ..()

/mob/living/carbon/human/handle_shock()
	..()
	if(status_flags & GODMODE)	return 0	//godmode
	if(!can_feel_pain()) return

	if(health < config.health_threshold_softcrit)// health 0 makes you immediately collapse
		shock_stage = max(shock_stage, 61)

	if(traumatic_shock >= 80)
		shock_stage += 1
	else if(health < config.health_threshold_softcrit)
		shock_stage = max(shock_stage, 61)
	else
		shock_stage = min(shock_stage, 160)
		shock_stage = max(shock_stage-1, 0)
		return

	if(stat)
		return 0

	if(shock_stage == 10)
		custom_pain("[pick("It hurts so much", "You really need some painkillers", "Dear god, the pain")]!", 40)

	if(shock_stage >= 30)
		if(shock_stage == 30) emote("me",1,"is having trouble keeping their eyes open.")
		eye_blurry = max(2, eye_blurry)
		stuttering = max(stuttering, 5)

	if(shock_stage == 40)
		src << "<span class='danger'>[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!</span>"

	if (shock_stage >= 60)
		if(shock_stage == 60) emote("me",1,"'s body becomes limp.")
		if (prob(2))
			src << "<span class='danger'>[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!</span>"
			Weaken(20)

	if(shock_stage >= 80)
		if (prob(5))
			src << "<span class='danger'>[pick("The pain is excruciating", "Please, just end the pain", "Your whole body is going numb")]!</span>"
			Weaken(20)

	if(shock_stage >= 120)
		if (prob(2))
			src << "<span class='danger'>[pick("You black out", "You feel like you could die any moment now", "You're about to lose consciousness")]!</span>"
			Paralyse(5)

	if(shock_stage == 150)
		emote("me",1,"can no longer stand, collapsing!")
		Weaken(20)

	if(shock_stage >= 150)
		Weaken(20)