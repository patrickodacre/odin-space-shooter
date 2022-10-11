# Part 1 :: Game Loop

* [YouTube Video]()
* [YouTube Channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg)
* [SDL2 Core Library](https://wiki.libsdl.org/CategoryAPI)
* [Odin Documentation](https://github.com/odin-lang/Odin/wiki)

## SDL2 - Some Functions Used

**SDL.Init(u32 Subsystem_Init_Flags)**

We call this using the `SDL.INIT_VIDEO` flag to initialize the video subsystem. The `events` subsystem is also initialized automatically.

**SDL.Quit()**

Shuts down the initialized subsystems.

**SDL.CreateWindow()** && **SDL.DestroyWindow()**

There are a number of flags available for creating a window, but at this stage we'll only use `SDL.WINDOW_SHOWN` which makes the window visible.

According to the [documentation](https://wiki.libsdl.org/SDL_CreateWindow) this particular flag isn't necessary, but I've put it here anyway for learning purposes.

**SDL.CreateRenderer()** && **SDL.DestroyRenderer()**

A Renderer is a rendering context for the life of the game. You only need ONE renderer for all graphics in your game.

`SDL.CreateRenderer()` accepts a number of [flags](https://wiki.libsdl.org/SDL_RendererFlags) to configure the renderer you want to create. At this point in my learning, I do not enable vsync so I can see the impact of using an enforced frame rate in my game loop.

**SDL.GetPerformanceCounter()** && **SDL.GetPerformanceFrequency()**

Used together, these functions allow us to get timestamps for the *start* and *end* of our game loop. These timestamps are used to enforce a frame rate, making things like physics easier to manage.

This frame rate timing is also used to modify movement. The "delta time" modifier ensures movement speed will be independent of frame rate speed. This is covered in other videos on the [Handmade Games channel](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg).

**SDL.GetKeyboardState()**

This function returns an array of bytes that tells us which keys are currently pressed on the keyboard.

We can then use the keyboard state to handle things like character movement.

**SDL.PollEvent()**

Keyboard events like `KEYUP` and `KEYDOWN` are queued. `SDL.PollEvent()` gets the latest event and uses the data to populate the given `event` struct. 

For now, we're just handling QUIT events, but in the future we'll handle others like `fire weapons`, `pause game`, etc.

**SDL.RenderPresent()**

In a future 'update and render' section of our game loop, we'll be drawing a scene in the background that won't be presented to the screen until it is finished (at the end our loop). 

This function replaces or "flips" the old scene from the previous frame with the new one we just drew in the present frame.

**SDL.RenderDrawColor()** && **SDL.RenderClear()**

`SDL.RenderClear()` will clear the background scene to get it ready for the next drawing. The old scene will be cleared to whatever color is set by `SDL.RenderDrawColor()`. 

Many code examples you'll find (like the one [here](https://wiki.libsdl.org/SDL_CreateRenderer)) will demonstrate using `SDL.RenderClear()` before `SDL.RenderPresent()`. This is because it draws the entire scene using `SDL.RenderCopy()** in a step distinct from the update portion of the code. We won't be doing that. Instead, we'll be updating and rendering our scene as close together as possible. This means we clear our background scene after the presentation, making it ready for our new scene at the beginning of our next frame.

## Odin - Some Functions Used

For explanations of keywords, etc. look at comments in `main.odin`.

**assert()**

Not to be confused with `#assert()` which is a compile-time assertion, `assert()` exits the program and displays the given error string in the console when the given expression is false. 

**defer**

A `defer` statement defers the execution of a statement until the end of the scope it is in.

**fmt.println()**

From the `fmt` package, `println()` prints a line to the console.

## Game Loop Explained

Before the game loop starts, I initialize variables for my timestamps, any event, and the keyboard state.

```odin

game.perf_frequency = f64(SDL.GetPerformanceFrequency())
start : f64
end : f64

event : SDL.Event
state : [^]u8

```

Before doing anything else, we get the `start` time for the loop, and only after all the work is done do we get the `end` time.

Inbetween our `start` and `end` points we perform the following operations in order:

1. Get our current keyboard state
2. Handle any input events
3. Update and Render

Updates and Rendering should only happen after current keyboard state and events are known. These variables will drive how we update our game state.

Finally, as mentioned above, updates and rendering should happen at the same time. Separating these operations arbitrarily has a big performance cost.

## Next Video!

In the next video, I'll cover rendering our main player entity.

Subscribe to [Handmade Games](https://www.youtube.com/channel/UCKXSHFNc-5D9i3heHkHgeUg) if you're interested in learning how to program games from scratch using SDL2 and the Odin programming language.


