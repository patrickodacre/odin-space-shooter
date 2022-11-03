# Part 3 :: Moving the Player

* [YouTube Video](https://youtu.be/hY071s3M4N0)
* [YouTube Channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg)
* [SDL2 Scancodes](https://wiki.libsdl.org/SDL_Scancode)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)

There are numerous ways to handle keyboard input for player movement.

The easiest method I have found so far consists of the following parts:

1. SDL.GetKeyboardState() or SDL.PollEvent() for KEYDOWN / KEYUP events
2. delta_time OR TARGET_DELTA_TIME * target_pixels_per_second

## SDL.GetKeyboardState()

This function allows us to check which keys on the keyboard are pressed. In our code we set 4 booleans based on the state of the 4 movement keys we're interested in -- WASD.


```odin

state := SDL.GetKeyboardState(nil)

game.left = state[SDL.Scancode.A] > 0
game.right = state[SDL.Scancode.D] > 0
game.up = state[SDL.Scancode.W] > 0
game.down = state[SDL.Scancode.S] > 0

```

The other way to set these boolean flags is to set them to `true` on the appropriate `KEYDOWN` event and `false` on the corresponding `KEYUP` event. `KEYDOWN` means the key has been pressed. `KEYUP` means the key has been released.

```odin

if event.type == SDL.EventType.KEYDOWN
{
	if event.key.keysym.scancode == SDL.Scancode.A
	{
		game.left = true
	}
	/// ...
}

if event.type == SDL.EventType.KEYUP
{
	if event.key.keysym.scancode == SDL.Scancode.A
	{
		game.left = false
	}
	/// ...
}

```

I prefer using `SDL.GetKeyboardState()` for movement, and the `KEYDOWN` and `KEYUP` events for other things like firing weapons, jumping, etc.

## delta_time and Delta Motion

Delta Motion is the incremental movement calculated for the present frame based on the time it took to complete the previous frame -- the delta time.

In practice, this delta time is multiplied by the desired travel distance measured in pixels per second. This ensures that movement doesn't speed up or slow down when the frame rate changes from machine to machine.

With our game, though, we are enforcing a frame rate of 60 FPS. We won't allow for variable frame times. Nevertheless, we'll still use our target delta_time to calculate movement distances, because we want our movements to scale properly if we decide to support other frame rates in the future.

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

Notice, we're careful to cast our `TARGET_DELTA_TIME` to a float _before_ dividing by 1000 to get our delta_time in seconds.

I would also like to point out a handy Odin function to ensure the player doesn't move off screen -- `clamp()`:

```odin

move_player :: proc(x, y: f64)
{
	game.player.dest.x = clamp(game.player.dest.x + i32(x), 0, WINDOW_WIDTH - game.player.dest.w)
	game.player.dest.y = clamp(game.player.dest.y + i32(y), 0, WINDOW_HEIGHT - game.player.dest.h)
}

```

`clamp()` returns the given value if it is between the given min and max arguments; otherwise, it will return the min or the max value as appropriate.

## SDL.RenderCopy()

Once we're done updating the player position, it is time to render that player to the window. Keep in mind that we're not displaying the updated player position, yet. We're rendering the image in the background / to the `back buffer`. The `back buffer` is flipped to the visible `front buffer` when we next call `SDL.RenderPresent()`.

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
