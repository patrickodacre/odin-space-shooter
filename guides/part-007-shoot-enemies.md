# Part 7 :: Shooting Drones

* [YouTube Video]() - Coming Soon!
* [YouTube Channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)

Shooting drones involves these 4 steps:

1. Fire Laser
2. Respawn Drones
3. Iterate Lasers -- Detect Collisions, Move, and Render
4. Iterate Drones -- Move and Render

While the collision detection code is what decides what has been hit, I found I had to complete these 4 steps in the proper way to make the collision detection work as I expected.

I was careful to move entities only AFTER collision detection is completed. If collisions are checked against positions not yet rendered, then it looks like the drones are being destroyed too early. In other words, I based my collisions on the positions last visible to the player.

## Fire Laser

We finished this portion of the code in a previous part of the series.

Firing a laser means resetting its position from RIGHT offscreen to the player's position, so it will be rendered in a straight path from this new starting position.

```odin

// FIRE LASERS
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

			break fire
		}
	}
}

```

## Respawn Drones

This was also completed in a previous part of the series.

Spawning a drone means resettings its position from the LEFT offscreen to the RIGHT where it can begin a new flight path moving towards the LEFT again.

```odin

// Spawn Drones
respawn : for drone in &game.drones
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

```

Once we fire our weapon and respawn drones, we need to move onto updating laser and drone positions.

## Iterate Lasers -- Detect Collisions, Move, and Render

For every laser in flight we need to check each active drone to see if their positions overlap. If their positions overlap, then we know the laser has hit the drone. For now we'll consider a single hit a kill shot, but later we can experiment with multiple hits.

Our collision detection looks like this:

```odin

collision :: proc(x1, y1, w1, h1, x2, y2, w2, h2: i32) -> bool
{
	return (max(x1, x2) < min(x1 + w1, x2 + w2)) && (max(y1, y2) < min(y1 + h1, y2 + h2))
}

```

We're checking the dimensions of 2 rectangles to see if any portion overlaps. If there is an overlap, then we have a collision.

```odin

// Check collisions and render lasers
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

		if hit
		{

			drone.health = 0
			laser.health = 0

			break detect_collision
		}

	}

	if laser.health > 0
	{
		laser.dest.x += i32(get_delta_motion(laser.dx))
		SDL.RenderCopy(game.renderer, game.laser_tex, nil, &laser.dest)
	}

}

```

If our laser doesn't collide with any drone, we can move and render the laser.

## Iterate Drones -- Move and Render

As before, all surviving drones are moved and rendered in a single step.

```odin

for drone in &game.drones
{

	if drone.health > 0
	{
		drone.dest.x -= i32(get_delta_motion(drone.dx))
		SDL.RenderCopy(game.renderer, game.drone_tex, nil, &drone.dest)
	}

}

```

## Challenges

1. Implement more interesting flight behavior for the drones.
2. Only destroy drones once they've been hit numerous times.
