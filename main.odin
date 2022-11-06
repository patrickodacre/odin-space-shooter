package game
// our package name. We call this 'main' but this name could be anything you want.

// import core and vendor packages
import "core:fmt"
import SDL "vendor:sdl2"
import SDL_Image "vendor:sdl2/image"
import "core:math/rand"
import "core:strings"

// constants
WINDOW_FLAGS :: SDL.WINDOW_SHOWN
RENDER_FLAGS :: SDL.RENDERER_ACCELERATED
TARGET_DELTA_TIME :: f64(1000) / f64(60)
WINDOW_WIDTH :: 1600
WINDOW_HEIGHT :: 960
HITBOXES_VISIBLE :: false


PLAYER_SPEED : f64 : 500 // pixels per second
LASER_SPEED : f64 : 700
LASER_COOLDOWN_TIMER : f64 : 50
NUM_OF_LASERS :: 100

DRONE_SPEED : f64 : 700
DRONE_SPAWN_COOLDOWN_TIMER : f64 : 700
NUM_OF_DRONES :: 10
NUM_OF_DRONE_LASERS :: 5
DRONE_LASER_SPEED : f64 : 200
DRONE_LASER_COOLDOWN : f64 : 1000
DRONE_LASER_COOLDOWN_MASTER : f64 : 300 // stagger lasers a bit

STAGE_RESET_TIMER : f64 : TARGET_DELTA_TIME * 60 * 3 // 3 seconds

FRAME_TIMER : f64 : 50

Game :: struct
{
	stage_reset_timer: f64,
	perf_frequency: f64,
	renderer: ^SDL.Renderer,

	// background
	bg_tex: ^SDL.Texture,
	bg_1: Background,
	bg_2: Background,
	bg_3: Background,
	bg_4: Background,
	bg_5: Background,
	bg_6: Background,

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
}

Background :: struct
{
	dest: SDL.Rect,
	dx: f64,
}

Explosion :: struct
{
	source: SDL.Rect,
	dest: SDL.Rect,
	dx: f64,
	frame: int,
	frame_timer: f64,
	is_active: bool,
}

Entity :: struct
{
	dest: SDL.Rect,
	dx: f64,
	dy: f64,
	health : int,
	ready: f64,
}

game := Game{}

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
						fmt.println("Log")
						fmt.println(game.effect_explosion_frames[0])
						fmt.println(game.explosions)
					case .C:
						game.bg_tex = SDL_Image.LoadTexture(game.renderer, "assets/bg_stars_1.png")
				}

			}
		}


		// 3. Update and Render

		// BGs are 1024, and our WINDOW_WIDTH is 1600. I use 3 bgs
		// to make sure that we're always filling the screen
		// BACKGROUND -- must be first so everything else is on TOP
		if (game.bg_1.dest.x + game.bg_1.dest.w < 0)
		{
			game.bg_1.dest.x = game.bg_3.dest.x + game.bg_3.dest.w
			game.bg_4.dest.x = game.bg_6.dest.x + game.bg_6.dest.w
		}

		if (game.bg_2.dest.x + game.bg_2.dest.w < 0)
		{
			game.bg_2.dest.x = game.bg_1.dest.x + game.bg_1.dest.w
			game.bg_5.dest.x = game.bg_4.dest.x + game.bg_4.dest.w
		}

		if (game.bg_3.dest.x + game.bg_3.dest.w < 0)
		{
			game.bg_3.dest.x = game.bg_2.dest.x + game.bg_2.dest.w
			game.bg_6.dest.x = game.bg_3.dest.x + game.bg_3.dest.w
		}

		game.bg_1.dest.x -= i32(get_delta_motion(200))
		SDL.RenderCopy(game.renderer, game.bg_tex, nil, &game.bg_1.dest)
		game.bg_2.dest.x -= i32(get_delta_motion(200))
		SDL.RenderCopy(game.renderer, game.bg_tex, nil, &game.bg_2.dest)
		game.bg_3.dest.x -= i32(get_delta_motion(200))
		SDL.RenderCopy(game.renderer, game.bg_tex, nil, &game.bg_3.dest)
		game.bg_4.dest.x -= i32(get_delta_motion(200))
		SDL.RenderCopy(game.renderer, game.bg_tex, nil, &game.bg_4.dest)
		game.bg_5.dest.x -= i32(get_delta_motion(200))
		SDL.RenderCopy(game.renderer, game.bg_tex, nil, &game.bg_5.dest)
		game.bg_6.dest.x -= i32(get_delta_motion(200))
		SDL.RenderCopy(game.renderer, game.bg_tex, nil, &game.bg_6.dest)



		// Based on the positions that are currently visible to the Player...
		// 1. Check Collisions
		// 2. Move any entities that survive
		// 3. Reset any entities that are offscreen
		// 4. Render onscreen entities
		// 5. Fire new lasers
		// 6. Respawn new drones

		// Player Lasers -- check collisions -> render
		for laser in &game.lasers
		{
			// laser offscreen or not fired
			if laser.health == 0
			{
				continue
			}

			// check collision based on previous frame's rendered position
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

				if hit
				{

					drone.health = 0
					laser.health = 0

			    	explode(&drone)

					break detect_collision
				}
			}

			laser.dest.x += i32(get_delta_motion(laser.dx))

			// reset laser if it's offscreen
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
			hit := collision(
				game.player.dest.x,
				game.player.dest.y,
				game.player.dest.w,
				game.player.dest.h,
				laser.dest.x + 12,
				laser.dest.y + 10,
				laser.dest.w / 2,
				laser.dest.h / 2,
				)

			if hit
			{
				laser.health = 0
				game.player.health = 0

		    	explode(&game.player)
			}

			laser.dest.x += i32(get_delta_motion(laser.dx))
			laser.dest.y += i32(get_delta_motion(laser.dy))

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
				source := SDL.Rect{54, 28, 62, 28}
				SDL.RenderCopy(game.renderer, game.drone_laser_tex, &source, &laser.dest)
			}

		}


		// At this point we've checked our collisions
		// and we've figured out our active Player Lasers,
		// Drones, and Drone Lasers.

		// render active drones and fire new lasers
		for drone in &game.drones
		{

			if drone.health == 0
			{
				continue
			}

			drone.dest.x -= i32(get_delta_motion(drone.dx))

			if drone.dest.x < 0
			{
				drone.health = 0

				// don't fire a laser
				// from a drone that isn't rendered
				continue
			}

			SDL.RenderCopy(game.renderer, game.drone_tex, nil, &drone.dest)

			// for each active drone, fire a laser if cooldown time reached
			// and the drone isn't moving offscreen
			// without this 300 pixel buffer, it looks like lasers
			// are coming from offscreen
			if drone.dest.x > 300 &&
			drone.dest.x < (WINDOW_WIDTH - 300) &&
			drone.ready < 0 &&
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

						laser.dx = new_dx * DRONE_LASER_SPEED
						laser.dy = new_dy * DRONE_LASER_SPEED

						// reset the cooldown to prevent firing too rapidly
						drone.ready = DRONE_LASER_COOLDOWN
						game.drone_laser_cooldown = DRONE_LASER_COOLDOWN_MASTER

						break fire_drone_laser
					}
				}
			}

			// decrement our 'ready' timer
			// to help distribute lasers more evenly between
			// the active drones
			// w/o 'ready' one drone could end up firing all the lasers
			drone.ready -= get_delta_motion(drone.dx)
		}

		// update player position AFTER we detect any collisions with drone lasers
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
		// x := game.explosions[0]
		// t := game.effect_explosion_frames[x.frame]
		// fmt.println(x.dest)
		// SDL.RenderCopy(game.renderer, t, nil, &x.dest)

		for x in &game.explosions
		{
			if x.frame > 10
			{
				x.is_active = false
			}

			if x.is_active
			{

				t := game.effect_explosion_frames[x.frame]
				x.dest.x -= i32(get_delta_motion(x.dx)) / 3
				SDL.RenderCopy(game.renderer, t, nil, &x.dest)

				x.frame_timer -= 10

				// switch frames
				if x.frame_timer < 0
				{
					// restart timer
					x.frame_timer = FRAME_TIMER
					x.frame += 1
				}
			}

		}

		// FIRE PLAYER LASERS
		// NOTE :: firing new lasers AFTER
		// Collisions have been detected; otherwise,
		// collisions may be true for lasers that aren't rendered, yet.
		// BUT this means rendering of new lasers is delayed by one frame.
		// Is this the best way?
		if game.fire &&
		game.player.health > 0 &&
		!(game.laser_cooldown > 0)
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

					break fire
				}
			}
		}

		// Spawn Drones
		respawn : for drone, idx in &game.drones
		{

			if drone.health == 0 && !(game.drone_spawn_cooldown > 0)
			{
				drone.dest.x = WINDOW_WIDTH
				drone.dest.y = i32(rand.float32_range(120, WINDOW_HEIGHT - 120))
				drone.health = 1

				game.drone_spawn_cooldown = DRONE_SPAWN_COOLDOWN_TIMER

				break respawn
			}
		}


		// TIMERS
		game.laser_cooldown -= get_delta_motion(LASER_SPEED)
		game.drone_spawn_cooldown -= get_delta_motion(DRONE_SPEED)
		game.drone_laser_cooldown -= get_delta_motion(DRONE_SPEED)

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

get_delta_motion :: proc(speed: f64) -> f64
{
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

	// ensures values 0.5 -> 0.9 will be truncated to 1 AND
	// ensures values -0.5 -> -0.9 will be truncated to -1
	// when we convert to i32 for rendering.
	// this means drone laser paths will be angled better towards
	// the player position at the time of firing their laser
	new_dx = new_dx > 0 ? new_dx + 0.5 : new_dx - 0.5
	new_dy = new_dy > 0 ? new_dy + 0.5 : new_dy - 0.5

	return new_dx, new_dy
}

reset_stage :: proc()
{
	create_entities()

	game.laser_cooldown = LASER_COOLDOWN_TIMER
	game.drone_spawn_cooldown = DRONE_SPAWN_COOLDOWN_TIMER
	game.drone_laser_cooldown = DRONE_LASER_COOLDOWN_MASTER

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
			health = 0,
			dx = LASER_SPEED,
			dy = LASER_SPEED,
		}
	}


	// drones
	drone_texture := SDL_Image.LoadTexture(game.renderer, "assets/drone_1.png")
	assert(drone_texture != nil, SDL.GetErrorString())
	drone_w : i32
	drone_h : i32
	SDL.QueryTexture(drone_texture, nil, nil, &drone_w, &drone_h)

	game.drone_tex = drone_texture

	for index in 0..=(NUM_OF_DRONES - 1)
	{
		destination := SDL.Rect{
			x = -(drone_w),
			y = 0,
			w = drone_w / 5,
			h = drone_h / 5,
		}

		// randomize speed to make things more interesting
		max := DRONE_SPEED * 1.2
		min := DRONE_SPEED * 0.5
		random_speed := rand.float64_range(min, max)

		game.drones[index] = Entity{
			dest = destination,
			health = 0,
			dx = random_speed,
			dy = random_speed,
			ready = DRONE_LASER_COOLDOWN,
		}
	}

	// drone lasers
	game.drone_laser_tex = SDL_Image.LoadTexture(game.renderer, "assets/drone_laser_1.png")
	assert(game.drone_laser_tex != nil, SDL.GetErrorString())
	drone_laser_w : i32
	drone_laser_h : i32
	SDL.QueryTexture(game.drone_laser_tex, nil, nil, &drone_laser_w, &drone_laser_h)

	for _, idx in 1..=NUM_OF_DRONE_LASERS
	{

		game.drone_lasers[idx] = Entity{
			dest = SDL.Rect{
				x = -100,
				y = -100,
				w = drone_laser_w / 8,
				h = drone_laser_h / 6,
			},
			dx = DRONE_LASER_SPEED,
			dy = DRONE_LASER_SPEED,
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
			source = SDL.Rect{
				// 178 / 272
				x = 178,
				y = 178,
				w = 100,
				h = 100,
			},
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
	game.bg_tex = SDL_Image.LoadTexture(game.renderer, "assets/bg_purple_1.png")
	assert(game.bg_tex != nil, SDL.GetErrorString())
	bg_w : i32
	bg_h : i32
	SDL.QueryTexture(game.bg_tex, nil, nil, &bg_w, &bg_h)

	game.bg_1 = Background{
		dest = SDL.Rect{
			x = 0,
			w = bg_w,
			h = bg_h,
		}
	}

	game.bg_2 = Background{
		dest = SDL.Rect{
			x = bg_w,
			w = bg_w,
			h = bg_h,
		}
	}

	game.bg_3 = Background{
		dest = SDL.Rect{
			x = bg_w * 2,
			w = bg_w,
			h = bg_h,
		}
	}

	game.bg_4 = Background{
		dest = SDL.Rect{
			x = 0,
			y = bg_h,
			w = bg_w,
			h = bg_h,
		}
	}

	game.bg_5 = Background{
		dest = SDL.Rect{
			x = bg_w,
			y = bg_h,
			w = bg_w,
			h = bg_h,
		}
	}

	game.bg_6 = Background{
		dest = SDL.Rect{
			x = bg_w * 2,
			y = bg_h,
			w = bg_w,
			h = bg_h,
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

explode :: proc(e: ^Entity)
{
	// find a free Explosion entity
	find_explosion : for x in &game.explosions
	{
		if !x.is_active
		{
			x.dest.x = e.dest.x - (x.dest.w / 2)
			x.dest.y = e.dest.y - (x.dest.h / 2)
			x.dx = e.dx
			x.is_active = true
			x.frame = 0
			x.frame_timer = FRAME_TIMER

			break find_explosion
		}
	}


}