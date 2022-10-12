package game
// our package name. We call this 'main' but this name could be anything you want.

// import core and vendor packages
import "core:fmt"
import SDL "vendor:sdl2"
import SDL_Image "vendor:sdl2/image"

// constants
WINDOW_FLAGS :: SDL.WINDOW_SHOWN
RENDER_FLAGS :: SDL.RENDERER_ACCELERATED
TARGET_DELTA_TIME :: f64(1000) / f64(60)
WINDOW_WIDTH :: 1600
WINDOW_HEIGHT :: 960
PLAYER_SPEED : f64 : 500 // pixels per second
LASER_SPEED : f64 : 700
LASER_COOLDOWN_TIMER : f64 : 50
NUM_OF_LASERS :: 100

Game :: struct
{
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
}

Entity :: struct
{
	dest: SDL.Rect,
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

	// Must not do VSync because we run the tick loop on the same thread as rendering.
	game.renderer = SDL.CreateRenderer(window, -1, RENDER_FLAGS)
	assert(game.renderer != nil, SDL.GetErrorString())
	defer SDL.DestroyRenderer(game.renderer)

	create_entities()

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
				}

			}
		}


		// 3. Update and Render

		// update player position, etc...
		delta_motion := get_delta_motion(PLAYER_SPEED)

		if game.left
		{
			move_player(-delta_motion, 0)
		}

		if game.right
		{
			move_player(delta_motion, 0)
		}

		if game.up
		{
			move_player(0, -delta_motion)
		}

		if game.down
		{
			move_player(0, delta_motion)
		}

		// then render the updated entity:
		SDL.RenderCopy(game.renderer, game.player_tex, nil, &game.player.dest)


		// FIRE LASERS
		if game.fire && !(game.laser_cooldown > 0)
		{
			// find a laser:
			reload : for l in &game.lasers
			{
				// find the first one available
				if l.dest.x > WINDOW_WIDTH
				{

					l.dest.x = game.player.dest.x + 20
					l.dest.y = game.player.dest.y
					// reset the cooldown to prevent firing too rapidly
					game.laser_cooldown = LASER_COOLDOWN_TIMER

					break reload
				}
			}
		}

		for l in &game.lasers
		{
			if l.dest.x < WINDOW_WIDTH
			{
				l.dest.x += i32(get_delta_motion(LASER_SPEED))
				SDL.RenderCopy(game.renderer, game.laser_tex, nil, &l.dest)
			}
		}


		// decrement our cooldown
		game.laser_cooldown -= LASER_SPEED * (TARGET_DELTA_TIME / 1000)

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
	}

	laser_texture := SDL_Image.LoadTexture(game.renderer, "assets/bullet_red_2.png")
	assert(laser_texture != nil, SDL.GetErrorString())
	laser_w : i32
	laser_h :i32
	SDL.QueryTexture(laser_texture, nil, nil, &laser_w, &laser_h)

	game.laser_tex = laser_texture

	for index in 0..=(NUM_OF_LASERS-1)
	{
		destination := SDL.Rect{
			x = WINDOW_WIDTH + 20, // offscreen means available to fire
			w = laser_w / 3,
			h = laser_h / 3,
		}

		game.lasers[index] = Entity{
			dest = destination,
		}
	}

}

