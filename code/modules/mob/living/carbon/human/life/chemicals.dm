/mob/living/carbon/human/handle_chemicals_in_body()
	if(inStasisNow())
		return

	if(reagents)
		chem_effects.Cut()

		if(!isSynthetic())

			if(touching)
				touching.metabolize()
			if(ingested)
				ingested.metabolize()
			if(bloodstr)
				bloodstr.metabolize()

			var/total_phoronloss = 0
			for(var/obj/item/I in src)
				if(I.contaminated)
					if(src.species && src.species.get_bodytype() != "Vox")
						// This is hacky, I'm so sorry.
						if(I != l_hand && I != r_hand)	//If the item isn't in your hands, you're probably wearing it. Full damage for you.
							total_phoronloss += vsc.plc.CONTAMINATION_LOSS
						else if(I == l_hand)	//If the item is in your hands, but you're wearing protection, you might be alright.
							var/l_hand_blocked = 0
							l_hand_blocked = 1-(100-getarmor(BP_L_HAND, "bio"))/100	//This should get a number between 0 and 1
							total_phoronloss += vsc.plc.CONTAMINATION_LOSS * l_hand_blocked
						else if(I == r_hand)	//If the item is in your hands, but you're wearing protection, you might be alright.
							var/r_hand_blocked = 0
							r_hand_blocked = 1-(100-getarmor(BP_R_HAND, "bio"))/100	//This should get a number between 0 and 1
							total_phoronloss += vsc.plc.CONTAMINATION_LOSS * r_hand_blocked
			if(total_phoronloss)
				if(!(status_flags & GODMODE))
					adjustToxLoss(total_phoronloss)

	if(status_flags & GODMODE)
		return 0	//godmode

	var/obj/item/organ/internal/diona/node/light_organ = locate() in internal_organs

	if(!isSynthetic())
		if(light_organ && !light_organ.is_broken())
			var/light_amount = 0 //how much light there is in the place, affects receiving nutrition and healing
			if(isturf(loc)) //else, there's considered to be no light
				var/turf/T = loc
				light_amount = T.get_lumcount() * 10
			nutrition += light_amount
			traumatic_shock -= light_amount

			if(species.flags & IS_PLANT)
				if(nutrition > 450)
					nutrition = 450

				if(light_amount >= 3) //if there's enough light, heal
					adjustBruteLoss(-(round(light_amount/2)))
					adjustFireLoss(-(round(light_amount/2)))
					adjustToxLoss(-(light_amount))
					adjustOxyLoss(-(light_amount))
					//TODO: heal wounds, heal broken limbs.

	if(species.light_dam)
		var/light_amount = 0
		if(isturf(loc))
			var/turf/T = loc
			light_amount = T.get_lumcount() * 10
		if(light_amount > species.light_dam) //if there's enough light, start dying
			take_overall_damage(1,1)
		else //heal in the dark
			heal_overall_damage(1,1)

	// nutrition decrease
	if (nutrition > 0 && stat != DEAD)
		var/nutrition_reduction = species.hunger_factor

		for(var/datum/modifier/mod in modifiers)
			if(!isnull(mod.metabolism_percent))
				nutrition_reduction *= mod.metabolism_percent

		nutrition = max (0, nutrition - nutrition_reduction)

	if (nutrition > 450)
		if(overeatduration < 600) //capped so people don't take forever to unfat
			overeatduration++
	else
		if(overeatduration > 1)
			overeatduration -= 2 //doubled the unfat rate

	if(!isSynthetic() && (species.flags & IS_PLANT) && (!light_organ || light_organ.is_broken()))
		if(nutrition < 200)
			take_overall_damage(2,0)

			//traumatic_shock is updated every tick, incrementing that is pointless - shock_stage is the counter.
			//Not that it matters much for diona, who have NO_PAIN.
			shock_stage++

	// TODO: stomach and bloodstream organ.
	if(!isSynthetic())
		handle_trace_chems()

	updatehealth()

	return //TODO: DEFERRED