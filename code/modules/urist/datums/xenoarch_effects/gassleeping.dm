/datum/artifact_effect/gassleeping
	name = "N2O creation"

/datum/artifact_effect/gassleeping/New()
	..()
	effect = pick(EFFECT_TOUCH, EFFECT_AURA)
	effect_type = pick(EFFECT_BLUESPACE, EFFECT_SYNTH)


/datum/artifact_effect/gassleeping/DoEffectTouch(mob/living/user)
	if (holder)
		var/turf/holder_loc = holder.loc
		if (istype(holder_loc))
			holder_loc.assume_gas("nitrous_oxide", rand(2, 15))


/datum/artifact_effect/gassleeping/DoEffectAura()
	if (holder)
		var/turf/holder_loc = holder.loc
		if (istype(holder_loc))
			holder_loc.assume_gas("nitrous_oxide", pick(0, 0, 0.1, rand()))
