# Part 8 :: Enemies Attack!

* [YouTube Video]() - Coming Soon!
* [YouTube Channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)

In this guide we'll go through the following steps:

2. Create && Fire Drone Lasers
3. Implement Drone Laser Limits
3. Show Entity hitboxes
2. Clean up our drone laser SOURCE SDL.Rect for better hitboxes

## Create && Fire Drone Lasers

We'll create a fixed number of lasers for the drones to use. Much like with our own laser, a drone laser won't fire unless it is available.

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


### Direct Fire

As a first step, let's have our drone's fire directly ahead like we do with our player.

```odin


### Aiming Drone Lasers

Ensuring drone lasers fire towards our player each time will make the game a little more realistic.


## Implement Drone Laser Limits

To make sure our drones aren't firing lasers too quickly, we'll implement some cooldown timers. These timers will help regulate drone attack speed, making our game a little more enjoyable.