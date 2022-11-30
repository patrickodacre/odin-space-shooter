# Part 9 :: Animating Explosions

* [YouTube Video]() - Coming Soon!
* [YouTube Channel](https://www.youtube.com/@HandmadeGamesDev)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)

In this guide we will display an explosion animation whenever a drone is destroyed or when our player is destroyed.

Our animation will consist of 10 png files -- 10 frames that when displayed at the correct speed will create an explosion.

## Loading the Assets && Odin's String Builder

To load our assets we'll explore some new Odin functions.

Rather than load each of the 10 png files separately, let's use a loop. On each iteration we'll use Odin's string builder functions to create the string needed for the file path.

To load our texture using `SDL_Image.LoadTexture(game.renderer, path_to_image_file)` we need the path_to_image_file which is of type `cstring`.

```odin

caprintf :: proc(format: string, args: ..any) -> cstring {
    str: strings.Builder
    strings.builder_init(&str)
    fmt.sbprintf(&str, format, ..args)
    strings.write_byte(&str, 0)
    s := strings.to_string(str)
    return cstring(raw_data(s))
}

```

`caprintf` allows us to create strings with any arguments we need:

```odin

// Explosions
for i in 0..<11
{
	path := caprintf("assets/explosion_{}.png", i + 1)
	game.effect_explosion_frames[i] = SDL_Image.LoadTexture(game.renderer, path)
	assert(game.effect_explosion_frames[i] != nil, SDL.GetErrorString())
}

```

Here, we can use our new procedure to load all 10 textures for our explosion.


## Creating the Frames for our Explosion

Rather than reuse our Entity struct, I'm using a new `Explosion` struct.

Explosions live a little longer onscreen than drones. Since we'll need explosions for drones and for the player, I estimate needing NUM_OF_DRONES * 2 instances of explosions on the screen at any given time.

Our `game.explosions` is another fixed array declared at the top of the file:

```odin
Game :: struct
{
	/// ...

	// new
	explosions: [NUM_OF_DRONES * 2]Explosion,

	/// ...
}

/// ...

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



```