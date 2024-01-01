version "4.10"

class UTP_ItemHandler : EventHandler
{
	static bool IsVoodooDoll(PlayerPawn mo) 
	{
		return !mo.player || !mo.player.mo || mo.player.mo != mo;
	}

	override void WorldThingSpawned(worldEvent e)
	{
		let itm = Inventory(e.thing);
		if (itm)
		{
			itm.bSPECIAL = false;
		}
	}

	override void PlayerSpawned(playerEvent e)
	{
		let pmo = players[e.PlayerNumber].mo;
		if (pmo && !IsVoodooDoll(pmo))
		{
			pmo.GiveInventory("UTP_Controller", 1);
		}
	}
}

class UTP_Controller : Inventory
{
	const PICKUPANGLE = 25.0;
	const PICKUPDISTFAC = 2;
	const PICKINGTIME = 5;
	int pickingTimer;
	UTP_PickupHighligtThinker highlighter;

	Default
	{
		+Inventory.UNDROPPABLE
		+Inventory.UNTOSSABLE
		+Inventory.PERSISTENTPOWER
	}

	override void DoEffect()
	{
		if (!owner || !owner.player)
		{
			Destroy();
			return;
		}

		if (pickingTimer > 0)
		{
			pickingTimer--;
			return;
		}
		HighlightPickup(GetAimedPickup(owner));

		if ((owner.player.cmd.buttons & BT_USE) && highlighter && highlighter.DoPickup(owner))
		{
			pickingTimer = PICKINGTIME;
		}
	}

	void HighlightPickup(Inventory pickup)
	{
		if (!pickup)
		{
			if (highlighter)
			{
				highlighter.Destroy();
			}
			return;
		}
		if (!highlighter)
		{
			highlighter = UTP_PickupHighligtThinker.Make(pickup, owner.PlayerNumber());
		}
		else
		{
			highlighter.Update(pickup, owner.PlayerNumber());
		}
	}

	Inventory GetAimedPickup(Actor source)
	{
		double dist = source.radius * 2 * PICKUPDISTFAC;
		BlockThingsIterator it = BlockThingsIterator.Create(source, dist);
		Inventory closest;
		double closestAngle = double.infinity;
		while (it.Next())
		{
			let itm = Inventory(it.thing);
			if (!itm)
				continue;
			
			if (itm.bNOSECTOR || itm.owner)
				continue;
			
			if (!source.CheckSight(itm, SF_IGNOREWATERBOUNDARY))
				continue;
			
			double distTo = owner.Distance3D(itm);
			if (distTo > dist)
				continue;
			
			double z = source.height * 0.5 - source.floorclip + source.player.mo.AttackZOffset*source.player.crouchFactor;
			Vector3 view = Level.SphericalCoords(source.pos + (0,0,z), itm.pos + (0,0,itm.height * 0.5), (source.angle, source.pitch));
			if (view.z > dist || (view.z > owner.radius * 2 && (abs(view.x) > PICKUPANGLE || abs(view.y) > PICKUPANGLE)))
			{
					continue;
			}
			double ang = min(view.x, view.y);
			if (ang < closestAngle)
			{
				closest = itm;
			}
		}
		return closest;
	}
}

class UTP_PickupHighligtThinker : Thinker
{
	Inventory pickup;
	Inventory highlight;
	Actor toucher;
	bool isPicking;
	int age;

	static UTP_PickupHighligtThinker Make(Inventory pickup, int playerNumber)
	{
		let h = New('UTP_PickupHighligtThinker');
		if (h)
		{
			h.Update(pickup, playerNumber);
		}
		return h;
	}

	void Update(Inventory pickup, int playerNumber)
	{
		if (pickup && pickup == self.pickup)
			return;
		
		if (highlight)
			highlight.Destroy();
		
		highlight = Inventory(Actor.Spawn(pickup.GetClass(), pickup.pos));
		highlight.A_ChangeLinkFlags(true);
		highlight.A_ChangeCountFlags(false, false, false);
		highlight.bNOINTERACTION = true;
		highlight.bNOTIMEFREEZE = true;
		highlight.bBRIGHT = true;
		switch(pickup.GetRenderstyle())
		{
		case STYLE_OptFuzzy:
		case STYLE_SoulTrans:
		case STYLE_Normal:
		case STYLE_Shadow:
			highlight.A_SetRenderstyle(0, STYLE_Translucent);
			break;
		case STYLE_Stencil:
			highlight.A_SetRenderstyle(0, STYLE_TranslucentStencil);
			break;
		}
		highlight.A_SetTranslation("UTP_Highlight");
		highlight.angle = pickup.angle;
		highlight.pitch = pickup.pitch;
		highlight.worldOffset = pickup.worldOffset;
		highlight.floatBobPhase = pickup.floatBobPhase;
		highlight.SetState(pickup.curstate);
		highlight.tics = pickup.curstate.tics;
		if (playerNumber != consoleplayer)
		{
			highlight.alpha = -1;
		}
		self.pickup = pickup;
	}

	bool DoPickup(Actor toucher)
	{
		if (!highlight || !pickup)
			return false;
		
		if (!pickup.CallTryPickup(toucher))
			return false;

		pickup.PlayPickupSound(toucher);
		pickup.PrintPickupMessage(true, pickup.PickupMessage());
		highlight.A_SetRenderstyle(highlight.default.alpha, highlight.default.GetRenderstyle());
		highlight.translation = highlight.default.translation;
		self.toucher = toucher;
		isPicking = true;
		return true;
	}

	override void Tick()
	{
		super.Tick();
		if (!highlight || (!isPicking && !pickup))
		{
			return;
		}

		if (isPicking && toucher)
		{
			Vector3 vec = Level.Vec3Diff(highlight.pos, toucher.pos + (0,0,toucher.height*0.5));
			double dist = vec.Length();
			if (dist <= toucher.radius)
			{
				Destroy();
				return;
			}
			highlight.vel = vec.Unit() * 12;
			return;
		}

		if (pickup.owner || pickup.bNOSECTOR)
		{
			highlight.Destroy();
			return;
		}

		highlight.SetOrigin(pickup.pos, true);
		if (highlight.alpha != -1)
		{
			highlight.alpha = 0.5 + (0.25 + 0.25 * sin(360.0 * age / double(TICRATE)));
		}
		age++;
	}

	override void OnDestroy()
	{
		if (highlight)
		{
			highlight.Destroy();
		}
		super.OnDestroy();
	}
}