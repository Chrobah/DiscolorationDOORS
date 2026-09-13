local import, base = ...

local assets = import("lib/assets")

return function()
	local root = Instance.new("Part")
	root.Name = "DiscolorationMoving"
	root.Size = Vector3.new(3, 4.5, 3)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false

	local middle = Instance.new("Attachment")
	middle.Parent = root

	local body = Instance.new("ParticleEmitter")
	body.Name = "Body"
	body.Texture = assets(base .. "assets/DiscolorSpritesheet.png")
	body.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	body.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	body.FlipbookFramerate = NumberRange.new(20, 30)
	body.FlipbookStartRandom = true
	body.Lifetime = NumberRange.new(0.08, 0.12)
	body.Rate = 30
	body.Speed = NumberRange.new(0)
	body.Size = NumberSequence.new(6)
	body.Transparency = NumberSequence.new(0.15)
	body.LightInfluence = 0
	body.LockedToPart = true
	body.ZOffset = 1
	body.Parent = middle

	local aura = Instance.new("ParticleEmitter")
	aura.Name = "Aura"
	aura.Texture = assets(base .. "assets/Discoloration1.png")
	aura.Lifetime = NumberRange.new(0.2, 0.3)
	aura.Rate = 20
	aura.Speed = NumberRange.new(0)
	aura.Size = NumberSequence.new(7.5)
	aura.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.9),
		NumberSequenceKeypoint.new(1, 1),
	})
	aura.LightEmission = 1
	aura.LightInfluence = 0
	aura.LockedToPart = true
	aura.Parent = middle

	local glow = Instance.new("ParticleEmitter")
	glow.Name = "Glow"
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.Lifetime = NumberRange.new(0.8, 1.6)
	glow.Rate = 30
	glow.Speed = NumberRange.new(0.5, 2)
	glow.SpreadAngle = Vector2.new(180, 180)
	glow.Drag = 1
	glow.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	glow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	glow.LightEmission = 1
	glow.LightInfluence = 0
	glow.Parent = root

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 16
	light.Parent = root

	local noise = Instance.new("Sound")
	noise.Name = "Noise"
	noise.SoundId = "rbxassetid://132917229044801"
	noise.Looped = true
	noise.Volume = 0
	noise.PlaybackSpeed = 0.55
	noise.RollOffMode = Enum.RollOffMode.InverseTapered
	noise.RollOffMinDistance = 12
	noise.RollOffMaxDistance = 120
	noise.Parent = root

	local muffle = Instance.new("EqualizerSoundEffect")
	muffle.HighGain = -30
	muffle.MidGain = -10
	muffle.LowGain = 5
	muffle.Parent = noise

	local crunch = Instance.new("DistortionSoundEffect")
	crunch.Level = 0.4
	crunch.Parent = noise

	return root
end
