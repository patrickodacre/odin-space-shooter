# Part 8 :: Enemies Attack!

* [YouTube Video]() - Coming Soon!
* [YouTube Channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)

In this guide we'll go through the following steps:

1. Create && Fire Drone Lasers
2. Show Entity hitboxes

## Create && Fire Drone Lasers

We'll create a fixed number of lasers for the drones to use. Much like with our own laser, a drone laser won't fire unless it is available -- `health == 0`.

We need to implement two separate timers -- one master timer, and another for each individual drone. These two timers help us control the number of drone lasers firing at the player.

We'll add a `ready` field to the `Entity` struct to control the laser fire-rate of individual drones, and the `drone_laser_cooldown` field to the `Game` struct as our master timer.

```odin

NUM_OF_DRONE_LASERS :: 5

Game :: struct
{
	/// Other stuff ^^^
	/// new
	drone_laser_tex: ^SDL.Texture,
	drone_lasers: [NUM_OF_DRONE_LASERS]Entity,
	drone_laser_cooldown : f64,
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

create_entities :: proc()
{
	/// create drones ^^

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


	///
}

```

The drone lasers aren't shaped quite like I want, so I skew the image by changing the `w` and `h` a bit to get it as close to round as I can.

### Fire Lasers

We'll allow drones to fire when within certain boundaries and the cooldown timer has expired:

```odin

if drone.dest.x > 30 &&
drone.dest.x < (WINDOW_WIDTH - 30) &&
drone.ready <= 0 &&
game.drone_laser_cooldown < 0
{
	// fire
}

```

We check this each time we render a drone.

If the drone's individual timer has expired, ie: `drone.ready < 0` then we'll look for the first available drone laser to "fire":

```odin
// find a drone laser:
fire_drone_laser : for laser, idx in &game.drone_lasers
{

	// find the first one available
	if laser.health == 0
	{
		// fire
	}
}

```

Drones need to shoot towards our player, so we'll have to calculate a `dx` and `dy` value that will lead the laser from the position of the drone to the current position of the player:

```odin
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

```

Of course, we're also careful to reset our timers.

Now, each time this active laser is rendered, it will move according to the calculated `dx` and `dy`:

```odin
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

```

## Show Entity hitboxes

To help with visualizing how our collisions are working, let's add a little utility to outline our collision areas.

We'll add a flag that will be checked at compile time:

```odin

HITBOXES_VISIBLE :: false

```

Next, we'll add this helper function to render a red rectangle at a given destination `SDL.Rect`:

```odin

render_hitbox :: proc(dest: ^SDL.Rect)
{
	r := SDL.Rect{ dest.x, dest.y, dest.w, dest.h }

	SDL.SetRenderDrawColor(game.renderer, 255, 0, 0, 255)
	SDL.RenderDrawRect(game.renderer, &r)
}

```

Now we can pass in any entity `SDL.Rect` to get an outline of their collision boundaries:

```odin

if laser.health > 0
{
	when HITBOXES_VISIBLE do render_hitbox(&laser.dest)
	SDL.RenderCopy(game.renderer, game.laser_tex, nil, &laser.dest)
}

```
