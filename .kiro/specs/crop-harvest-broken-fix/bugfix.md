# Bugfix Requirements Document

## Introduction

Players cannot harvest crops. Walking up to a fully grown crop shows the harvest
ProximityPrompt, pressing E consumes the prompt (it disappears), and then nothing happens: no
fruit lands in the inventory, the plant stays in the bed, and the Output/F9 console shows no
warning and no error at all.

The absence of any console output is not incidental — it is a second, separate defect. The
harvest path has code branches that abandon a request without saying why, so a live gameplay
break produced zero diagnostic signal. Both the broken harvest and the silence need to be fixed:
after this change, a harvest that does not happen must always explain itself in the server log.

Scope note from investigation: 18 of the 19 crops configured in `SeedData` are single-harvest
(`MultiHarvest = false`); only Mango is multi-harvest. That matches the report of "can't harvest
the crops at all" — the single-harvest interaction path is the broken one, and the Mango aim-and-E
path is the behavior that must be preserved untouched.

Investigation also confirmed this is **independent of the `pet-facing-direction-fix` work**: those
commits touched only `src/client/panels/PetClient.client.lua` and `tools/CalibratePetOrientation.lua`,
nothing on the harvest path, and the harvest scripts currently live in Studio are byte-identical to
`src/` (no divergence, nothing lost on a place reopen). The uncommitted `default.project.json` change
is purely additive (a new `RainVisualConfig` key); no instance key was renamed or moved.

## Bug Analysis

### Current Behavior (Defect)

What happens today when a player tries to harvest.

1.1 WHEN a player triggers the HarvestPrompt on a fully grown single-harvest crop they own, while standing within range THEN the system consumes the prompt and harvests nothing

1.2 WHEN a player triggers the HarvestPrompt on a fully grown single-harvest crop they own THEN the system grants no fruit item to that player's inventory

1.3 WHEN a player triggers the HarvestPrompt on a fully grown single-harvest crop they own THEN the system leaves the plant model and its plot-data entry in place, so the bed slot stays permanently occupied

1.4 WHEN a player triggers the HarvestPrompt repeatedly on the same fully grown single-harvest crop THEN the system consumes every trigger with no state change and no player-visible feedback

1.5 WHEN the server abandons a harvest request because an argument fails validation THEN the system returns without emitting any warning, so the failure is invisible in the Output/F9 console

1.6 WHEN the server abandons a harvest request because it cannot resolve the plant, the seed data, the owner's profile, the plot-data entry, or the fruit record THEN the system returns without emitting any warning

1.7 WHEN the server refuses a harvest request on a gameplay rule (crop below 100% growth, requester is not the owner, requester is out of range, fruit already harvested) THEN the system returns without emitting any warning

### Expected Behavior (Correct)

What should happen instead, for the same conditions.

2.1 WHEN a player triggers the HarvestPrompt on a fully grown single-harvest crop they own, while standing within range THEN the system SHALL grant exactly one fruit item for that crop to the player's inventory

2.2 WHEN a single-harvest crop is successfully harvested THEN the system SHALL mark the fruit record harvested, remove the plant model, and clear its plot-data entry so the bed slot becomes plantable again

2.3 WHEN a player triggers the HarvestPrompt repeatedly on the same crop THEN the system SHALL grant the fruit at most once and SHALL NOT duplicate items or double-clear plot data

2.4 WHEN the server rejects a harvest request because an argument fails validation THEN the system SHALL reject it without harvesting AND SHALL warn to the server Output identifying the rejected request

2.5 WHEN the server cannot resolve a harvest request to a plant, seed data, owner profile, plot-data entry, or fruit record THEN the system SHALL warn to the server Output naming which resolution step failed and the plant key involved

2.6 WHEN the server refuses a harvest request on a gameplay rule (below 100% growth, not the owner, out of range, fruit already harvested) THEN the system SHALL warn to the server Output naming the specific rule that refused it

2.7 WHEN a player triggers the HarvestPrompt on a fully grown single-harvest crop owned by another player THEN the system SHALL grant nothing to the requester, leave the crop intact, and warn to the server Output

### Unchanged Behavior (Regression Prevention)

Behavior that exists today and must be identical after the fix.

3.1 WHEN a player aims at a ripe Mango fruit and presses E (or taps it on mobile) THEN the system SHALL CONTINUE TO grant that fruit and reset the fruit record's size, mutations, rarity, and harvest timestamp

3.2 WHEN a HarvestPrompt belonging to a multi-harvest fruit is triggered THEN the system SHALL CONTINUE TO defer to the aim-and-E path and SHALL NOT fire a second, duplicate harvest request

3.3 WHEN a player triggers any non-harvest ProximityPrompt (seed shop, sell shop, pet shop, gear shop, crop price board, rebirth board, buy prompt, NPC dialogue) THEN the system SHALL CONTINUE TO open the matching panel and re-enable prompts exactly as it does today

3.4 WHEN a malformed or non-string harvest argument arrives from an exploiting client THEN the system SHALL CONTINUE TO reject it server-side without harvesting and without erroring the remote event's thread

3.5 WHEN a crop has not reached 100% growth THEN the system SHALL CONTINUE TO refuse to harvest it

3.6 WHEN the requesting player is outside the allowed harvest distance THEN the system SHALL CONTINUE TO refuse the harvest

3.7 WHEN a harvest is granted THEN the system SHALL CONTINUE TO derive fruit rarity, mutations, weight/size, and plant size from the server-side crop configuration values (the `SeedData` instance tree remaining the source of truth), producing the same item strings and sell values as before

3.8 WHEN a fruit's harvestable state changes THEN the system SHALL CONTINUE TO update the client-side crop visuals and prompt enable/disable state as it does today

3.9 WHEN a player harvests THEN the system SHALL CONTINUE TO keep all money, inventory, and ownership decisions on the server, with the client only sending the interaction request
