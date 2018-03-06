
/mob/living/carbon/human/handle_mutations_and_radiation()
	if(inStasisNow())
		return

	if(getFireLoss())
		if((COLD_RESISTANCE in mutations) || (prob(1)))
			heal_organ_damage(0,1)

	// DNA2 - Gene processing.
	// The HULK stuff that was here is now in the hulk gene.
	if(!isSynthetic())
		for(var/datum/dna/gene/gene in dna_genes)
			if(!gene.block)
				continue
			if(gene.is_active(src))
				gene.OnMobLife(src)

	radiation = Clamp(radiation,0,250)

	if(!radiation)
		if(species.appearance_flags & RADIATION_GLOWS)
			set_light(0)
	else
		if(species.appearance_flags & RADIATION_GLOWS)
			set_light(max(1,min(5,radiation/15)), max(1,min(10,radiation/25)), species.get_flesh_colour(src))
		// END DOGSHIT SNOWFLAKE

		var/obj/item/organ/internal/diona/nutrients/rad_organ = locate() in internal_organs
		if(rad_organ && !rad_organ.is_broken())
			var/rads = radiation/25
			radiation -= rads
			nutrition += rads
			adjustBruteLoss(-(rads))
			adjustFireLoss(-(rads))
			adjustOxyLoss(-(rads))
			adjustToxLoss(-(rads))
			updatehealth()
			return

		var/obj/item/organ/internal/brain/slime/core = locate() in internal_organs
		if(core)
			return

		var/damage = 0
		radiation -= 1 * RADIATION_SPEED_COEFFICIENT
		if(prob(25))
			damage = 1

		if (radiation > 50)
			damage = 1
			radiation -= 1 * RADIATION_SPEED_COEFFICIENT
			if(!isSynthetic())
				if(prob(5) && prob(100 * RADIATION_SPEED_COEFFICIENT))
					radiation -= 5 * RADIATION_SPEED_COEFFICIENT
					src << "<span class='warning'>You feel weak.</span>"
					Weaken(3)
					if(!lying)
						emote("collapse")
				if(prob(5) && prob(100 * RADIATION_SPEED_COEFFICIENT) && species.get_bodytype() == "Human") //apes go bald
					if((h_style != "Bald" || f_style != "Shaved" ))
						src << "<span class='warning'>Your hair falls out.</span>"
						h_style = "Bald"
						f_style = "Shaved"
						update_hair()

		if (radiation > 75)
			damage = 3
			radiation -= 1 * RADIATION_SPEED_COEFFICIENT
			if(!isSynthetic())
				if(prob(5))
					take_overall_damage(0, 5 * RADIATION_SPEED_COEFFICIENT, used_weapon = "Radiation Burns")
				if(prob(1))
					src << "<span class='warning'>You feel strange!</span>"
					adjustCloneLoss(5 * RADIATION_SPEED_COEFFICIENT)
					emote("gasp")

		if (radiation > 150)
			damage = 6
			radiation -= 4 * RADIATION_SPEED_COEFFICIENT

		if(damage)
			damage *= species.radiation_mod
			adjustToxLoss(damage * RADIATION_SPEED_COEFFICIENT)
			updatehealth()
			if(!isSynthetic() && organs.len)
				var/obj/item/organ/external/O = pick(organs)
				if(istype(O)) O.add_autopsy_data("Radiation Poisoning", damage)