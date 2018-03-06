/mob/living/carbon/human/proc/handle_pulse()
	if(life_tick % 5) return pulse	//update pulse every 5 life ticks (~1 tick/sec, depending on server load)

	if(!internal_organs_by_name[O_HEART])
		return PULSE_NONE //No blood, no pulse.

	if(stat == DEAD)
		return PULSE_NONE	//that's it, you're dead, nothing can influence your pulse

	var/temp = PULSE_NORM

	if(round(vessel.get_reagent_amount("blood")) <= BLOOD_VOLUME_BAD)	//how much blood do we have
		temp = PULSE_THREADY	//not enough :(

	if(status_flags & FAKEDEATH)
		temp = PULSE_NONE		//pretend that we're dead. unlike actual death, can be inflienced by meds

	//handles different chems' influence on pulse
	for(var/datum/reagent/R in reagents.reagent_list)
		if(R.id in bradycardics)
			if(temp <= PULSE_THREADY && temp >= PULSE_NORM)
				temp--
		if(R.id in tachycardics)
			if(temp <= PULSE_FAST && temp >= PULSE_NONE)
				temp++
		if(R.id in heartstopper) //To avoid using fakedeath
			temp = PULSE_NONE
		if(R.id in cheartstopper) //Conditional heart-stoppage
			if(R.volume >= R.overdose)
				temp = PULSE_NONE

	return temp

/mob/living/carbon/human/proc/handle_heartbeat()
	if(pulse == PULSE_NONE)
		return

	var/obj/item/organ/internal/heart/H = internal_organs_by_name[O_HEART]

	if(!H || (H.robotic >= ORGAN_ROBOT))
		return

	if(pulse >= PULSE_2FAST || shock_stage >= 10 || istype(get_turf(src), /turf/space))
		//PULSE_THREADY - maximum value for pulse, currently it 5.
		//High pulse value corresponds to a fast rate of heartbeat.
		//Divided by 2, otherwise it is too slow.
		var/rate = (PULSE_THREADY - pulse)/2

		if(heartbeat >= rate)
			heartbeat = 0
			src << sound('sound/effects/singlebeat.ogg',0,0,0,50)
		else
			heartbeat++


// Stomach contents. NOT reagents
/mob/living/carbon/human/handle_stomach()
	spawn(0)
		for(var/mob/living/M in stomach_contents)
			if(M.loc != src)
				stomach_contents.Remove(M)
				continue
			if(istype(M, /mob/living/carbon) && stat != 2)
				if(M.stat == 2)
					M.death(1)
					stomach_contents.Remove(M)
					qdel(M)
					continue
				if(air_master.current_cycle%3==1)
					if(!(M.status_flags & GODMODE))
						M.adjustBruteLoss(5)
					nutrition += 10


// Glasses, goggles, etc.
/mob/living/carbon/human/proc/process_glasses(var/obj/item/clothing/glasses/G)
	if(G && G.active)
		see_in_dark += G.darkness_view
		if(G.overlay)
			client.screen |= G.overlay
		if(G.vision_flags)
			sight |= G.vision_flags
		if(istype(G,/obj/item/clothing/glasses/night) && !seer)
			see_invisible = SEE_INVISIBLE_MINIMUM

		if(G.see_invisible >= 0)
			see_invisible = G.see_invisible
		else if(!druggy && !seer)
			see_invisible = SEE_INVISIBLE_LIVING