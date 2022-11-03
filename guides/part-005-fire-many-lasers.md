# Part 5 :: Firing Many Lasers

* [YouTube Video](https://youtu.be/lw2lde4xN9w)
* [YouTube Channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)

We left Part 4 with a challenge to discover a way to fire more than one laser. If you haven't yet attempted this update, please do so before going through Part 5.

In this part we'll cover how to fire many lasers.

1. Some Simple Upkeep
2. Store a finite number of lasers in a fixed array.
3. Reload our laser cannon once a laser goes offscreen.
4. Balance laser speed with the number of lasers so we always have plenty of ammo.

## Some Basic Upkeep

Before we get started I want to highlight some minor fixes made to the code.

### Fixing Our Frame Rate

Previously we calculated our `TARGET_DELTA_TIME` like so:

```odin

TARGET_DELTA_TIME :: 1000 / 60

```

This constant defaulted to a `int` type, and so our target frame rate was truncated to 16 milliseconds. That resulted in an FPS of 62 frames per second. That was a mistake.

Rather, the code to calculate our target delta time should have been:

```odin

TARGET_DELTA_TIME :: f64(1000) / f64(60)

```

This would give us an `f64` and an accurate frame time of 16.667 milliseconds, which would give us our desired 60 FPS.

Our new `get_delta_motion()` procedure would then have to be updated:

```odin

get_delta_motion :: proc(speed: f64) -> f64
{
	return speed * (TARGET_DELTA_TIME / 1000)
}

```

## A Fixed Array of Lasers

To keep tight control over the number of lasers we have to keep track of, we'll start with using a fixed array.

```odin

NUM_OF_LASERS :: 100

Game :: struct
{
	// ...

	lasers: [NUM_OF_LASERS]Entity,

	// ...
}

```

Adjusting the laser limit and the laser speed will take some trial and error to ensure the player never feels like they don't have enough lasers. In other words, we want to make sure lasers reach the end of the screen and replenish quickly enough so we rarely meet the end of our laser supply.

We'll create our lasers at game startup, filling in our array with our now-simplified entities.

```odin

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

```

Notice the changes to the `Game` struct and the `Entity` struct:

```odin

Game :: struct
{
	perf_frequency: f64,
	renderer: ^SDL.Renderer,

	// player
	player: Entity,
	player_tex: ^SDL.Texture, // NEW
	left: bool,
	right: bool,
	up: bool,
	down: bool,


	laser_tex: ^SDL.Texture, // NEW
	lasers: [NUM_OF_LASERS]Entity, // NEW
	fire: bool,
	laser_cooldown : f64, // NEW
}

Entity :: struct
{
	dest: SDL.Rect,
}

```

`laser_tex` and `player_tex` are added to the `Game` struct and the `tex` fields are removed from the `Entity` struct.

Why?

We're creating 100 lasers, and there is no need to create 100 textures -- only one texture is needed.

We also removed our `health` field from the `Entity` struct. We can track laser lifetimes by checking their `x` position.

## Reloading our Laser Cannon

Each time a player "fires" a laser we need to iterate through our array of lasers and find the first one whose `x` position is greater than the width of the window, i.e.: is offscreen. That one laser that is offscreen is then "reloaded" by having its `x` and `y` position reset.

## Choosing the Right NUM_OF_LASERS, LASER_SPEED, and LASER_COOLDOWN_TIMER

We have 100 lasers available to us, and our laser cooldown timer counts down each frame by an amount relative to the frame rate and the LASER_SPEED. With the timer set to `50`, a laser will move approximately 50 pixels before another can be fired.

```odin

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

```

Our cooldown timer is reset each time we fire a laser. We cannot fire a laser until our cooldown timer goes below ZERO.

With the settings we have right now I don't feel like we run out of ammunition too quickly, but you should feel free to change these settings to match your tastes.

## Suggested Challenges

In the next part we'll cover adding enemies to the window. By now you should understand how to render images to the screen, so you should try adding a few enemies that our player must battle.


Good luck!
