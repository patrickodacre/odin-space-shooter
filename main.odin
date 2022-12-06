package game

import "core:fmt"
import SDL "vendor:sdl2"
import SDL_Image "vendor:sdl2/image"
import "core:math/rand"
import "core:strings"

WINDOW_FLAGS :: SDL.WINDOW_SHOWN | SDL.WINDOW_RESIZABLE
RENDER_FLAGS :: SDL.RENDERER_ACCELERATED
FRAMES_PER_SECOND : f64 : 60
TARGET_DELTA_TIME :: f64(1000) / FRAMES_PER_SECOND
WINDOW_WIDTH :: 1600
WINDOW_HEIGHT :: 960
HITBOXES_VISIBLE :: false

BACKGROUND_SPEED :: 300

PLAYER_SPEED : f64 : 250 // pixels per second
LASER_SPEED : f64 : 500
LASER_COOLDOWN_TIMER : f64 : TARGET_DELTA_TIME * (FRAMES_PER_SECOND / 2) // 1/2 second
NUM_OF_LASERS :: 100

DRONE_SPAWN_COOLDOWN_TIMER : f64 : TARGET_DELTA_TIME * FRAMES_PER_SECOND * 1 // 1 sec
NUM_OF_DRONES :: 5

DRONE_LASER_COOLDOWN_TIMER_SINGLE : f64 : TARGET_DELTA_TIME * (FRAMES_PER_SECOND * 2)
DRONE_LASER_COOLDOWN_TIMER_ALL : f64 : TARGET_DELTA_TIME * 5
NUM_OF_DRONE_LASERS :: 2

STAGE_RESET_TIMER : f64 : TARGET_DELTA_TIME * FRAMES_PER_SECOND * 3 // 3 seconds

// each frame of an explosion is rendered for X frames
FRAME_TIMER_EXPLOSIONS : f64 : TARGET_DELTA_TIME * 4

OVERLAY_TIMER: f64 : TARGET_DELTA_TIME * FRAMES_PER_SECOND * 2

Game :: struct
{
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
	explosions: [NUM_OF_DRONES * 2]Explosion,

	background_textures: [Background]^SDL.Texture,
	background_sections: [8]BackgroundSection,

	overlay: SDL.Rect,
	overlay_alpha: u8,

	overlay_active: bool,
	overlay_frame: int,
	overlay_timer: f64,
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

Explosion :: struct
{
	dest: SDL.Rect,
	dx: f64,
	frame: int,
	frame_timer: f64,
	is_active: bool,
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
	overlay = SDL.Rect{0, 0, WINDOW_WIDTH, WINDOW_HEIGHT},
	overlay_active = false,
	overlay_frame = 1,
	overlay_timer = OVERLAY_TIMER,
	overlay_alpha = 0,
	is_invincible = false,
}

// a proc (procedure) would be a 'function' in another language.
main :: proc()
{
	assert(SDL.Init(SDL.INIT_VIDEO) == 0, SDL.GetErrorString())
	assert(SDL_Image.Init(SDL_Image.INIT_PNG) != nil, SDL.GetErrorString())
	defer SDL.Quit()

	window := SDL.CreateWindow(
		"Odin Space Shooter",
		SDL.WINDOWPOS_CENTERED,
		SDL.WINDOWPOS_CENTERED,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		WINDOW_FLAGS
	)
	assert(window != nil, SDL.GetErrorString())
	defer SDL.DestroyWindow(window)

	game.renderer = SDL.CreateRenderer(window, -1, RENDER_FLAGS)
	assert(game.renderer != nil, SDL.GetErrorString())
	defer SDL.DestroyRenderer(game.renderer)

	SDL.RenderSetLogicalSize(game.renderer, WINDOW_WIDTH, WINDOW_HEIGHT)

	reset_stage()

	game.perf_frequency = f64(SDL.GetPerformanceFrequency())
	start : f64
	end : f64

	event : SDL.Event
	state : [^]u8

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
					case .P:
						game.is_paused = ! game.is_paused
					case .F:
						game.overlay_active = true
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
			SDL.RenderCopy(game.renderer, tex, nil, &section.dest)

		}

		// Based on the positions that are currently visible to the Player...
		// 1. Check Collisions
		// 2. Move any entities that survive
		// 3. Reset any entities that are offscreen
		// 4. Render onscreen entities
		// 5. Fire new lasers + render
		// 6. Respawn new drones + render

		// Player Lasers -- check collisions -> render
		for laser in &game.lasers
		{

			if laser.health == 0
			{
				continue
			}

			detect_collision : for drone in &game.drones
			{
				if drone.health == 0
				{
					continue
				}

				hit := collision(
					laser.dest.x,
					laser.dest.y,
					laser.dest.w,
					laser.dest.h,

					drone.dest.x,
					drone.dest.y,
					drone.dest.w,
					drone.dest.h
					)

				if hit && !game.is_invincible
				{

					drone.health = 0
					laser.health = 0

			    	explode(&drone)

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

		// Drone Lasers -- check collisions -> render
		for laser, idx in &game.drone_lasers
		{

			if laser.health == 0
			{
				continue
			}

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

				if hit && !game.is_invincible
				{
					laser.health = 0
					game.player.health = 0

			    	explode(&game.player)
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

			if drone.health == 0
			{
				continue
			}

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
						drone.dest.h
						)

					if hit && !game.is_invincible
					{

						drone.health = 0
						game.player.health = 0

				    	explode(&drone)
				    	explode(&game.player)

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
								game.player.dest.y
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

			// FIRE PLAYER LASERS
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

						break fire
					}
				}
			}

		}

		// Player Dead
		if game.player.health == 0
		{
			game.stage_reset_timer -= TARGET_DELTA_TIME

			if game.stage_reset_timer < 0
			{
				reset_stage()
			}
		}

		// Explosions
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

		// Fade Overlay
		if game.overlay_frame > 3
		{
			game.overlay_active = false
			game.overlay_frame = 1
			game.overlay_timer = OVERLAY_TIMER
			game.is_invincible = false
		}

		if game.overlay_active
		{
			game.is_invincible = true
			// fade out
			if game.overlay_frame == 1
			{
				new_alpha := game.overlay_alpha + 5

				// overflow
				if new_alpha < game.overlay_alpha
				{
					new_alpha = 255
				}

				game.overlay_alpha = new_alpha
			}

			// pause
			if game.overlay_frame == 2
			{
				game.overlay_alpha = 255
			}

			// fade in
			if game.overlay_frame == 3
			{
				new_alpha := game.overlay_alpha - 5

				// underflow
				if new_alpha > game.overlay_alpha
				{
					new_alpha = 0
				}

				game.overlay_alpha = new_alpha
			}


			SDL.SetRenderDrawBlendMode(game.renderer, SDL.BlendMode.BLEND)
			SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, game.overlay_alpha)
			SDL.RenderFillRect(game.renderer, &game.overlay)

			game.overlay_timer -= TARGET_DELTA_TIME

			if game.overlay_timer < 0
			{
				game.overlay_timer = OVERLAY_TIMER
				game.overlay_frame += 1
			}
		}





		// TIMERS
		game.laser_cooldown -= TARGET_DELTA_TIME
		game.drone_spawn_cooldown -= TARGET_DELTA_TIME
		game.drone_laser_cooldown -= TARGET_DELTA_TIME

		// ... end LOOP code



		// spin lock to hit our framerate
		end = get_time()
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
		SDL.SetRenderDrawColor(game.renderer, 0, 0, 0, 100)

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

	SDL.SetRenderDrawColor(game.renderer, 255, 0, 0, 100)
	SDL.RenderDrawRect(game.renderer, &r)
}

collision :: proc(x1, y1, w1, h1, x2, y2, w2, h2: i32) -> bool
{
	return (max(x1, x2) < min(x1 + w1, x2 + w2)) && (max(y1, y2) < min(y1 + h1, y2 + h2))
}

reset_stage :: proc()
{
	create_entities()

	game.laser_cooldown = LASER_COOLDOWN_TIMER
	game.drone_spawn_cooldown = DRONE_SPAWN_COOLDOWN_TIMER
	game.drone_laser_cooldown = DRONE_LASER_COOLDOWN_TIMER_ALL

	game.stage_reset_timer = STAGE_RESET_TIMER
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
		random_speed := rand.float64_range(BACKGROUND_SPEED + 50, BACKGROUND_SPEED + 200)

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

caprintf :: proc(format: string, args: ..any) -> cstring {
    str: strings.Builder
    strings.builder_init(&str)
    fmt.sbprintf(&str, format, ..args)
    strings.write_byte(&str, 0)
    s := strings.to_string(str)
    return cstring(raw_data(s))
}

explode :: proc(e: ^Entity)
{
	// find a free Explosion entity
	find_explosion : for x in &game.explosions
	{
		if !x.is_active
		{
			// divide by 2 so we place our explosion
			// at the center of the destroyed entity
			x.dest.x = e.dest.x - (x.dest.w / 2)
			x.dest.y = e.dest.y - (x.dest.h / 2)
			x.dx = e.dx // explode at the speed at which the destroyed entity was moving
			x.is_active = true
			x.frame = 0
			x.frame_timer = FRAME_TIMER_EXPLOSIONS

			break find_explosion
		}
	}


}
