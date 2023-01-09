package game

import "core:fmt"
import SDL "vendor:sdl2"
import SDL_Image "vendor:sdl2/image"
import SDL_TTF "vendor:sdl2/ttf"
import MIX "vendor:sdl2/mixer"
import "core:math/rand"
import "core:strings"
import "core:unicode/utf8"

COLOR_WHITE : SDL.Color = {255,255,255, 255}

WINDOW_FLAGS :: SDL.WINDOW_SHOWN | SDL.WINDOW_RESIZABLE
RENDER_FLAGS :: SDL.RENDERER_ACCELERATED
FRAMES_PER_SECOND : f64 : 60
TARGET_DELTA_TIME :: f64(1000) / FRAMES_PER_SECOND
WINDOW_WIDTH :: 1600
WINDOW_HEIGHT :: 960
HITBOXES_VISIBLE :: false
PLAY_SOUND :: true

BACKGROUND_SPEED :: 100

PLAYER_SPEED : f64 : 250 // pixels per second
LASER_SPEED : f64 : 500
LASER_COOLDOWN_TIMER : f64 : TARGET_DELTA_TIME * (FRAMES_PER_SECOND / 2) // 1/2 second
NUM_OF_LASERS :: 100

DRONE_SPAWN_COOLDOWN_TIMER : f64 : TARGET_DELTA_TIME * FRAMES_PER_SECOND * 1 // 1 sec
NUM_OF_DRONES :: 5
NUM_OF_EXPLOSIONS :: 10
DRONE_MIN_SPEED : f64 : 250
DRONE_MAX_SPEED : f64 : 350

DRONE_LASER_COOLDOWN_TIMER_SINGLE : f64 : TARGET_DELTA_TIME * (FRAMES_PER_SECOND * 2)
DRONE_LASER_COOLDOWN_TIMER_ALL : f64 : TARGET_DELTA_TIME * (FRAMES_PER_SECOND * 3)
NUM_OF_DRONE_LASERS :: 2

NUM_OF_NUKES :: 10
NUKE_SPEED : f64 : 175
NUKE_COOLDOWN_TIMER : f64 : TARGET_DELTA_TIME * FRAMES_PER_SECOND // 1 second
NUM_OF_NUKE_EXPLOSIONS :: 10
NUM_NUKE_PU :: 15

STAGE_RESET_TIMER : f64 : TARGET_DELTA_TIME * FRAMES_PER_SECOND * 3 // 3 seconds

// each frame of an explosion is rendered for X frames
FRAME_TIMER_EXPLOSIONS : f64 : TARGET_DELTA_TIME * 4
FRAME_TIMER_NUKE_EXPLOSIONS : f64 : TARGET_DELTA_TIME * 2


Game :: struct
{

	sounds: [SoundId]^MIX.Chunk,
	bg_sound_fx: ^MIX.Music,
	is_restarting: bool,
	is_render_title: bool,
	is_render_sub_title: bool,
	begin_stage_animation: Animation,
	fade_animation: Animation,
	reset_animation: Animation,

	font: ^SDL_TTF.Font,
	texts: [TextId]Text,
	chars: map[rune]Text,

	screen: Screen,

	is_invincible: bool,
	is_paused: bool,

	stage_reset_timer: f64,
	perf_frequency: f64,
	renderer: ^SDL.Renderer,

	// player
	player: Entity,
	player_tex: ^SDL.Texture,
	left: bool,
	right: bool,
	up: bool,
	down: bool,


	laser_tex: ^SDL.Texture,
	lasers: [NUM_OF_LASERS]Entity,
	fire: bool,
	laser_cooldown : f64,

	drone_tex: ^SDL.Texture,
	drones: [NUM_OF_DRONES]Entity,
	drone_spawn_cooldown: f64,

	drone_laser_tex: ^SDL.Texture,
	drone_lasers: [NUM_OF_DRONE_LASERS]Entity,
	drone_laser_cooldown : f64,

	effect_explosion_frames: [11]^SDL.Texture,
	explosions: [NUM_OF_EXPLOSIONS]Explosion,

	// source rects for the sprite sheet
	nuke_sprite_sheet: ^SDL.Texture,
	effect_nuke_explosion_frames: [79]SDL.Rect,
	nuke_explosions: [NUM_OF_NUKE_EXPLOSIONS]Explosion,

	nuke_power_up_tex: ^SDL.Texture,
	nuke_power_ups: [NUM_NUKE_PU]NukePowerUp,
	player_nukes : int,

	fire_nuke: bool,
	nuke_tex: ^SDL.Texture,
	loaded_nuke_tex: ^SDL.Texture,
	loaded_nuke_dest: SDL.Rect,
	nukes: [NUM_OF_NUKES]NukeEntity,
	nuke_cooldown : f64,



	background_textures: [Background]^SDL.Texture,
	background_sections: [8]BackgroundSection,

	overlay: SDL.Rect,
	overlay_alpha: u8,

	// score
	current_score: int,

}

SoundId :: enum
{
	PlayerLaser,
	DroneLaser,
	PlayerExplosion,
	DroneExplosion,
}

Animation :: struct
{
	is_active: bool,
	current_frame: int,
	frames: [dynamic]Frame,
	maybe_run: proc(index: int = 0),
	start: proc(index: int = 0, dest: ^SDL.Rect = nil, dx: f64 = 0, starting_frame: int = 0),
}

Frame :: struct
{
	duration: f64,
	timer: f64,
	action: proc(index: int),
}


TextId :: enum
{
	HomeTitle,
	HomeSubTitle,
	DeathScreen,
	Loading,
	ScoreLabel,
}

Text :: struct
{
	tex: ^SDL.Texture,
	dest: SDL.Rect,
}

Screen :: enum
{
	Home,
	Play,
}

Background :: enum
{
	PlainStars,
	PurpleNebula,
}

BackgroundSection :: struct
{
	background: Background,
	dest: SDL.Rect,
}

NukeExplosion :: struct
{
	source: SDL.Rect,
	dest: SDL.Rect,
	dx: f64,
	frame: int,
	frame_timer: f64,
	is_active: bool,
}

Explosion :: struct
{
	dest: SDL.Rect,
	dx: f64,
	frame: int,
	frame_timer: f64,
	is_active: bool,
}

// can move on an angle
NukePowerUp :: struct
{
	dest: SDL.Rect,
	dx: f64,
	dy: f64,
	animation: Animation,
	counter: int,
	alpha: u8,
}

NukeEntity :: struct
{
	dest: SDL.Rect,
	dx: f64,
	dy: f64,
	health: int,
	animation: Animation,
	counter: int,
	alpha: u8,
	is_exploding: bool,
}

Entity :: struct
{
	source: SDL.Rect,
	dest: SDL.Rect,
	dx: f64,
	dy: f64,
	health: int,
	ready: f64,
}

game := Game{
	chars = make(map[rune]Text),
	screen = Screen.Home,
	is_render_title = true,
	is_render_sub_title = true,
	overlay = SDL.Rect{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT},
	overlay_alpha = 0,
	is_invincible = false,
	stage_reset_timer = STAGE_RESET_TIMER,

	loaded_nuke_dest = SDL.Rect{},

	current_score = 0,
}

// a proc (procedure) would be a 'function' in another language.
main :: proc()
{
	assert(SDL.Init(SDL.INIT_VIDEO | SDL.INIT_AUDIO) == 0, SDL.GetErrorString())
	defer SDL.Quit()
	assert(SDL_Image.Init(SDL_Image.INIT_PNG) != nil, SDL.GetErrorString())
	defer SDL_Image.Quit()

	init_font := SDL_TTF.Init()
	assert(init_font == 0, SDL.GetErrorString())
	game.font = SDL_TTF.OpenFont("assets/fonts/Terminal.ttf", 28)
	assert(game.font != nil, SDL.GetErrorString())
	defer SDL_TTF.Quit()

	init_sound := MIX.Init(MIX.INIT_OGG)
	assert(init_sound != -1, SDL.GetErrorString())
	defer MIX.Quit()

	FREQUENCY :: 44100
	STEREO :: 2 // MONO is 1
	CHUNK_SIZE :: 1024
	// OpenAudio will initialize the Audio subsystem if not already
	// https://wiki.libsdl.org/SDL_mixer/Mix_OpenAudio
	opened_audio := MIX.OpenAudio(FREQUENCY, MIX.DEFAULT_FORMAT, STEREO, CHUNK_SIZE)
	assert(opened_audio != -1, SDL.GetErrorString())

	// channels aka tracks -- how many sounds to play simultaneously
	// https://wiki.libsdl.org/SDL_mixer/Mix_AllocateChannels
	// 8 is default
	MIX.AllocateChannels(8)

	// lasers
	// https://wiki.libsdl.org/SDL_mixer/Mix_LoadWAV
	// returns a Chunk which is decoded into memory up front
	// many channels - many chunks
	game.sounds[SoundId.PlayerLaser] = MIX.LoadWAV("assets/sounds/player-laser.ogg")
	assert(game.sounds[SoundId.PlayerLaser] != nil, SDL.GetErrorString())
	defer MIX.FreeChunk(game.sounds[SoundId.PlayerLaser])

	game.sounds[SoundId.DroneLaser] = MIX.LoadWAV("assets/sounds/drone-laser.ogg")
	assert(game.sounds[SoundId.DroneLaser] != nil, SDL.GetErrorString())
	defer MIX.FreeChunk(game.sounds[SoundId.DroneLaser])

	// explosions
	game.sounds[SoundId.PlayerExplosion] = MIX.LoadWAV("assets/sounds/player-explosion.ogg")
	assert(game.sounds[SoundId.PlayerExplosion] != nil, SDL.GetErrorString())
	defer MIX.FreeChunk(game.sounds[SoundId.PlayerExplosion])

	game.sounds[SoundId.DroneExplosion] = MIX.LoadWAV("assets/sounds/drone-explosion.ogg")
	assert(game.sounds[SoundId.DroneExplosion] != nil, SDL.GetErrorString())
	defer MIX.FreeChunk(game.sounds[SoundId.DroneExplosion])


	// https://wiki.libsdl.org/SDL_mixer/Mix_LoadMUS
	// returns Music which is decoded on demand
	// one channel for music
	game.bg_sound_fx = MIX.LoadMUS("assets/sounds/space-bg-seamless.ogg")
	assert(game.bg_sound_fx != nil, SDL.GetErrorString())
	defer MIX.FreeMusic(game.bg_sound_fx)

	window := SDL.CreateWindow(
		"Odin Space Shooter",
		SDL.WINDOWPOS_CENTERED,
		SDL.WINDOWPOS_CENTERED,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		WINDOW_FLAGS,
	)
	assert(window != nil, SDL.GetErrorString())
	defer SDL.DestroyWindow(window)

	game.renderer = SDL.CreateRenderer(window, -1, RENDER_FLAGS)
	assert(game.renderer != nil, SDL.GetErrorString())
	defer SDL.DestroyRenderer(game.renderer)

	SDL.RenderSetLogicalSize(game.renderer, WINDOW_WIDTH, WINDOW_HEIGHT)

	create_statics()
	create_entities()
	create_animations()
	reset_timers()

	game.perf_frequency = f64(SDL.GetPerformanceFrequency())
	start : f64
	end : f64

	event : SDL.Event
	state : [^]u8

	// https://wiki.libsdl.org/SDL_mixer/Mix_PlayMusic
	// -1 => infinite loop
	if PLAY_SOUND do MIX.PlayMusic(game.bg_sound_fx, -1)

	game_loop : for
	{

		start = get_time()

		// Begin LOOP code...

		// 1. Get our Keyboard State :: which keys are pressed?
		state = SDL.GetKeyboardState(nil)

		game.left = state[SDL.Scancode.A] > 0
		game.right = state[SDL.Scancode.D] > 0
		game.up = state[SDL.Scancode.W] > 0
		game.down = state[SDL.Scancode.S] > 0
		game.fire = state[SDL.Scancode.SPACE] > 0
		game.fire_nuke = state[SDL.Scancode.N] > 0

		// 2. Handle any input events :: quit, pause, fire weapons?
		if SDL.PollEvent(&event)
		{

			if event.type == SDL.EventType.QUIT
			{
				break game_loop
			}

			if event.type == SDL.EventType.KEYDOWN
			{

				// a #partial switch allows us to ignore other scancode types;
				// otherwise, the compiler will refuse to compile the program, alerting us of the unhandled cases
				#partial switch event.key.keysym.scancode
				{
					case .ESCAPE:
						break game_loop
					case .L:
						fmt.println("log")
					case .I:
						game.is_invincible = !game.is_invincible
						fmt.println("I'm invincible!")
					case .P:
						game.is_paused = ! game.is_paused
					case .SPACE:
						if game.screen == Screen.Home
						{
							game.begin_stage_animation.start()
							game.fade_animation.start()
							game.is_render_sub_title = false
						}
				}

			}
		}

		/****************************
		// 3. Update and Render
		****************************/

		// background first...
		for index in 0..<len(game.background_sections)
		{
			section := &game.background_sections[index]

			right_side := section.dest.x + section.dest.w

			if right_side < -(section.dest.w / 2)
			{
				next_section_index : int
				if index < 4
				{
					next_section_index = index == 0 ? 3 : index - 1
				}
				else
				{
					next_section_index = index == 4 ? 7 : index - 1
				}

				next_section := &game.background_sections[next_section_index]

				// position AFTER the last section in line
				section.dest.x = next_section.dest.x + next_section.dest.w
			}

			section.dest.x -= i32(get_delta_motion(BACKGROUND_SPEED))
			tex := game.background_textures[section.background]

			if game.screen == Screen.Home
			{
				tex = game.background_textures[Background.PlainStars]
			}

			SDL.RenderCopy(game.renderer, tex, nil, &section.dest)

		}

		if game.screen == Screen.Play
		{

			// Based on the positions that are currently visible to the Player...
			// 1. Check Collisions
			// 2. Move any entities that survive
			// 3. Reset any entities that are offscreen
			// 4. Render onscreen entities
			// 5. Fire new lasers + render
			// 6. Respawn new drones + render

			// Render Lasers -- check collisions -> render
			for laser in &game.lasers
			{

				if laser.health == 0 do continue

				detect_collision : for drone in &game.drones
				{
					if drone.health == 0 do continue

					hit := collision(
						laser.dest.x,
						laser.dest.y,
						laser.dest.w,
						laser.dest.h,

						drone.dest.x,
						drone.dest.y,
						drone.dest.w,
						drone.dest.h,
						)

					if hit
					{

						laser.health = 0

				    	explode_drone(&drone)
				    	game.current_score += 1

				    	spawn_nuke_pu: for index in 0..<NUM_NUKE_PU
				    	{

					    	pu := &game.nuke_power_ups[index].animation

					    	if !pu.is_active
					    	{
					    		pu.start(index, &drone.dest, drone.dx)

					    		break spawn_nuke_pu
					    	}

				    	}

						break detect_collision
					}

				}

				laser.dest.x += i32(get_delta_motion(laser.dx))

				if laser.dest.x > WINDOW_WIDTH
				{
					laser.health = 0
				}

				if laser.health > 0
				{
					when HITBOXES_VISIBLE do render_hitbox(&laser.dest)
					SDL.RenderCopy(game.renderer, game.laser_tex, nil, &laser.dest)
				}
			}

			// Render Drone Lasers -- check collisions -> render
			for laser, idx in &game.drone_lasers
			{

				if laser.health == 0 do continue

				// check collision based on previous frame's rendered position
				// check player health to make sure drone lasers don't explode
				// while we're rendering our stage_reset() scenes after a player
				// has already died.
				if game.player.health > 0
				{
					hit := collision(
						game.player.dest.x,
						game.player.dest.y,
						game.player.dest.w,
						game.player.dest.h,

						laser.dest.x,
						laser.dest.y,
						laser.dest.w,
						laser.dest.h,
						)

					if hit
					{
						laser.health = 0

						if !game.is_invincible
						{
					    	explode_player(&game.player)
						}
					}
				}

				if !game.is_paused
				{
					laser.dest.x += i32(laser.dx)
					laser.dest.y += i32(laser.dy)
				}

				// reset laser if it's offscreen
				// checking x and y b/c these drone
				// lasers go in different directions
				if laser.dest.x <= 0 ||
				laser.dest.x >= WINDOW_WIDTH ||
				laser.dest.y <= 0 ||
				laser.dest.y >= WINDOW_HEIGHT
				{
					laser.health = 0
				}

				if laser.health > 0
				{
					when HITBOXES_VISIBLE do render_hitbox(&laser.dest)
					SDL.RenderCopy(game.renderer, game.drone_laser_tex, &laser.source, &laser.dest)
				}

			}

			// At this point we've checked our collisions
			// and we've figured out our active Player Lasers,
			// Drones, and Drone Lasers.

			// render active drones and fire new lasers
			respawned := false
			for drone in &game.drones
			{

				if !respawned &&
				drone.health == 0 &&
				!(game.drone_spawn_cooldown > 0)
				{
					drone.dest.x = WINDOW_WIDTH
					drone.dest.y = i32(rand.float32_range(120, WINDOW_HEIGHT - 120))
					drone.health = 1
					drone.ready = DRONE_LASER_COOLDOWN_TIMER_SINGLE / 10 // ready to fire quickly

					game.drone_spawn_cooldown = DRONE_SPAWN_COOLDOWN_TIMER

					respawned = true
				}

				if drone.health == 0 do continue

				drone.dest.x -= i32(get_delta_motion(drone.dx))

				if drone.dest.x <= 0
				{
					drone.health = 0
				}

				if drone.health > 0
				{

					// check player health to account for our 3-second transition
					// scenes after a player dies
					if  game.player.health > 0
					{
						hit := collision(
							game.player.dest.x,
							game.player.dest.y,
							game.player.dest.w,
							game.player.dest.h,

							drone.dest.x,
							drone.dest.y,
							drone.dest.w,
							drone.dest.h,
							)

						if hit
						{

					    	explode_drone(&drone)

							if !game.is_invincible
							{
						    	explode_player(&game.player)
							}

					    	// skip the rest of this loop so we
					    	// don't render our drone or fire its laser
							continue
						}
					}

					SDL.RenderCopy(game.renderer, game.drone_tex, nil, &drone.dest)

					// for each active drone, fire a laser if cooldown time reached
					// and the drone isn't moving offscreen
					// without this 300 pixel buffer, it looks like lasers
					// are coming from offscreen
					if drone.dest.x > 30 &&
					drone.dest.x < (WINDOW_WIDTH - 30) &&
					drone.ready <= 0 &&
					game.drone_laser_cooldown < 0
					{

						// find a drone laser:
						fire_drone_laser : for laser, idx in &game.drone_lasers
						{

							// find the first one available
							if laser.health == 0
							{

								// fire from the drone's position
								laser.dest.x = drone.dest.x
								laser.dest.y = drone.dest.y
								laser.health = 1

								new_dx, new_dy := calc_slope(
									laser.dest.x,
									laser.dest.y,
									game.player.dest.x,
									game.player.dest.y,
									)

								if !game.is_paused
								{
									laser.dx = new_dx * get_delta_motion(drone.dx + 150)
									laser.dy = new_dy * get_delta_motion(drone.dx + 150)
								}

								// reset the cooldown to prevent firing too rapidly
								drone.ready = DRONE_LASER_COOLDOWN_TIMER_SINGLE
								game.drone_laser_cooldown = DRONE_LASER_COOLDOWN_TIMER_ALL

								SDL.RenderCopy(game.renderer, game.drone_laser_tex, &laser.source, &laser.dest)

								if PLAY_SOUND do MIX.PlayChannel(-1, game.sounds[SoundId.DroneLaser], 0)

								break fire_drone_laser
							}
						}
					}

					// decrement our 'ready' timer
					// to help distribute lasers more evenly between
					// the active drones
					drone.ready -= TARGET_DELTA_TIME

				}

			}

			// update player position, etc...
			if game.player.health > 0
			{

				delta_motion_x := get_delta_motion(game.player.dx)
				delta_motion_y := get_delta_motion(game.player.dy)

				if game.left
				{
					move_player(-delta_motion_x, 0)
				}

				if game.right
				{
					move_player(delta_motion_x, 0)
				}

				if game.up
				{
					move_player(0, -delta_motion_y)
				}

				if game.down
				{
					move_player(0, delta_motion_y)
				}

				when HITBOXES_VISIBLE do render_hitbox(&game.player.dest)

				SDL.RenderCopy(game.renderer, game.player_tex, nil, &game.player.dest)

				if game.is_invincible
				{
					r := SDL.Rect{ game.player.dest.x - 10, game.player.dest.y - 10, game.player.dest.w + 20, game.player.dest.h + 20 }
					SDL.SetRenderDrawColor(game.renderer, 0, 255, 0, 255)
					SDL.RenderDrawRect(game.renderer, &r)
				}

				// Fire Lasers
				// NOTE :: firing new lasers AFTER
				// Collisions have been detected; otherwise,
				// collisions may be true for lasers that aren't rendered, yet.
				// BUT this means rendering of new lasers is delayed by one frame.
				// Is this the best way?
				if game.fire && !(game.laser_cooldown > 0)
				{
					// find a laser:
					fire : for laser in &game.lasers
					{
						// find the first one available
						if laser.health == 0
						{
							laser.dest.x = game.player.dest.x + 20
							laser.dest.y = game.player.dest.y
							laser.health = 1
							// reset the cooldown to prevent firing too rapidly
							game.laser_cooldown = LASER_COOLDOWN_TIMER

							SDL.RenderCopy(game.renderer, game.laser_tex, nil, &laser.dest)
							if PLAY_SOUND do MIX.PlayChannel(-1, game.sounds[SoundId.PlayerLaser], 0)

							break fire
						}
					}
				}

				// Fire Nuke
				if game.fire_nuke && game.player_nukes > 0 && game.nuke_cooldown < 0
				{
					// find a nuke:
					fire_nuke : for nuke, i in &game.nukes
					{
						// find the first one available
						if !nuke.animation.is_active
						{

							nuke.animation.start(i, &game.player.dest, NUKE_SPEED)

							break fire_nuke
						}
					}
				}

			}

			// Player Dead
			if game.player.health == 0 && !game.is_restarting
			{

				msg := game.texts[TextId.DeathScreen]
				msg.dest.x = (WINDOW_WIDTH / 2) - (msg.dest.w / 2)
				msg.dest.y = (WINDOW_HEIGHT / 2) - (msg.dest.h / 2)
				SDL.RenderCopy(game.renderer, msg.tex, nil, &msg.dest)

				game.stage_reset_timer -= TARGET_DELTA_TIME

				if game.stage_reset_timer < 0
				{

					game.reset_animation.start()
					game.begin_stage_animation.start()
					game.fade_animation.start()
				}

			}

			// Render Nuke Explosions
			for x in &game.nuke_explosions
			{
				if x.frame > 78
				{
					x.is_active = false
				}

				if !x.is_active do continue

				source_rect := game.effect_nuke_explosion_frames[x.frame]

				// at explosion, the smoke travels at a speed /3 of that of the destroyed entity
				x.dest.x -= i32(get_delta_motion(x.dx)) / 3

				// if the explosion is relatively fresh
				// we'll destroy any drones, lasers, and drone lasers
				// that pass through
				if x.frame < 50
				{

					nuke_explosion_area := SDL.Rect{
						x = (x.dest.x + (x.dest.w / 4)),
						y = (x.dest.y + (x.dest.h / 4)),
						w = (x.dest.w - (x.dest.w / 2)),
						h = (x.dest.h - (x.dest.h / 2)),
					}

					when HITBOXES_VISIBLE do render_hitbox(&nuke_explosion_area)

					// check hit player
					// don't blow yourself up!
					if game.player.health > 0 && !(game.is_invincible)
					{
						hit := collision(
							game.player.dest.x,
							game.player.dest.y,
							game.player.dest.w,
							game.player.dest.h,

							nuke_explosion_area.x,
							nuke_explosion_area.y,
							nuke_explosion_area.w,
							nuke_explosion_area.h,
							)

						if hit
						{
							explode_player(&game.player)
						}
					}

					for nuke in &game.nukes
					{
						// make sure we don't trigger this collision again and again
						// as these frames continue to tick by
						if nuke.health == 0 || nuke.is_exploding do continue

						hit := collision(
							nuke.dest.x,
							nuke.dest.y,
							nuke.dest.w,
							nuke.dest.h,

							nuke_explosion_area.x,
							nuke_explosion_area.y,
							nuke_explosion_area.w,
							nuke_explosion_area.h,
							)

						if hit
						{
							// is_exploding is used in this specific spot
							// to prevent the current_frame from being reset
							// again and again as the nuke continues to collide
							// with the first nuke's explosion
							nuke.is_exploding = true
							nuke.animation.current_frame = 2
						}
					}

					for drone in &game.drones
					{
						if drone.health == 0 do continue

						hit := collision(
							drone.dest.x,
							drone.dest.y,
							drone.dest.w,
							drone.dest.h,

							nuke_explosion_area.x,
							nuke_explosion_area.y,
							nuke_explosion_area.w,
							nuke_explosion_area.h,
							)

						if hit
						{
							explode_drone(&drone)

					    	game.current_score += 1
						}
					}

					for laser in &game.lasers
					{
						if laser.health == 0 do continue

						hit := collision(
							laser.dest.x,
							laser.dest.y,
							laser.dest.w,
							laser.dest.h,

							nuke_explosion_area.x,
							nuke_explosion_area.y,
							nuke_explosion_area.w,
							nuke_explosion_area.h,
							)

						if hit
						{
							laser.health = 0
							// this starting position looks a little better when our laser explodes
							explode((laser.dest.x + laser.dest.w), laser.dest.y, laser.dx)
						}
					}


					for laser in &game.drone_lasers
					{
						if laser.health == 0 do continue

						hit := collision(
							laser.dest.x,
							laser.dest.y,
							laser.dest.w,
							laser.dest.h,

							nuke_explosion_area.x,
							nuke_explosion_area.y,
							nuke_explosion_area.w,
							nuke_explosion_area.h,
							)

						if hit
						{
							laser.health = 0
							x := laser.dest.x - (laser.dest.w / 2)
							y := laser.dest.y - (laser.dest.h / 2)
							explode(x, y, laser.dx)
						}
					}



				}

				SDL.RenderCopy(game.renderer, game.nuke_sprite_sheet, &source_rect, &x.dest)

				x.frame_timer -= TARGET_DELTA_TIME

				// switch frames
				if x.frame_timer < 0
				{
					// restart timer
					x.frame_timer = FRAME_TIMER_NUKE_EXPLOSIONS
					x.frame += 1
				}

			}


			// Render Explosions
			for x in &game.explosions
			{
				// there are 11 sprites
				// so index 10 will be our final frame
				if x.frame > 10
				{
					x.is_active = false
				}

				if x.is_active
				{

					t := game.effect_explosion_frames[x.frame]

					// at explosion, the smoke travels at a speed /3 of that of the destroyed entity
					x.dest.x -= i32(get_delta_motion(x.dx)) / 3

					SDL.RenderCopy(game.renderer, t, nil, &x.dest)

					x.frame_timer -= TARGET_DELTA_TIME

					// switch frames
					if x.frame_timer < 0
					{
						// restart timer
						x.frame_timer = FRAME_TIMER_EXPLOSIONS
						x.frame += 1
					}
				}

			}

			// score label
			score := game.texts[TextId.ScoreLabel]
			score.dest.x = 10
			score.dest.y = 10
			SDL.RenderCopy(game.renderer, score.tex, nil, &score.dest)

			// current_score
			score_str : string = (fmt.tprintf("%v", game.current_score))[:]
			char_spacing : i32 = 2
			prev_chars_w : i32 = 0

			starting_x : i32 = score.dest.x + score.dest.w + 10
			starting_y : i32 = score.dest.y

			// iterate characters in the string
			for c in score_str
			{
				// grab the texture for the single character
				char : Text = game.chars[c]

				// render this character after the previous one
				char.dest.x = starting_x + prev_chars_w
				char.dest.y = starting_y

				SDL.RenderCopy(game.renderer, char.tex, nil, &char.dest)

				prev_chars_w += char.dest.w + char_spacing
			}

			nuke_starting_x : i32 = 10
			nuke_starting_y : i32 = 30

			nuke_spacing : i32 = 2
			prev_nukes_w : i32 = 0

			if game.player_nukes > 0
			{

				for i := 0; i < game.player_nukes; i += 1
				{
					game.loaded_nuke_dest.x = nuke_starting_x + prev_nukes_w
					game.loaded_nuke_dest.y = nuke_starting_y

					SDL.RenderCopy(game.renderer, game.loaded_nuke_tex, nil, &game.loaded_nuke_dest)

					prev_nukes_w += game.loaded_nuke_dest.w + nuke_spacing
				}

			}

		// end game.screen == Screen.Play
		}



    	for index in 0..<NUM_NUKE_PU
    	{
	    	nuke_pu := &game.nuke_power_ups[index]
	    	nuke_pu.animation.maybe_run(index)
    	}

    	for nuke, i in &game.nukes
    	{
	    	nuke.animation.maybe_run(i)
    	}

		game.begin_stage_animation.maybe_run()
		game.fade_animation.maybe_run()
		game.reset_animation.maybe_run()

		if game.is_render_title
		{

			title := game.texts[TextId.HomeTitle]
			title.dest.x = (WINDOW_WIDTH / 2) - (title.dest.w / 2)
			title.dest.y = (WINDOW_HEIGHT / 2) - (title.dest.h / 2)

			SDL.RenderCopy(game.renderer, title.tex, nil, &title.dest)

			if game.is_render_sub_title
			{
				sub_title := game.texts[TextId.HomeSubTitle]
				sub_title.dest.x = (WINDOW_WIDTH / 2) - (sub_title.dest.w / 2)
				sub_title.dest.y = (WINDOW_HEIGHT / 2) - (sub_title.dest.h / 2) + title.dest.h

				SDL.RenderCopy(game.renderer, sub_title.tex, nil, &sub_title.dest)
			}
		}



		// ... end LOOP code

		// TIMERS
		game.laser_cooldown -= TARGET_DELTA_TIME
		game.nuke_cooldown -= TARGET_DELTA_TIME
		game.drone_spawn_cooldown -= TARGET_DELTA_TIME
		game.drone_laser_cooldown -= TARGET_DELTA_TIME



		// spin lock to hit our framerate
		end = get_time()

		if (end - start > TARGET_DELTA_TIME)
		{
			fmt.println("Exceeded Target Delta Time")
			break game_loop
		}

		for end - start < TARGET_DELTA_TIME
		{
			end = get_time()
		}

		// fmt.println("FPS : ", 1000 / (end - start))

		// actual flipping / presentation of the copy
		// read comments here :: https://wiki.libsdl.org/SDL_RenderCopy
		SDL.RenderPresent(game.renderer)

		// make sure our background is black
		// RenderClear colors the entire screen whatever color is set here
		SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 255)

		// clear the old scene from the renderer
		// clear after presentation so we remain free to call RenderCopy() throughout our update code / wherever it makes the most sense
		SDL.RenderClear(game.renderer)

	}

}

move_player :: proc(x, y: f64)
{
	game.player.dest.x = clamp(game.player.dest.x + i32(x), 0, WINDOW_WIDTH - game.player.dest.w)
	game.player.dest.y = clamp(game.player.dest.y + i32(y), 0, WINDOW_HEIGHT - game.player.dest.h)
}

// Calculate the dx, dy needed to go from_x,y to_x,y
calc_slope :: proc(from_x, from_y, to_x, to_y : i32) -> (f64, f64)
{
	steps := f64(max(abs(to_x - from_x), abs(to_y - from_y)))

	if steps == 0
	{
		return 0,0
	}

	new_dx := f64(to_x) - f64(from_x)
	new_dx /= steps

	new_dy := f64(to_y) - f64(from_y)
	new_dy /= steps

	return new_dx, new_dy
}

get_delta_motion :: proc(speed: f64) -> f64
{
	if game.is_paused
	{
		return 0
	}

	return speed * (TARGET_DELTA_TIME / 1000)
}

get_time :: proc() -> f64
{
	return f64(SDL.GetPerformanceCounter()) * 1000 / game.perf_frequency
}

render_hitbox :: proc(dest: ^SDL.Rect)
{
	r := SDL.Rect{ dest.x, dest.y, dest.w, dest.h }

	SDL.SetRenderDrawColor(game.renderer, 255, 0, 0, 255)
	SDL.RenderDrawRect(game.renderer, &r)
}

collision :: proc(x1, y1, w1, h1, x2, y2, w2, h2: i32) -> bool
{
	return (max(x1, x2) < min(x1 + w1, x2 + w2)) && (max(y1, y2) < min(y1 + h1, y2 + h2))
}

reset_timers :: proc()
{
	game.laser_cooldown = LASER_COOLDOWN_TIMER
	game.nuke_cooldown = NUKE_COOLDOWN_TIMER
	game.drone_spawn_cooldown = DRONE_SPAWN_COOLDOWN_TIMER
	game.drone_laser_cooldown = DRONE_LASER_COOLDOWN_TIMER_ALL
	game.stage_reset_timer = STAGE_RESET_TIMER
}

reset_entities :: proc()
{
	game.player.dest.x = 20
	game.player.dest.y = WINDOW_HEIGHT / 2
	game.player_nukes = 0

	for nuke in &game.nukes
	{
		nuke.health = 0
	}

	for laser in &game.lasers
	{
		laser.health = 0
	}

	for laser in &game.drone_lasers
	{
		laser.health = 0
	}

	for drone in &game.drones
	{
		random_speed := rand.float64_range(DRONE_MIN_SPEED, DRONE_MAX_SPEED)
		drone.health = 0
		drone.ready = DRONE_LASER_COOLDOWN_TIMER_SINGLE
		drone.dx = random_speed
		drone.dy = random_speed
	}

	for explosion in &game.nuke_explosions
	{
		explosion.frame = 0
		explosion.is_active = false
	}

	for explosion in &game.explosions
	{
		explosion.frame = 0
		explosion.is_active = false
	}

	for nuke_pu in &game.nuke_power_ups
	{
		nuke_pu.animation.is_active = false
	}
}

create_entities :: proc()
{

	// player
	player_texture := SDL_Image.LoadTexture(game.renderer, "assets/player.png")
	assert(player_texture != nil, SDL.GetErrorString())

	// init with starting position
	destination := SDL.Rect{x = 20, y = WINDOW_HEIGHT / 2}
	SDL.QueryTexture(player_texture, nil, nil, &destination.w, &destination.h)
	// reduce the source size by 10x
	destination.w /= 10
	destination.h /= 10

	game.player_tex = player_texture
	game.player = Entity{
		dest = destination,
		dx = PLAYER_SPEED,
		dy = PLAYER_SPEED,
		health = 1,
	}

	nuke_tex := SDL_Image.LoadTexture(game.renderer, "assets/nuke.png")
	assert(nuke_tex != nil, SDL.GetErrorString())
	nuke_w : i32
	nuke_h : i32
	SDL.QueryTexture(nuke_tex, nil, nil, &nuke_w, &nuke_h)

	game.nuke_tex = nuke_tex

	for index in 0..<NUM_OF_NUKES
	{
		destination := SDL.Rect{
			w = nuke_w / 2,
			h = nuke_h / 2,
		}

		game.nukes[index] = NukeEntity{
			dest = SDL.Rect{
				w = nuke_w / 2,
				h = nuke_h / 2,
			},
			dx = NUKE_SPEED,
			dy = NUKE_SPEED,
			health = 0,
			counter = 0,
			animation = Animation{
				is_active = false,
				current_frame = 0,
				frames = make([dynamic]Frame, 4, 4),
			},
		}

		n := &game.nukes[index].animation

		n.start = proc(index: int, dest: ^SDL.Rect, dx: f64, starting_frame: int = 0)
		{
			n := &game.nukes[index]
			n.is_exploding = false // for nuke-to-nuke explosions
			n.health = 1
			n.counter = 0
			n.dest.x = dest.x
			n.dest.y = dest.y
			n.alpha = 255
			n.animation.current_frame = starting_frame
			n.animation.is_active = true
			// timers otherwise won't be reset if the nuke
			// collides with drone and explodes
			n.animation.frames[0].timer = n.animation.frames[0].duration
			n.animation.frames[1].timer = n.animation.frames[1].duration
			n.animation.frames[2].timer = n.animation.frames[2].duration
			n.animation.frames[3].timer = n.animation.frames[3].duration

			if PLAY_SOUND do MIX.PlayChannel(-1, game.sounds[SoundId.PlayerLaser], 0)
			game.nuke_cooldown = NUKE_COOLDOWN_TIMER
			game.player_nukes -= 1
		}

		n.maybe_run = proc(index: int)
		{
			n := &game.nukes[index]

			if n.animation.current_frame > 3
			{
				n.animation.is_active = false
			}

			if !n.animation.is_active do return

			frame := &n.animation.frames[n.animation.current_frame]

			detect_laser_collision : for laser in &game.lasers
			{
				if laser.health == 0 do continue

				hit := collision(
					laser.dest.x,
					laser.dest.y,
					laser.dest.w,
					laser.dest.h,

					n.dest.x,
					n.dest.y,
					n.dest.w,
					n.dest.h,
					)

				if hit
				{
					explode_nuke(n)
					laser.health = 0

					break detect_laser_collision
				}

			}

			detect_drone_laser_collision : for laser in &game.drone_lasers
			{
				if laser.health == 0 do continue

				hit := collision(
					laser.dest.x,
					laser.dest.y,
					laser.dest.w,
					laser.dest.h,

					n.dest.x,
					n.dest.y,
					n.dest.w,
					n.dest.h,
					)

				if hit
				{
					explode_nuke(n)
					laser.health = 0

					break detect_drone_laser_collision
				}

			}

			detect_nuke_collision : for drone in &game.drones
			{
				if drone.health == 0 do continue

				hit := collision(
					n.dest.x,
					n.dest.y,
					n.dest.w,
					n.dest.h,

					drone.dest.x,
					drone.dest.y,
					drone.dest.w,
					drone.dest.h,
					)

				if hit
				{

			    	explode_drone(&drone)

					explode_nuke(n)

			    	game.current_score += 1

					break detect_nuke_collision
				}

			}

			if !n.animation.is_active do return

			frame.action(index)

			frame.timer -= TARGET_DELTA_TIME

			if frame.timer < 0
			{
				frame.timer = frame.duration
				n.animation.current_frame += 1
			}
		}

		n.frames[0] = Frame{
			duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND) * 4,
			timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND) * 4,
			action = proc(index: int)
			{
				n := &game.nukes[index]

				n.dest.x += i32(get_delta_motion(n.dx))

				SDL.SetTextureAlphaMod(game.nuke_tex, 255)
				SDL.RenderCopy(game.renderer, game.nuke_tex, nil, &n.dest)
			},
		}

		n.frames[1] = Frame{
			duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND) * 2,
			timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND) * 2,
			action = proc(index: int)
			{

				n := &game.nukes[index]

				// blinking
				if n.counter > 3
				{
					n.counter = 0

					if n.alpha == 255
					{
						n.alpha = 100
					}
					else
					{
						n.alpha = 255
					}

				}

				n.dest.x += i32(get_delta_motion(n.dx))

				SDL.SetTextureAlphaMod(game.nuke_tex, n.alpha)
				SDL.SetTextureColorMod(game.nuke_tex, 255, 255, 255)
				SDL.RenderCopy(game.renderer, game.nuke_tex, nil, &n.dest)

				n.counter += 1
			},
		}

		// Stops and shakes
		n.frames[2] = Frame{

			duration = TARGET_DELTA_TIME * FRAMES_PER_SECOND,
			timer = TARGET_DELTA_TIME * FRAMES_PER_SECOND,
			action = proc(index: int)
			{
				n := &game.nukes[index]
				dx : f64
				dy : f64


				if n.counter < 2
				{
					dx -= get_delta_motion(n.dx)
					dy -= get_delta_motion(n.dx)

					n.counter +=1
				}
				else if n.counter < 4
				{
					dx += get_delta_motion(n.dx)
					dy += get_delta_motion(n.dx)
					n.counter +=1
				}
				else if n.counter < 6
				{
					dx += get_delta_motion(n.dx)
					dy -= get_delta_motion(n.dx)
					n.counter +=1
				}
				else if n.counter < 8
				{
					dx -= get_delta_motion(n.dx)
					dy += get_delta_motion(n.dx)
					n.counter +=1
				}
				else
				{
					n.counter = 0
				}

				n.dest.x += i32(dx + 0.5)
				n.dest.y += i32(dy)

				SDL.SetTextureAlphaMod(game.nuke_tex, 255)
				SDL.RenderCopy(game.renderer, game.nuke_tex, nil, &n.dest)
			},
		}

		n.frames[3] = Frame{
			duration = TARGET_DELTA_TIME,
			timer = TARGET_DELTA_TIME,
			action = proc(index: int)
			{
				n := &game.nukes[index]

				explode_nuke(n)

			},
		}
	}

	laser_texture := SDL_Image.LoadTexture(game.renderer, "assets/bullet_red_2.png")
	assert(laser_texture != nil, SDL.GetErrorString())
	laser_w : i32
	laser_h : i32
	SDL.QueryTexture(laser_texture, nil, nil, &laser_w, &laser_h)

	game.laser_tex = laser_texture

	for index in 0..<NUM_OF_LASERS
	{
		destination := SDL.Rect{
			x = WINDOW_WIDTH + 20, // offscreen means available to fire
			w = laser_w / 3,
			h = laser_h / 3,
		}

		game.lasers[index] = Entity{
			dest = destination,
			dx = LASER_SPEED,
			dy = LASER_SPEED,
			health = 0,
		}
	}


	// drones
	drone_texture := SDL_Image.LoadTexture(game.renderer, "assets/drone_1.png")
	assert(drone_texture != nil, SDL.GetErrorString())
	drone_w : i32
	drone_h : i32
	SDL.QueryTexture(drone_texture, nil, nil, &drone_w, &drone_h)

	game.drone_tex = drone_texture

	for index in 0..<NUM_OF_DRONES
	{
		destination := SDL.Rect{
			x = -(drone_w),
			y = 0,
			w = drone_w / 5,
			h = drone_h / 5,
		}

		// randomize speed to make things more interesting
		random_speed := rand.float64_range(DRONE_MIN_SPEED, DRONE_MAX_SPEED)

		game.drones[index] = Entity{
			dest = destination,
			dx = random_speed,
			dy = random_speed,
			health = 0,
			ready = DRONE_LASER_COOLDOWN_TIMER_SINGLE,
		}
	}


	drone_laser_texture := SDL_Image.LoadTexture(game.renderer, "assets/drone_laser_1.png")
	assert(drone_laser_texture != nil, SDL.GetErrorString())
	drone_laser_w : i32
	drone_laser_h : i32
	SDL.QueryTexture(drone_laser_texture, nil, nil, &drone_laser_w, &drone_laser_h)

	game.drone_laser_tex = drone_laser_texture

	for index in 0..<NUM_OF_DRONE_LASERS
	{
		destination := SDL.Rect{
			w = drone_laser_w / 8,
			h = drone_laser_h / 6,
		}

		source := SDL.Rect{54, 28, 62, 28}

		game.drone_lasers[index] = Entity{
			source = source,
			dest = destination,
			health = 0,
		}
	}

	// nuke_explosions
	game.nuke_sprite_sheet = SDL_Image.LoadTexture(game.renderer, "assets/nuke_x_1.png")
	assert(game.nuke_sprite_sheet != nil, SDL.GetErrorString())

	starting_x : i32 = 300
	starting_y : i32 = 0

	for i in 0..<79
	{
		// end of row
		if i %% 13 == 0
		{
			starting_y += 300
			starting_x = 0
		}

		source := SDL.Rect{
			x = starting_x,
			y = starting_y,
			w = 300,
			h = 300,
		}

		game.effect_nuke_explosion_frames[i] = source

		starting_x += 300
	}


	for index in 0..<NUM_OF_NUKE_EXPLOSIONS
	{
		game.nuke_explosions[index] = Explosion{
			dest = SDL.Rect{
				x = 100,
				y = 100,
				w = 600,
				h = 600,
			},
			// all explosions start with the FIRST sprite
			frame = 0,
			is_active = false,
		}
	}

	// Explosions
	for i in 0..<11
	{
		// aprintf needs to be freed, as the string is allocated with the current context
		// path := cstring(raw_data(fmt.aprintf("assets/explosion_{}.png", i + 1)))

		// this was recommended by Bill:
		path := caprintf("assets/explosion_{}.png", i + 1)
		game.effect_explosion_frames[i] = SDL_Image.LoadTexture(game.renderer, path)
		assert(game.effect_explosion_frames[i] != nil, SDL.GetErrorString())
	}

	// explosions are animated, and don't clear right away,
	// so we estimate needing * 2 explosions
	for index in 0..<(NUM_OF_DRONES * 2)
	{

		game.explosions[index] = Explosion{
			dest = SDL.Rect{
				x = 100,
				y = 100,
				w = 453 / 3,
				h = 453 / 3,
			},
			// all explosions start with the FIRST sprite
			frame = 0,
			is_active = false,
		}
	}


	// NukePowerUps:
	// item animation - creates an item that will blink after a few seconds and eventually disappear
	game.nuke_power_up_tex = SDL_Image.LoadTexture(game.renderer, "assets/pu_nuke.png")
	assert(game.nuke_power_up_tex != nil, SDL.GetErrorString())
	pu_width : i32
	pu_height : i32
	SDL.QueryTexture(game.nuke_power_up_tex, nil, nil, &pu_width, &pu_height)

	for index in 0..<NUM_NUKE_PU
	{
		// initialize our NukePowerUp
		game.nuke_power_ups[index] = NukePowerUp{
			dest = SDL.Rect{
				w = (pu_width / 7),
				h = (pu_height / 7),
			},
			animation = Animation{
				is_active = false,
				current_frame = 0,
				frames = make([dynamic]Frame, 3, 3),
			},
		}

		// fill out our Animation:
		pu := &game.nuke_power_ups[index].animation

		pu.start = proc(index: int, dest: ^SDL.Rect, dx: f64, starting_frame: int = 0) {
			// Odin is not object oriented, we need `index` so we can
			// identify the correct NukePowerUp object in our array.
			pu := &game.nuke_power_ups[index]
			pu.alpha = 255
			pu.counter = 0
			pu.dest.x = dest.x
			pu.dest.y = dest.y
			pu.dx = dx
			pu.animation.current_frame = 0
			pu.animation.is_active = true
		}

		pu.maybe_run = proc(index: int) {
			pu := &game.nuke_power_ups[index]

			if pu.animation.current_frame > 2
			{
				pu.animation.is_active = false
			}

			if pu.animation.is_active
			{

				frame := &pu.animation.frames[pu.animation.current_frame]

				hit := collision(
					game.player.dest.x,
					game.player.dest.y,
					game.player.dest.w,
					game.player.dest.h,

					pu.dest.x,
					pu.dest.y,
					pu.dest.w,
					pu.dest.h,
					)

				if hit
				{
					pu.animation.is_active = false

					if game.player_nukes < NUM_OF_NUKES
					{
						game.player_nukes += 1
					}
				}

				frame.action(index)

				frame.timer -= TARGET_DELTA_TIME

				// reset and move to the next frame
				if frame.timer < 0
				{
					frame.timer = frame.duration
					pu.animation.current_frame += 1
				}

			}
		}


		pu.frames[0] = Frame{
			duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND) * 3,
			timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND) * 3,
			action = proc(index: int) {
				pu := &game.nuke_power_ups[index]

				pu.dest.x -= i32(get_delta_motion(pu.dx / 2))
				pu.dest.y -= i32(get_delta_motion(pu.dx / 4))

				SDL.SetTextureAlphaMod(game.nuke_power_up_tex, pu.alpha)
				SDL.RenderCopy(game.renderer, game.nuke_power_up_tex, nil, &pu.dest)
			},
		}

		pu.frames[1] = Frame{
			duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND) * 5,
			timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND) * 5,
			action = proc(index: int) {
				pu := &game.nuke_power_ups[index]

				// blinking
				if pu.counter > 15
				{
					pu.counter = 0

					if pu.alpha == 255
					{
						pu.alpha = 100
					}
					else
					{
						pu.alpha = 255
					}

				}

				pu.dest.x -= i32(get_delta_motion(pu.dx / 2))
				pu.dest.y += i32(get_delta_motion(pu.dx / 4))

				SDL.SetTextureAlphaMod(game.nuke_power_up_tex, pu.alpha)
				SDL.RenderCopy(game.renderer, game.nuke_power_up_tex, nil, &pu.dest)

				pu.counter += 1

			},
		}

		pu.frames[2] = Frame{
			duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND) * 4,
			timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND) * 4,
			action = proc(index: int) {
				pu := &game.nuke_power_ups[index]

				// blinking
				if pu.counter > 3
				{
					pu.counter = 0

					if pu.alpha == 255
					{
						pu.alpha = 100
					}
					else
					{
						pu.alpha = 255
					}

				}

				pu.dest.x += i32(get_delta_motion(pu.dx / 2))
				pu.dest.y -= i32(get_delta_motion(pu.dx / 4))

				SDL.SetTextureAlphaMod(game.nuke_power_up_tex, pu.alpha)
				SDL.RenderCopy(game.renderer, game.nuke_power_up_tex, nil, &pu.dest)

				pu.counter += 1

			},
		}

	}


}

caprintf :: proc(format: string, args: ..any) -> cstring {
    str: strings.Builder
    strings.builder_init(&str)
    fmt.sbprintf(&str, format, ..args)
    strings.write_byte(&str, 0)
    s := strings.to_string(str)
    return cstring(raw_data(s))
}

explode_nuke :: proc(n: ^NukeEntity)
{

	n.health = 0
	n.animation.is_active = false

	// find a free Explosion entity
	find_nuke_explosion : for _x in &game.nuke_explosions
	{
		if !_x.is_active
		{
			// divide by 2 so we place our explosion
			// at the center of the destroyed entity
			_x.dest.x = n.dest.x - (_x.dest.w / 2)
			_x.dest.y = n.dest.y - (_x.dest.h/ 2)
			_x.dx = n.dx // explode at the speed at which the destroyed entity was moving
			_x.is_active = true
			_x.frame = 0
			_x.frame_timer = FRAME_TIMER_NUKE_EXPLOSIONS

			break find_nuke_explosion
		}
	}


	if PLAY_SOUND do MIX.PlayChannel(-1, game.sounds[SoundId.PlayerExplosion], 0)
}

explode_player :: proc(e: ^Entity)
{
	e.health = 0
	explode(e.dest.x, e.dest.y, e.dx)

	// https://wiki.libsdl.org/SDL_mixer/Mix_PlayChannel
	// -1 => first available channel
	// Chunk
	// Loops? -1 => infinite, 0 => play once and stop
	if PLAY_SOUND do MIX.PlayChannel(-1, game.sounds[SoundId.PlayerExplosion], 0)
}

explode_drone :: proc(e: ^Entity)
{
	e.health = 0
	explode(e.dest.x, e.dest.y, e.dx)

	if PLAY_SOUND do MIX.PlayChannel(-1, game.sounds[SoundId.DroneExplosion], 0)
}

explode :: proc(x, y: i32, dx: f64)
{
	// find a free Explosion entity
	find_explosion : for _x in &game.explosions
	{
		if !_x.is_active
		{
			// divide by 2 so we place our explosion
			// at the center of the destroyed entity
			_x.dest.x = x - (_x.dest.w / 2)
			_x.dest.y = y - (_x.dest.h / 2)
			_x.dx = dx // explode at the speed at which the destroyed entity was moving
			_x.is_active = true
			_x.frame = 0
			_x.frame_timer = FRAME_TIMER_EXPLOSIONS

			break find_explosion
		}
	}
}

create_statics :: proc()
{
	// texts
	game.texts[TextId.HomeTitle] = make_text("Space Shooter", i32(4))
	game.texts[TextId.HomeSubTitle] = make_text("press space to start", i32(2))

	game.texts[TextId.DeathScreen] = make_text("Oh no!", i32(2))
	game.texts[TextId.Loading] = make_text("Loading...", i32(2))
	game.texts[TextId.ScoreLabel] = make_text("Score : ")

	chars := "0123456789"
	for c in chars[:]
	{
		str := utf8.runes_to_string([]rune{c})
		defer delete(str)

		game.chars[c] = make_text(cstring(raw_data(str)))
	}

	// Loaded Nukes
	game.loaded_nuke_tex = SDL_Image.LoadTexture(game.renderer, "assets/loaded_nuke.png")
	assert(game.loaded_nuke_tex != nil, SDL.GetErrorString())
	SDL.QueryTexture(game.loaded_nuke_tex, nil, nil, &game.loaded_nuke_dest.w, &game.loaded_nuke_dest.h)
	game.loaded_nuke_dest.w /= 2
	game.loaded_nuke_dest.h /= 2

	// Background
	stars := SDL_Image.LoadTexture(game.renderer, "assets/bg_stars_1.png")
	assert(stars != nil, SDL.GetErrorString())

	purple_nebula := SDL_Image.LoadTexture(game.renderer, "assets/bg_purple_1.png")
	assert(purple_nebula != nil, SDL.GetErrorString())

	bg_w : i32 = 1024
	bg_h : i32 = 1024

	game.background_textures[Background.PlainStars] = stars
	game.background_textures[Background.PurpleNebula] = purple_nebula

	game.background_sections[0] = BackgroundSection{background = Background.PurpleNebula, dest = SDL.Rect{x = 0, w = bg_w, h = bg_h}}
	game.background_sections[1] = BackgroundSection{background = Background.PurpleNebula, dest = SDL.Rect{x = bg_w, w = bg_w, h = bg_h}}
	game.background_sections[2] = BackgroundSection{background = Background.PurpleNebula, dest = SDL.Rect{x = bg_w * 2, w = bg_w, h = bg_h}}
	game.background_sections[3] = BackgroundSection{background = Background.PurpleNebula, dest = SDL.Rect{x = bg_w * 3, w = bg_w, h = bg_h}}

	game.background_sections[4] = BackgroundSection{background = Background.PurpleNebula, dest = SDL.Rect{x = 0, y = bg_h, w = bg_w, h = bg_h}}
	game.background_sections[5] = BackgroundSection{background = Background.PurpleNebula, dest = SDL.Rect{x = bg_w, y = bg_h, w = bg_w, h = bg_h}}
	game.background_sections[6] = BackgroundSection{background = Background.PurpleNebula, dest = SDL.Rect{x = bg_w * 2, y = bg_h, w = bg_w, h = bg_h}}
	game.background_sections[7] = BackgroundSection{background = Background.PurpleNebula, dest = SDL.Rect{x = bg_w * 3, y = bg_h, w = bg_w, h = bg_h}}


}


create_animations :: proc()
{


	// begin new stage
	// this animation should be timed according to the fade_animation
	game.begin_stage_animation = Animation{}
	a := &game.begin_stage_animation
	a.frames = make([dynamic]Frame, 3, 3)
	a.current_frame = 0
	a.is_active = false
	a.start = proc(_index: int = 0, _dest: ^SDL.Rect = nil, dx: f64 = 0, starting_frame: int = 0)
	{
		game.begin_stage_animation.current_frame = 0
		game.begin_stage_animation.is_active = true
	}
	a.maybe_run = proc(_index: int = 0)
	{

		a := &game.begin_stage_animation
		// finished animation
		if a.current_frame > (len(a.frames) - 1)
		{
			a.current_frame = 0
			a.is_active = false
		}

		// do animation
		if a.is_active
		{

			frame := &a.frames[a.current_frame]

			frame.action(_index)

			frame.timer -= TARGET_DELTA_TIME

			// reset and move to the next frame
			if frame.timer < 0
			{
				frame.timer = frame.duration
				a.current_frame += 1
			}

		}
	}

	a.frames[0] = Frame{
		duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 2),
		timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 2),
		action = proc(_index: int) {
			game.is_invincible = true
		},
	}

	a.frames[1] = Frame{
		duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 3),
		timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 3),
		action = proc(_index: int) {
			// render player and init play screen as scene fades in
			game.player.health = 1
			game.screen = Screen.Play
		},
	}

	a.frames[2] = Frame{
		duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 1),
		timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 1),
		action = proc(_index: int) {
			game.is_invincible = false
		},
	}


	// reset after death
	game.reset_animation = Animation{}
	game.reset_animation.frames = make([dynamic]Frame, 2, 2)
	game.reset_animation.current_frame = 0
	game.reset_animation.is_active = false
	game.reset_animation.start = proc(_index: int = 0, _dest: ^SDL.Rect = nil, dx: f64 = 0, starting_frame: int = 0)
	{
		game.reset_animation.current_frame = 0
		game.reset_animation.is_active = true
		game.current_score = 0

	}

	// animation will only run if active and unfinished
	game.reset_animation.maybe_run = proc(_index: int = 0)
	{
		// finished animation
		if game.reset_animation.current_frame > (len(game.reset_animation.frames) - 1)
		{
			game.reset_animation.current_frame = 0
			game.reset_animation.is_active = false
		}

		// do animation
		if game.reset_animation.is_active
		{

			frame := &game.reset_animation.frames[game.reset_animation.current_frame]

			frame.action(_index)

			frame.timer -= TARGET_DELTA_TIME

			// reset and move to the next frame
			if frame.timer < 0
			{
				frame.timer = frame.duration
				game.reset_animation.current_frame += 1
			}

		}
	}

	// init
	game.reset_animation.frames[0] = Frame{
		duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 2),
		timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 2),
		action = proc(_index: int) {
			// prevent stage reset from continuing to run b/c player health == 0
			game.is_restarting = true
			// we want the player hidden until the reset is complete
			game.player.health = 0
		},
	}

	game.reset_animation.frames[1] = Frame{
		duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 1),
		timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 1),
		action = proc(_index: int) {

			msg := game.texts[TextId.Loading]
			msg.dest.x = (WINDOW_WIDTH / 2) - (msg.dest.w / 2)
			msg.dest.y = (WINDOW_HEIGHT / 2) - (msg.dest.h / 2)
			SDL.RenderCopy(game.renderer, msg.tex, nil, &msg.dest)

			game.screen = Screen.Play
			game.is_invincible = true
			game.player.health = 1
			game.is_restarting = false

			reset_entities()
			reset_timers()
		},
	}
	// end reset_animation


	// 5 seconds total
	game.fade_animation = Animation{}
	game.fade_animation.frames = make([dynamic]Frame, 3, 3)
	game.fade_animation.current_frame = 0
	game.fade_animation.is_active = false

	game.fade_animation.start = proc(_index: int = 0, _dest: ^SDL.Rect = nil, dx: f64 = 0, starting_frame: int = 0)
	{
		game.overlay_alpha = 0
		game.fade_animation.current_frame = 0
		game.fade_animation.is_active = true
	}

	game.fade_animation.maybe_run = proc(_index: int = 0)
	{
		if game.fade_animation.current_frame > (len(game.fade_animation.frames) - 1)
		{
			game.fade_animation.current_frame = 0
			game.fade_animation.is_active = false
		}

		if game.fade_animation.is_active
		{

			frame := &game.fade_animation.frames[game.fade_animation.current_frame]

			frame.action(_index)

			SDL.SetRenderDrawBlendMode(game.renderer, SDL.BlendMode.BLEND)
			SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, game.overlay_alpha)
			SDL.RenderFillRect(game.renderer, &game.overlay)

			frame.timer -= TARGET_DELTA_TIME
			if frame.timer < 0
			{
				game.fade_animation.current_frame += 1
				frame.timer = frame.duration
			}

		}
	}

	game.fade_animation.frames[0] = Frame{
		duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 2),
		timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 2),
		action = proc(_index: int) {
			new_alpha := game.overlay_alpha + 5

			// check overflow
			if new_alpha < game.overlay_alpha
			{
				new_alpha = 255
			}

			game.overlay_alpha = new_alpha
		},
	}

	game.fade_animation.frames[1] = Frame{
		duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 1),
		timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 1),
		action = proc(_index: int) {
			game.overlay_alpha = 255
		},
	}

	game.fade_animation.frames[2] = Frame{
		duration = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 2),
		timer = (TARGET_DELTA_TIME * FRAMES_PER_SECOND * 2),
		action = proc(_index: int) {
			new_alpha := game.overlay_alpha - 5

			// check underflow
			if new_alpha > game.overlay_alpha
			{
				game.is_render_title = false
				new_alpha = 0
			}

			game.overlay_alpha = new_alpha
		},
	}

}

make_text :: proc(text: cstring, scale: i32 = 1) -> Text
{
	dest := SDL.Rect{}
	SDL_TTF.SizeText(game.font, text, &dest.w, &dest.h)
	surface := SDL_TTF.RenderText_Solid(game.font, text, COLOR_WHITE)
	defer(SDL.FreeSurface(surface))
	tex := SDL.CreateTextureFromSurface(game.renderer, surface)
	dest.w *= scale
	dest.h *= scale

	return Text{tex, dest}
}