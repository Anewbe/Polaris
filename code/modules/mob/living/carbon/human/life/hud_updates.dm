/*
// HUD update code for humans now lives here, as best it can.
*/

/mob/living/carbon/human/handle_regular_hud_updates()
	if(hud_updateflag) // update our mob's hud overlays, AKA what others see flaoting above our head
		handle_hud_list()

	// now handle what we see on our screen

	if(!client)
		return 0

	..()

	client.screen.Remove(global_hud.blurry, global_hud.druggy, global_hud.vimpaired, global_hud.darkMask, global_hud.nvg, global_hud.thermal, global_hud.meson, global_hud.science, global_hud.material, global_hud.whitense)

	if(istype(client.eye,/obj/machinery/camera))
		var/obj/machinery/camera/cam = client.eye
		client.screen |= cam.client_huds

	if(stat != DEAD)
		if(stat == UNCONSCIOUS && health <= 0)
			//Critical damage passage overlay
			var/severity = 0
			switch(health)
				if(-20 to -10)			severity = 1
				if(-30 to -20)			severity = 2
				if(-40 to -30)			severity = 3
				if(-50 to -40)			severity = 4
				if(-60 to -50)			severity = 5
				if(-70 to -60)			severity = 6
				if(-80 to -70)			severity = 7
				if(-90 to -80)			severity = 8
				if(-95 to -90)			severity = 9
				if(-INFINITY to -95)	severity = 10
			overlay_fullscreen("crit", /obj/screen/fullscreen/crit, severity)
		else
			clear_fullscreen("crit")
			//Oxygen damage overlay
			if(oxyloss)
				var/severity = 0
				switch(oxyloss)
					if(10 to 20)		severity = 1
					if(20 to 25)		severity = 2
					if(25 to 30)		severity = 3
					if(30 to 35)		severity = 4
					if(35 to 40)		severity = 5
					if(40 to 45)		severity = 6
					if(45 to INFINITY)	severity = 7
				overlay_fullscreen("oxy", /obj/screen/fullscreen/oxy, severity)
			else
				clear_fullscreen("oxy")

		//Fire and Brute damage overlay (BSSR)
		var/hurtdamage = src.getShockBruteLoss() + src.getShockFireLoss() + damageoverlaytemp	//Doesn't call the overlay if you can't actually feel it
		damageoverlaytemp = 0 // We do this so we can detect if someone hits us or not.
		if(hurtdamage)
			var/severity = 0
			switch(hurtdamage)
				if(10 to 25)		severity = 1
				if(25 to 40)		severity = 2
				if(40 to 55)		severity = 3
				if(55 to 70)		severity = 4
				if(70 to 85)		severity = 5
				if(85 to INFINITY)	severity = 6
			overlay_fullscreen("brute", /obj/screen/fullscreen/brute, severity)
		else
			clear_fullscreen("brute")

	if( stat == DEAD )
		sight |= SEE_TURFS|SEE_MOBS|SEE_OBJS|SEE_SELF
		see_in_dark = 8
		if(!druggy)		see_invisible = SEE_INVISIBLE_LEVEL_TWO
		if(healths)		healths.icon_state = "health7"	//DEAD healthmeter
		if(client)
			if(client.view != world.view) // If mob dies while zoomed in with device, unzoom them.
				for(var/obj/item/item in contents)
					if(item.zoom)
						item.zoom()
						break

	else
		sight &= ~(SEE_TURFS|SEE_MOBS|SEE_OBJS)
		see_invisible = see_in_dark>2 ? SEE_INVISIBLE_LEVEL_ONE : SEE_INVISIBLE_LIVING

		if(XRAY in mutations)
			sight |= SEE_TURFS|SEE_MOBS|SEE_OBJS
			see_in_dark = 8
			if(!druggy)		see_invisible = SEE_INVISIBLE_LEVEL_TWO

		if(seer==1)
			var/obj/effect/rune/R = locate() in loc
			if(R && R.word1 == cultwords["see"] && R.word2 == cultwords["hell"] && R.word3 == cultwords["join"])
				see_invisible = SEE_INVISIBLE_CULT
			else
				see_invisible = SEE_INVISIBLE_LIVING
				seer = 0

		if(!seedarkness)
			sight = species.get_vision_flags(src)
			see_in_dark = 8
			see_invisible = SEE_INVISIBLE_NOLIGHTING

		else
			sight = species.get_vision_flags(src)
			see_in_dark = species.darksight
			see_invisible = see_in_dark>2 ? SEE_INVISIBLE_LEVEL_ONE : SEE_INVISIBLE_LIVING

		var/tmp/glasses_processed = 0
		var/obj/item/weapon/rig/rig = back
		if(istype(rig) && rig.visor)
			if(!rig.helmet || (head && rig.helmet == head))
				if(rig.visor && rig.visor.vision && rig.visor.active && rig.visor.vision.glasses)
					glasses_processed = 1
					process_glasses(rig.visor.vision.glasses)

		if(glasses && !glasses_processed)
			glasses_processed = 1
			process_glasses(glasses)
		if(XRAY in mutations)
			sight |= SEE_TURFS|SEE_MOBS|SEE_OBJS
			see_in_dark = 8
			if(!druggy)		see_invisible = SEE_INVISIBLE_LEVEL_TWO

		if(!glasses_processed && (species.get_vision_flags(src) > 0))
			sight |= species.get_vision_flags(src)
		if(!seer && !glasses_processed && seedarkness)
			see_invisible = SEE_INVISIBLE_LIVING

		if(healths)
			if (chem_effects[CE_PAINKILLER] > 100)
				healths.icon_state = "health_numb"
			else
				// Generate a by-limb health display.
				var/mutable_appearance/healths_ma = new(healths)
				healths_ma.icon_state = "blank"
				healths_ma.overlays = null
				healths_ma.plane = PLANE_PLAYER_HUD

				var/no_damage = 1
				var/trauma_val = 0 // Used in calculating softcrit/hardcrit indicators.
				if(!(species.flags & NO_PAIN))
					trauma_val = max(traumatic_shock,halloss)/species.total_health
				var/limb_trauma_val = trauma_val*0.3
				// Collect and apply the images all at once to avoid appearance churn.
				var/list/health_images = list()
				for(var/obj/item/organ/external/E in organs)
					if(no_damage && (E.brute_dam || E.burn_dam))
						no_damage = 0
					health_images += E.get_damage_hud_image(limb_trauma_val)

				// Apply a fire overlay if we're burning.
				if(on_fire)
					health_images += image('icons/mob/OnFire.dmi',"[get_fire_icon_state()]")

				// Show a general pain/crit indicator if needed.
				if(trauma_val)
					if(!(species.flags & NO_PAIN))
						if(trauma_val > 0.7)
							health_images += image('icons/mob/screen1_health.dmi',"softcrit")
						if(trauma_val >= 1)
							health_images += image('icons/mob/screen1_health.dmi',"hardcrit")
				else if(no_damage)
					health_images += image('icons/mob/screen1_health.dmi',"fullhealth")

				healths_ma.overlays += health_images
				healths.appearance = healths_ma

		if(nutrition_icon)
			switch(nutrition)
				if(450 to INFINITY)				nutrition_icon.icon_state = "nutrition0"
				if(350 to 450)					nutrition_icon.icon_state = "nutrition1"
				if(250 to 350)					nutrition_icon.icon_state = "nutrition2"
				if(150 to 250)					nutrition_icon.icon_state = "nutrition3"
				else							nutrition_icon.icon_state = "nutrition4"

		if(pressure)
			pressure.icon_state = "pressure[pressure_alert]"

//			if(rest)	//Not used with new UI
//				if(resting || lying || sleeping)		rest.icon_state = "rest1"
//				else									rest.icon_state = "rest0"
		if(toxin)
			if(hal_screwyhud == 4 || (phoron_alert && !does_not_breathe))	toxin.icon_state = "tox1"
			else									toxin.icon_state = "tox0"
		if(oxygen)
			if(hal_screwyhud == 3 || (oxygen_alert && !does_not_breathe))	oxygen.icon_state = "oxy1"
			else									oxygen.icon_state = "oxy0"
		if(fire)
			if(fire_alert)							fire.icon_state = "fire[fire_alert]" //fire_alert is either 0 if no alert, 1 for cold and 2 for heat.
			else									fire.icon_state = "fire0"

		if(bodytemp)
			if (!species)
				switch(bodytemperature) //310.055 optimal body temp
					if(370 to INFINITY)		bodytemp.icon_state = "temp4"
					if(350 to 370)			bodytemp.icon_state = "temp3"
					if(335 to 350)			bodytemp.icon_state = "temp2"
					if(320 to 335)			bodytemp.icon_state = "temp1"
					if(300 to 320)			bodytemp.icon_state = "temp0"
					if(295 to 300)			bodytemp.icon_state = "temp-1"
					if(280 to 295)			bodytemp.icon_state = "temp-2"
					if(260 to 280)			bodytemp.icon_state = "temp-3"
					else					bodytemp.icon_state = "temp-4"
			else
				//TODO: precalculate all of this stuff when the species datum is created
				var/base_temperature = species.body_temperature
				if(base_temperature == null) //some species don't have a set metabolic temperature
					base_temperature = (species.heat_level_1 + species.cold_level_1)/2

				var/temp_step
				if (bodytemperature >= base_temperature)
					temp_step = (species.heat_level_1 - base_temperature)/4

					if (bodytemperature >= species.heat_level_1)
						bodytemp.icon_state = "temp4"
					else if (bodytemperature >= base_temperature + temp_step*3)
						bodytemp.icon_state = "temp3"
					else if (bodytemperature >= base_temperature + temp_step*2)
						bodytemp.icon_state = "temp2"
					else if (bodytemperature >= base_temperature + temp_step*1)
						bodytemp.icon_state = "temp1"
					else
						bodytemp.icon_state = "temp0"

				else if (bodytemperature < base_temperature)
					temp_step = (base_temperature - species.cold_level_1)/4

					if (bodytemperature <= species.cold_level_1)
						bodytemp.icon_state = "temp-4"
					else if (bodytemperature <= base_temperature - temp_step*3)
						bodytemp.icon_state = "temp-3"
					else if (bodytemperature <= base_temperature - temp_step*2)
						bodytemp.icon_state = "temp-2"
					else if (bodytemperature <= base_temperature - temp_step*1)
						bodytemp.icon_state = "temp-1"
					else
						bodytemp.icon_state = "temp0"

		if(blinded)		overlay_fullscreen("blind", /obj/screen/fullscreen/blind)
		else			clear_fullscreens()

		if(disabilities & NEARSIGHTED)	//this looks meh but saves a lot of memory by not requiring to add var/prescription
			if(glasses)					//to every /obj/item
				var/obj/item/clothing/glasses/G = glasses
				if(!G.prescription)
					set_fullscreen(disabilities & NEARSIGHTED, "impaired", /obj/screen/fullscreen/impaired, 1)
			else
				set_fullscreen(disabilities & NEARSIGHTED, "impaired", /obj/screen/fullscreen/impaired, 1)

		set_fullscreen(eye_blurry, "blurry", /obj/screen/fullscreen/blurry)
		set_fullscreen(druggy, "high", /obj/screen/fullscreen/high)

		if(config.welder_vision)
			var/found_welder
			if(species.short_sighted)
				found_welder = 1
			else
				if(istype(glasses, /obj/item/clothing/glasses/welding))
					var/obj/item/clothing/glasses/welding/O = glasses
					if(!O.up)
						found_welder = 1
				if(!found_welder && istype(head, /obj/item/clothing/head/welding))
					var/obj/item/clothing/head/welding/O = head
					if(!O.up)
						found_welder = 1
				if(!found_welder && istype(back, /obj/item/weapon/rig))
					var/obj/item/weapon/rig/O = back
					if(O.helmet && O.helmet == head && (O.helmet.body_parts_covered & EYES))
						if((O.offline && O.offline_vision_restriction == 1) || (!O.offline && O.vision_restriction == 1))
							found_welder = 1
			if(found_welder)
				client.screen |= global_hud.darkMask

		if(machine)
			var/viewflags = machine.check_eye(src)
			if(viewflags < 0)
				reset_view(null, 0)
			else if(viewflags)
				sight |= viewflags
		else if(eyeobj)
			if(eyeobj.owner != src)

				reset_view(null)
		else
			var/isRemoteObserve = 0
			if((mRemote in mutations) && remoteview_target)
				if(remoteview_target.stat==CONSCIOUS)
					isRemoteObserve = 1
			if(!isRemoteObserve && client && !client.adminobs)
				remoteview_target = null
				reset_view(null, 0)
	return 1

/*
	Called by life(), instead of having the individual hud items update icons each tick and check for status changes
	we only set those statuses and icons upon changes.  Then those HUD items will simply add those pre-made images.
	This proc below is only called when those HUD elements need to change as determined by the mobs hud_updateflag.
*/
/mob/living/carbon/human/proc/handle_hud_list()
	if (BITTEST(hud_updateflag, HEALTH_HUD))
		var/image/holder = hud_list[HEALTH_HUD]
		if(stat == DEAD)
			holder.icon_state = "-100" 	// X_X
		else
			holder.icon_state = RoundHealth((health-config.health_threshold_crit)/(getMaxHealth()-config.health_threshold_crit)*100)
		hud_list[HEALTH_HUD] = holder

	if (BITTEST(hud_updateflag, LIFE_HUD))
		var/image/holder = hud_list[LIFE_HUD]
		if(isSynthetic())
			holder.icon_state = "hudrobo"
		else if(stat == DEAD)
			holder.icon_state = "huddead"
		else
			holder.icon_state = "hudhealthy"
		hud_list[LIFE_HUD] = holder

	if (BITTEST(hud_updateflag, STATUS_HUD))
		var/foundVirus = 0
		for (var/ID in virus2)
			if (ID in virusDB)
				foundVirus = 1
				break

		var/image/holder = hud_list[STATUS_HUD]
		var/image/holder2 = hud_list[STATUS_HUD_OOC]
		if (isSynthetic())
			holder.icon_state = "hudrobo"
		else if(stat == DEAD)
			holder.icon_state = "huddead"
			holder2.icon_state = "huddead"
		else if(foundVirus)
			holder.icon_state = "hudill"
		else if(has_brain_worms())
			var/mob/living/simple_animal/borer/B = has_brain_worms()
			if(B.controlling)
				holder.icon_state = "hudbrainworm"
			else
				holder.icon_state = "hudhealthy"
			holder2.icon_state = "hudbrainworm"
		else
			holder.icon_state = "hudhealthy"
			if(virus2.len)
				holder2.icon_state = "hudill"
			else
				holder2.icon_state = "hudhealthy"

		hud_list[STATUS_HUD] = holder
		hud_list[STATUS_HUD_OOC] = holder2

	if (BITTEST(hud_updateflag, ID_HUD))
		var/image/holder = hud_list[ID_HUD]
		if(wear_id)
			var/obj/item/weapon/card/id/I = wear_id.GetID()
			if(I)
				holder.icon_state = "hud[ckey(I.GetJobName())]"
			else
				holder.icon_state = "hudunknown"
		else
			holder.icon_state = "hudunknown"


		hud_list[ID_HUD] = holder

	if (BITTEST(hud_updateflag, WANTED_HUD))
		var/image/holder = hud_list[WANTED_HUD]
		holder.icon_state = "hudblank"
		var/perpname = name
		if(wear_id)
			var/obj/item/weapon/card/id/I = wear_id.GetID()
			if(I)
				perpname = I.registered_name

		for(var/datum/data/record/E in data_core.general)
			if(E.fields["name"] == perpname)
				for (var/datum/data/record/R in data_core.security)
					if((R.fields["id"] == E.fields["id"]) && (R.fields["criminal"] == "*Arrest*"))
						holder.icon_state = "hudwanted"
						break
					else if((R.fields["id"] == E.fields["id"]) && (R.fields["criminal"] == "Incarcerated"))
						holder.icon_state = "hudprisoner"
						break
					else if((R.fields["id"] == E.fields["id"]) && (R.fields["criminal"] == "Parolled"))
						holder.icon_state = "hudparolled"
						break
					else if((R.fields["id"] == E.fields["id"]) && (R.fields["criminal"] == "Released"))
						holder.icon_state = "hudreleased"
						break
		hud_list[WANTED_HUD] = holder

	if (  BITTEST(hud_updateflag, IMPLOYAL_HUD) \
	   || BITTEST(hud_updateflag,  IMPCHEM_HUD) \
	   || BITTEST(hud_updateflag, IMPTRACK_HUD))

		var/image/holder1 = hud_list[IMPTRACK_HUD]
		var/image/holder2 = hud_list[IMPLOYAL_HUD]
		var/image/holder3 = hud_list[IMPCHEM_HUD]

		holder1.icon_state = "hudblank"
		holder2.icon_state = "hudblank"
		holder3.icon_state = "hudblank"

		for(var/obj/item/weapon/implant/I in src)
			if(I.implanted)
				if(!I.malfunction)
					if(istype(I,/obj/item/weapon/implant/tracking))
						holder1.icon_state = "hud_imp_tracking"
					if(istype(I,/obj/item/weapon/implant/loyalty))
						holder2.icon_state = "hud_imp_loyal"
					if(istype(I,/obj/item/weapon/implant/chem))
						holder3.icon_state = "hud_imp_chem"

		hud_list[IMPTRACK_HUD] = holder1
		hud_list[IMPLOYAL_HUD] = holder2
		hud_list[IMPCHEM_HUD]  = holder3

	if (BITTEST(hud_updateflag, SPECIALROLE_HUD))
		var/image/holder = hud_list[SPECIALROLE_HUD]
		holder.icon_state = "hudblank"
		if(mind && mind.special_role)
			if(hud_icon_reference[mind.special_role])
				holder.icon_state = hud_icon_reference[mind.special_role]
			else
				holder.icon_state = "hudsyndicate"
			hud_list[SPECIALROLE_HUD] = holder
	hud_updateflag = 0
	update_icons_huds()

/*
// Changeling Chem HUD
*/

/mob/living/carbon/human/proc/handle_changeling()
	if(mind && mind.changeling)
		mind.changeling.regenerate()
		if(hud_used)
			ling_chem_display.invisibility = 0
//			ling_chem_display.maptext = "<div align='center' valign='middle' style='position:relative; top:0px; left:6px'><font color='#dd66dd'>[round(mind.changeling.chem_charges)]</font></div>"
			switch(mind.changeling.chem_storage)
				if(1 to 50)
					switch(mind.changeling.chem_charges)
						if(0 to 9)
							ling_chem_display.icon_state = "ling_chems0"
						if(10 to 19)
							ling_chem_display.icon_state = "ling_chems10"
						if(20 to 29)
							ling_chem_display.icon_state = "ling_chems20"
						if(30 to 39)
							ling_chem_display.icon_state = "ling_chems30"
						if(40 to 49)
							ling_chem_display.icon_state = "ling_chems40"
						if(50)
							ling_chem_display.icon_state = "ling_chems50"
				if(51 to 80) //This is a crappy way of checking for engorged sacs...
					switch(mind.changeling.chem_charges)
						if(0 to 9)
							ling_chem_display.icon_state = "ling_chems0e"
						if(10 to 19)
							ling_chem_display.icon_state = "ling_chems10e"
						if(20 to 29)
							ling_chem_display.icon_state = "ling_chems20e"
						if(30 to 39)
							ling_chem_display.icon_state = "ling_chems30e"
						if(40 to 49)
							ling_chem_display.icon_state = "ling_chems40e"
						if(50 to 59)
							ling_chem_display.icon_state = "ling_chems50e"
						if(60 to 69)
							ling_chem_display.icon_state = "ling_chems60e"
						if(70 to 79)
							ling_chem_display.icon_state = "ling_chems70e"
						if(80)
							ling_chem_display.icon_state = "ling_chems80e"
	else
		if(mind && hud_used)
			ling_chem_display.invisibility = 101
