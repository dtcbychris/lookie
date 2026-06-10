# PixelGP — Harbor Crown Circuit (first playable)

Monaco-inspired luxury coastal street circuit. Godot 4.3, pixel-3D look:
the whole world is 3D, rendered into a 640x360 SubViewport and integer-upscaled
with nearest filtering.

## Run it

1. Install [Godot 4.3+](https://godotengine.org/download) (standard build).
2. Open this folder (`pixelgp/`) in Godot, or run from a terminal:

   ```bash
   godot --path pixelgp
   ```

   The main scene `scenes/harbor_crown_circuit.tscn` starts a 3-lap race:
   you (RED FALCON) start P4 behind three AI cars.

### Controls

| Input | Action |
| --- | --- |
| W / Up | throttle |
| S / Down | brake |
| A / D or Left / Right | steer |
| Shift / Space | boost (meter regenerates; locked for 2s after wall contact) |
| T | cycle control preset: CLASSIC (above) / DRIVER (A brake, D gas, arrows steer) |
| C | toggle camera: RACE (overhead) / SHOWCASE (lower 3/4) |
| Tab | toggle full-circuit overview camera |
| R | restart race |

Preset and camera choices persist in `user://pixelgp_settings.cfg`.

### Handling notes (post-playtest tune)

- Coasting barely slows you — braking is the skill tool for hairpins.
- Wall penalty scales with impact angle: parallel grazing is near-free,
  slamming in costs real speed, drains boost, and pauses boost regen for 2s.
  You can't boost your way out of sloppy corners anymore.
- All sounds are procedurally synthesized (`scripts/audio_gen.gd`) —
  placeholder-quality by design, swappable for real sound design later.

## Tests / verification

```bash
# headless AI race sim — run after every physics change.
# 4 equal-skill AI cars, 3 laps; asserts every lap in 35-55s, spread < 2s,
# and 12-19 detected corners. Exit code 0 = pass.
godot --headless --path pixelgp --script res://tests/headless_sim.gd

# screenshot passes (need a display; under CI use xvfb-run)
xvfb-run godot --path pixelgp res://tests/screenshot_runner.tscn   # gameplay
xvfb-run godot --path pixelgp res://tests/landmark_shots.tscn      # landmarks
```

## Architecture (tracks are data, not hand-built scenes)

`data/harbor_crown_track.json` is the single source of truth: traced 63-point
centerline, proven physics tuning from the validated web prototype, team and
sponsor canon. Everything else is generated from it at load:

- `scripts/track_data.gd` — samples the closed Catmull-Rom centerline
  (882 samples, with the hand-authored elevation profile: tunnel dip, +12 m
  climb to the casino crest), computes curvature/normals/checkpoints and
  auto-numbers the corners.
- `scripts/car_physics.gd` — arcade model: speed-blended velocity, grip-limited
  turn rate, lateral-g cap, centerline wall clamp with near-free grazing.
  Pure math, no physics engine — the game and the headless sim run identical code.
- `scripts/ai_driver.gd` — prototype AI verbatim: `vAllow = min over lookahead
  of sqrt(LATG/curv + 2*BRAKE*0.8*dist)`, target `vAllow*0.89*skill`,
  lookahead steering, slipstream.
- `scripts/track_builder.gd` — road ribbon, markings, curbs, barriers,
  retaining skirts on the climb, tunnel (cutaway roof ribs so the top-down
  camera never loses the car), start line/gantry/grid, numbered corner signs.
- `scripts/scenery_builder.gd` — water shader, marina + yachts (sea yachts
  drift), ~500 procedural city buildings with window textures, Crown Casino,
  grandstands with flags, palms, sponsor billboards, street lights,
  decorative pit lane. All placement is distance-checked against the
  full circuit so scenery never intrudes on any corridor.
- `scripts/race_manager.gd` — countdown / racing / finished state machine,
  fixed-timestep stepping, live positions.
- `scripts/hud.gd` + `scripts/minimap.gd` — lap/time/best, position, speed,
  boost, leaderboard, live minimap with sector ticks.
- `scripts/follow_camera.gd` — smooth 3/4 follow with speed zoom + look-ahead.

Units: 1 Godot unit = 1 "world px" (art px × 2), matching `proven_tuning`.

## Known limitations (first playable)

- Pit lane is decorative (entry/exit gaps in the barrier + painted boxes);
  no pit-stop gameplay yet.
- Cars are ghost-ish: simple push-apart contact, no damage.
- AI ignores boost; player-only mechanic for now.
- Placeholder art language: procedural textures, box buildings, default font.
- The tunnel runs at harbor grade (token -0.1m dip): a real below-grade trench
  needs the causeway ground carved around the road corridor — deferred to the
  art pass.
- AI cars are silent; only the player car has engine audio.
- Real-world-mark-free by construction (fictional teams/sponsors from JSON).
