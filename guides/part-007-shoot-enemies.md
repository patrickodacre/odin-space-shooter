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

While the collision detection code is what decides what has been hit, you must complete these 4 steps in the proper way to make the collision detection work as you expect.

One important point I want to make right now -- entities move only AFTER collision detection is completed. If collisions are checked against positions not yet rendered, then it looks like the drones are being destroyed too early. In other words, collision must be based on the positions last visible to the player.

Be careful to update positions and render at the proper time to get everything working smoothly.

## Fire Laser

We finished this portion of the code in a previous part of the series.

Firing a laser means resetting its position from RIGHT offscreen to the player's position, so it will be rendered in a straight path from this new starting position.

```odin

// FIRE LASERS
if game.fire && !(game.laser_cooldown > 0)
{
	// find a laser:
	fire : for l in &game.lasers
	{
		// find the first one available
		if l.dest.x > WINDOW_WIDTH
		{

			l.dest.x = game.player.dest.x + 20
			l.dest.y = game.player.dest.y
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

	if drone.dest.x <= 0 && !(game.drone_spawn_cooldown > 0)
	{
		drone.dest.x = WINDOW_WIDTH
		drone.dest.y = i32(rand.float32_range(120, WINDOW_HEIGHT - 120))

		game.drone_spawn_cooldown = DRONE_SPAWN_COOLDOWN_TIMER

		break respawn
	}
}

```

Once we fire our weapon and respawn drones, we need to move onto updating laser and drone positions.

## Iterate Lasers -- Detect Collisions, Move, and Render

For every laser in flight we need to check each active drone to see if their positions overlap. If their positions overlap, then we know the laser has hit the drone. For now we'll consider a single hit a kill shot, but later we can experiment with multiple hits.

```odin

// Check collisions and render lasers
for l in &game.lasers
{
	// lasers offscreen to the RIGHT are no longer in flight
	if l.dest.x > WINDOW_WIDTH
	{
		continue
	}

	bounds_y_top := l.dest.y
	bounds_y_bottom := l.dest.y + l.dest.h
	bounds_x_right := l.dest.x + l.dest.w

	detect_collision : for drone in &game.drones
	{

		// drones offscreen to the LEFT are no longer in flight
		if drone.dest.x < 0
		{
			continue
		}

		// drone is hit if
		// (direct hit OR
		// top of drone is hit OR
		// bottom of drone is hit)
		// AND
		// the front of the drone overlaps
		// with the front 30 pixels of the laser
		if ((drone.dest.y >= bounds_y_top &&
			drone.dest.y <= bounds_y_bottom) ||
			(drone.dest.y + drone.dest.h >= bounds_y_top &&
			drone.dest.y + drone.dest.h <= bounds_y_bottom)) &&
			drone.dest.x <= bounds_x_right &&
			drone.dest.x >= bounds_x_right - 30
		{
			// kill drone
			drone.dest.x = -1000
			drone.dest.y = -1000

			// kill laser
			l.dest.x = WINDOW_WIDTH + 1000

			break detect_collision
		}

	}

	l.dest.x += i32(get_delta_motion(l.dx))
	SDL.RenderCopy(game.renderer, game.laser_tex, nil, &l.dest)
}

```

A drone is destroyed when:

* there is a direct impact along the y-axis OR
* the top is hit by the laser OR
* the bottom is hit by the laser

AND

* the front of the drone hits the front half of the laser.

Why the **front half** of the laser?

If we do a check for exact equality of `laser.dest.x` == `drone.dest.x`, our collision check will likely fail and lasers will appear to pass through drones. Using a range means our collision checks will be more accurate.

If our laser doesn't collide with any drone, we can move and render the laser.

## Iterate Drones -- Move and Render

As before, all surviving drones are moved and rendered in a single step.

```odin

for drone in &game.drones
{

	if drone.dest.x > 0
	{
		drone.dest.x -= i32(get_delta_motion(drone.dx))
		SDL.RenderCopy(game.renderer, game.drone_tex, nil, &drone.dest)
	}

}

```

## Challenges

1. Implement more interesting flight behavior for the drones.
2. Only destroy drones once they've been hit numerous times.
