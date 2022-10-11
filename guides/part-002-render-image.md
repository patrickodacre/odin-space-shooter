# Part 2 :: Rendering an Image

* [YouTube Video]()
* [YouTube Channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg)
* [SDL2 Image Library](https://wiki.libsdl.org/SDL_image/CategoryAPI)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)

Rendering an image requires initialization of the SDL Image library.

## Steps to Render an Image

1. Initialize SDL_Image for the asset file types you want to use.
2. Load a Texture
3. Keep that Texture in an Entity struct that also tracks the entity's position.
4. `SDL.RenderCopy()` to draw the entity to the scene before `SDL.RenderPresent()`

**SDL_Image.Init()**

The Image library extends the core library to allow for using .png images when we use the `SDL_Image.INIT_PNG` flag.

**SDL_Image.LoadTexture()**

In cases where you're rendering for 2d and you do NOT have to manipulate an image (other than resizing and changing position), `LoadTexture()` is the most efficient way to load an image asset. See [https://wiki.libsdl.org/SDL_image/IMG_LoadTexture](https://wiki.libsdl.org/SDL_image/IMG_LoadTexture).


```odin

player_texture := SDL_Image.LoadTexture(game.renderer, "assets/player.png")
assert(player_texture != nil, SDL.GetErrorString())

```

`SDL_Image.LoadTexture()` will return nil on an error, so it is a good idea to check that before continuing with our code.

There is a mistake in the code below, and you may not understand why your player.png isn't loading if you didn't use an `assert()` here:

```odin

// try using an assert here to see the problem:
player_texture := SDL_Image.LoadTexture(game.renderer, "/assets/player.png")

```

**Entity :: struct**

Entity structs are a simple way to keep track of entity positions and their loaded textures which you need for subsequent calls to `SDL.RenderCopy()`.

```odin

Entity :: struct
{
	tex: ^SDL.Texture,
	dest: SDL.Rect,
}

```

If you're using a sprite sheet with many sprites, you will also need to keep track of the source position of the image on the sprite sheet:

```odin

Entity :: struct
{
	tex: ^SDL.Texture,
	source: SDL.Rect,
	dest: SDL.Rect,
}

```

At this point in our code we do not need to track a source because we're loading the entire image.

**SDL.RenderCopy()**

Because we are loading the entire image, we can pass `nil` to the `SDL.RenderCopy()` function in place of the source `SDL.Rect` struct:

```odin

SDL.RenderCopy(game.renderer, game.player.tex, nil, &game.player.dest)

```

`SDL.RenderCopy()` is called after all inputs are handled and any updates are made to the player struct's position.
