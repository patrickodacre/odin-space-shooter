# Part 3 :: Moving the Player

* [YouTube Video]()
* [YouTube Channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg)
* [SDL2 Scancodes](https://wiki.libsdl.org/SDL_Scancode)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)

There are numerous ways to handle keyboard input for player movement.

The easiest method I have found so far consists of the following parts:

1. SDL.GetKeyboardState() or SDL.PollEvent() for KEYDOWN / KEYUP events
2. (Delta Time or Enforced Frame Rate) * target_pixels_per_second

## SDL.GetKeyboardState()

This function allows us to check which keys on the keyboard are pressed. In our code we set 4 booleans based on the state of the 4 movement keys we're interested in -- WASD.

The other way to set these boolean flags is to set them to `true` on the appropriate `KEYDOWN` event and `false` on the corresponding `KEYUP` event. `KEYDOWN` means the key has been pressed. `KEYUP` means the key has been released.

This second method, though, requires us to also check if the `KEYDOWN` or `KEYUP` event is either a repeated event, or the initial pressing / releasing of that key. If we do not distinguish between the two we could get some strange behavior as we poll the event queue.

```odin

state := SDL.GetKeyboardState(nil)

game.left = state[SDL.Scancode.A] > 0
game.right = state[SDL.Scancode.D] > 0
game.up = state[SDL.Scancode.W] > 0
game.down = state[SDL.Scancode.S] > 0

// versus ...

if event.type == SDL.EventType.KEYDOWN
{
	// not repeated
	if event.repeat == 0
	{

		if event.key.keysym.scancode == SDL.Scancode.A
		{
			game.left = true
		}
		/// ...
	}
}

if event.type == SDL.EventType.KEYUP
{
	// not repeated
	if event.repeat == 0
	{

		if event.key.keysym.scancode == SDL.Scancode.A
		{
			game.left = false
		}
		/// ...
	}
}

```

I think you'll agree that checking the keyboard state is much nicer to look at. This second option is too verbose for what we need.

## delta_time and Delta Motion

Delta Motion is the incremental movement calculated for the present frame based on the time it took to complete the previous frame -- the delta time. In practice, this delta time is multiplied by the desired travel distance measured in pixels per second. This ensures that movement doesn't speed up or slow down when the frame rate changes from machine to machine.

```odin

delta_motion := PLAYER_SPEED * (f64(TARGET_DELTA_TIME) / 1000)

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

```

I would also like to point out a handy Odin function for ensure the player doesn't move off screen:

```odin

move_player :: proc(x, y: f64)
{
	game.player.dest.x = clamp(game.player.dest.x + i32(x), 0, WINDOW_WIDTH - game.player.dest.w)
	game.player.dest.y = clamp(game.player.dest.y + i32(y), 0, WINDOW_HEIGHT - game.player.dest.h)
}

```

`clamp()` returns the given value provided it is between the given min and max arguments; otherwise, it will return the min or the max value provided.

In other games I've used a combination of `min()` and `max()` that work well for basic collision detection, but for now `clamp()` does a good job.

## SDL.RenderCopy()

Once we're done updating the player position, it is time to render that player to the window. Keep in mind that we're not displaying the updated player position, yet. We're rendering the image in the background, drawing the scene that will be displayed when we next call `SDL.RenderPresent()`.

## Odin Highlights

### Variable Declarations

In Odin, the colon `:` is used for variables and other type declarations.

* [Variable Declarations](https://odin-lang.org/docs/overview/#variable-declarations)
* [Constant Declarations](https://odin-lang.org/docs/overview/#constant-declarations)

When we declare a constant for the player's speed, we specify an `f64` type rather than allow the constant to default to an `int`

```odin

PLAYER_SPEED : f64 : 500 // pixels per second

```

Notice how our struct and procedure declarations follow the same pattern:

```odin

Entity :: struct
{
	tex: ^SDL.Texture,
	dest: SDL.Rect,
}

main :: proc()
{
	//
}

```

### Package Naming

In the first parts of this series we named our package "main", but this is just an arbitrary name -- we can name our "main" package anything we want, so I renamed it "game".

```odin

package game

import "core:fmt"
import SDL "vendor:sdl2"
import SDL_Image "vendor:sdl2/image"

```

Notice also that we gave custom names to our imported packages.

Had we not chosen `SDL` and `SDL_Image`, we would reference these imported packages with `sdl2` and `image` prefixes like so:

```odin

assert(sdl2.Init(sdl2.INIT_VIDEO) == 0, sdl2.GetErrorString())
assert(image.Init(image.INIT_PNG) != nil, sdl2.GetErrorString())
defer sdl2.Quit()

```

Nice and simple!

## Suggested Exercises

Player movement is an interesting subject, and I have published a few videos documenting my search for a deeper understanding.

Perhaps you will find it helpful to download my movement tool visualization tool detailed here in this [video](https://www.youtube.com/watch?v=3xxac2Yip3Y).

To practice, you should experiment with the different ways to handle movement. Perhaps you can figure out how to use SDL to handle input from a game controller.

Be sure to post about your progress in the comments for [this video]().

Good luck!