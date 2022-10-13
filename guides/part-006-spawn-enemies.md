# Part 6 :: Spawning Enemies

* [YouTube Video]()
* [YouTube Channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)
* [Odin Math Rand Documentation](https://github.com/odin-lang/Odin/blob/master/core/math/rand/rand.odin)

In this part we'll focus on spawning some enemy drones. For now, they'll have unrestricted access to the galaxy, but later on we'll be sure to change that.

The logic to spawn the enemies isn't too complicated, and it gives us an opportunity get more familiar with Odin's Math library. The Rand package will allow us to make our enemies a little more interesting.

We'll have to make some changes to our Entity struct again. The changes will allow us more fine control over how our enemy drones move.

Now let's complete the following tasks:

1. Add new constants and Game struct fields for our drones
2. Create Drones
3. Spawn Drones
4. Give Drones variable speeds

## Drone Struct Fields and Constants

It's best to follow the same ordering of the constants and Game struct fields added for our lasers. I often try to stick to conventions / ordering like this to make it easier on my eyes to read through the code.

```odin
LASER_SPEED : f64 : 700
LASER_COOLDOWN_TIMER : f64 : 50
NUM_OF_LASERS :: 100

// NEW
DRONE_SPEED : f64 : 700
DRONE_SPAWN_COOLDOWN_TIMER : f64 : 700
NUM_OF_DRONES :: 10
// END NEW

Game :: struct
{
	// ...

	laser_tex: ^SDL.Texture,
	lasers: [NUM_OF_LASERS]Entity,
	fire: bool,
	laser_cooldown : f64,

	// NEW
	drone_tex: ^SDL.Texture,
	drones: [NUM_OF_DRONES]Entity,
	drone_spawn_cooldown: f64,
	// END NEW
}

```

With these settings we limit the number of drones that may appear on the screen at the same time to 10. We also use a cooldown timer to make sure drones don't spawn too quickly. We decrement the cooldown timer using our delta multiplier.

```odin

// TIMERS
game.laser_cooldown -= get_delta_motion(LASER_SPEED)
// NEW
game.drone_spawn_cooldown -= get_delta_motion(DRONE_SPEED)
// END NEW

```

You can play around with these settings until you get the number of enemies and speeds you like. In the future, these settings can be dynamically changed based on game level changes or other events.

## Creating our Enemy Drones

In the `create_entities()` procedure we create our drones after creating our lasers. Again, we try and follow the same pattern as with creating our lasers.

```odin

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
		w = drone_w / 5, // drone image is also a bit too large
		h = drone_h / 5,
	}

	game.drones[index] = Entity{
		dest = destination,
	}
}

```

## Spawning Drones

Now that we have our fixed array of drones, we are free to spawn them. We'll spawn them on the far-right side of our window, and have them fly towards us on the left until they disappear. Our lasers are spawned once we hit the spacebar, but our drones will just spawn as soon as they become available after disappearing on the left side.

```odin
for l in &game.lasers
{
	if l.dest.x < WINDOW_WIDTH
	{
		l.dest.x += i32(get_delta_motion(LASER_SPEED))
		SDL.RenderCopy(game.renderer, game.laser_tex, nil, &l.dest)
	}
}


// NEW
// Spawn Drones
for drone, idx in &game.drones
{

	if drone.dest.x <= 0 && !(game.drone_spawn_cooldown > 0)
	{
		drone.dest.x = WINDOW_WIDTH
		drone.dest.y = i32(rand.float32_range(120, WINDOW_HEIGHT - 120))

		game.drone_spawn_cooldown = DRONE_SPAWN_COOLDOWN_TIMER
	}

	steps := i32(get_delta_motion(DRONE_SPEED))
	drone.dest.x -= steps

	if drone.dest.x > 0
	{
		SDL.RenderCopy(game.renderer, game.drone_tex, nil, &drone.dest)
	}

}

// END NEW


// TIMERS
game.laser_cooldown -= get_delta_motion(LASER_SPEED)
game.drone_spawn_cooldown -= get_delta_motion(DRONE_SPEED)

```

This is our first look at the Odin Rand library. Look above at the `rand.float32_range()` procedure call. It takes two arguments -- a `min` and a `max` value. We use it to choose a random location on the `y` plane so our drones don't all fly along the same path on our y-axis.

## Variable Drone Speeds

Having the drones all fly at the same speed isn't very interesting. Let's make each drone fly at a slightly different speed.

To accomplish this, we'll have to add some new fields to our Entity struct.

```odin

Entity :: struct
{
	dest: SDL.Rect,
	// NEW
	dx: f64,
	dy: f64,
	// END NEW
}

```

These `dx` and `dy` fields will capture the speed at which the Entity should travel.

By adding these to the Entity struct, we'll have to update our `game.player` and `lasers` to use these fields, as well. While we don't strictly need them to use these fields right now, it's nice to be consistent, and eventually we may want to dynamically manipulate their speeds, anyway.

We'll have to update code in our `create_entities()` procedure, as well as wherever we use `get_delta_motion()` to get delta movement amounts for each entity.

### Entity Creation

```odin

game.player_tex = player_texture
game.player = Entity{
	dest = destination,
	// NEW
	dx = PLAYER_SPEED,
	dy = PLAYER_SPEED,
	// END NEW
}

// ...


game.lasers[index] = Entity{
	dest = destination,
	// NEW
	dx = LASER_SPEED,
	dy = LASER_SPEED,
	// END NEW
}

// ...


// NEW
// randomize speed to make things more interesting
max := DRONE_SPEED * 1.2
min := DRONE_SPEED * 0.5
random_speed := rand.float64_range(min, max)
// END NEW

game.drones[index] = Entity{
	dest = destination,
	// NEW
	dx = random_speed,
	dy = random_speed,
	// END NEW
}

```

Here we see Odin's Rand library again. `rand.float64_range()` also takes two arguments -- a `min` and a `max` value. For now we're making the random speed multiplier the same for both horizontal and vertical movements along the `x` and `y` axes.

Of course we now have to update the code where we handle entity position changes -- the update and render portion of our game loop.

### Entity Updates

```odin
// 3. Update and Render

// update player position, etc...
// NEW -- changing our PLAYER_SPEED for the dx and dy on the player entity
delta_motion_x := get_delta_motion(game.player.dx)
delta_motion_y := get_delta_motion(game.player.dy)

if game.left
{
	// NEW
	move_player(-delta_motion_x, 0)
}

if game.right
{
	// NEW
	move_player(delta_motion_x, 0)
}

if game.up
{
	// NEW
	move_player(0, -delta_motion_y)
}

if game.down
{
	// NEW
	move_player(0, delta_motion_y)
}


// ...

for l in &game.lasers
{
	if l.dest.x < WINDOW_WIDTH
	{
		// NEW -- changing our LASER_SPEED for the l.dx setting on this single laser entity
		l.dest.x += i32(get_delta_motion(l.dx))
		SDL.RenderCopy(game.renderer, game.laser_tex, nil, &l.dest)
	}
}

// ...


// Spawn Drones
for drone, idx in &game.drones
{

	if drone.dest.x <= 0 && !(game.drone_spawn_cooldown > 0)
	{
		drone.dest.x = WINDOW_WIDTH
		drone.dest.y = i32(rand.float32_range(120, WINDOW_HEIGHT - 120))

		game.drone_spawn_cooldown = DRONE_SPAWN_COOLDOWN_TIMER
	}

	// NEW -- changing our DRONE_SPEED for the drone.dx setting on this single drone entity
	steps := i32(get_delta_motion(drone.dx))
	drone.dest.x -= steps

	if drone.dest.x > 0
	{
		SDL.RenderCopy(game.renderer, game.drone_tex, nil, &drone.dest)
	}

}

```

For now we're just moving our drones horizontally, but in future parts we'll give them a little bit of vertical movement, as well. Be sure to keep an eye on [this series]() to catch that update!

## Suggested Challenges

In the next part we'll give our player the ability to destroy these drones -- they've been terrorizing the galaxy for far too long!

See if you can figure out the basic collision detection needed to make that happen.

If you get something working, share it in the comments beneath this [video]()!
