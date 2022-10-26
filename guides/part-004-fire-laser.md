# Part 4 :: Firing a Laser

* [YouTube Video]()
* [YouTube Channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)

In this part of the series we tackle the following:

1. add a new procedure - create_entities()
2. creating a new "laser" entity
3. firing a single laser with the spacebar key

## create_entities()

Our main procedure is getting a little large, so let's move all of code for creating new entities to a dedicated procedure. Normally, I would not be so quick to move things to a dedicated procedure, but this isn't code we need to look at again and again, so I don't mind getting it out of the way.

## Our Laser Entity

Our Laser Entity is very similar to our main Player Entity:

- it's a png
- it's not a sprite sheet but a single image
- it's a little large, and it needs to be scaled down

You can download the laser image [here](https://github.com/patrickodacre/odin-space-shooter/blob/master/assets/bullet_red_2.png).

We'll load our .png in the same way we loaded our player image, and we'll resize it to better match our main player spaceship.

```odin

	laser_texture := SDL_Image.LoadTexture(game.renderer, "assets/bullet_red_2.png")
	assert(laser_texture != nil, SDL.GetErrorString())
	SDL.QueryTexture(laser_texture, nil, nil, &destination.w, &destination.h)
	destination.w /= 3
	destination.h /= 3

	game.laser = Entity{
		tex = laser_texture,
		dest = destination,
		health = 0,
	}

```

Notice the new "health" field added to the Entity struct. `health` gives us a simple way to track whether or not our laser should be rendered to the screen.

## Firing our Laser

Each time the player hits the spacebar, we'll fire our laser.

```odin

game.fire = state[SDL.Scancode.SPACE] > 0

```

To enforce single shots, our laser will only fire if the health is `0`. Once fired, the laser health is reset to `1` and its position is set to just beyond the current position of the ship, so it appears to be firing directly from the ship.

```odin

if game.fire && game.laser.health == 0
{
	game.laser.dest.x = game.player.dest.x + 30
	game.laser.dest.y = game.player.dest.y
	game.laser.health = 1
}

```

Once our laser disappears offscreen, we reset the health to `0` so we can fire it again.

```odin

if game.laser.dest.x > WINDOW_WIDTH
{
	game.laser.health = 0
}

```

We only want to render our laser to the screen if it has been fired and hasn't yet disappeared offscreen.

```odin

if game.laser.health > 0
{
	game.laser.dest.x += i32(get_delta_motion(LASER_SPEED))
	SDL.RenderCopy(game.renderer, game.laser.tex, nil, &game.laser.dest)
}

```

To decide how quickly we should move our laser we use a new constant `LASER_SPEED`. As with our player, we want our laser to move at the rate we choose irrespective of the frame rate, so we need to calculate its delta motion. Since this operation is now performed on both the `player` and the `laser` we can create a new procedure `get_delta_motion()`

```odin

get_delta_motion :: proc(speed: f64) -> f64
{
	return speed * (f64(TARGET_DELTA_TIME) / 1000)
}

```

`get_delta_motion()` is similar to another procedure we wrote `get_time()` -- both procedures return a value. In Odin return values are specified using this arrow syntax `->`.

## Suggested Challenge

Try and find a way to fire more than one laser at a time.

I came up with a way using one of Odin's array types - a Fixed Array.

Odin has Fixed Arrays and Dynamic Arrays. Fixed Arrays have a set length that cannot be changed; whereas, Dynamic Arrays can grow dynamically to suit runtime requirements.

Try to give your ship a fixed number of lasers to fire using a Fixed Array. Once a laser goes offscreen, it should be made available again to fire.

Good luck!

