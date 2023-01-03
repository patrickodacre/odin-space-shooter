# Create PowerUps

The first power up we'll add to the game is the NUKE powerup.

These nukes will be extra-powerful projectiles that have the potential to kill many drones. We do have to be careful, though. These nukes also have the ability to destroy our own ship.

We can use these nukes in a few ways:

1) They can directly destroy an enemy drone.
2) We can shoot our own laser at a nuke to destroy it and any nearby drones.
3) We can use one nuke to destroy other surrounding nukes to further extend its area of destruction.

Hopefully this makes our game a little more challenging and interesting.

## Creating Our Nuke PowerUps

We'll allow for 15 powerups to float around the window at any given time:

```odin

NUM_NUKE_PU :: 15

```

As we've done before to manage multiple entities, we'll use a fixed array to store our powerup objects, but we only need to store a single texture.

```odin

Game :: struct
{
	// other fields...

	// new
	nuke_power_up_tex: ^SDL.Texture,
	nuke_power_ups: [NUM_NUKE_PU]NukePowerUp,
}

```

We'll create our texture and populate our array in our `create_entities` function:

```odin
create_entities :: proc()
{

	game.nuke_power_up_tex = SDL_Image.LoadTexture(game.renderer, "assets/pu_nuke.png")
	assert(game.nuke_power_up_tex != nil, SDL.GetErrorString())
	pu_width : i32
	pu_height : i32
	SDL.QueryTexture(game.nuke_power_up_tex, nil, nil, &pu_width, &pu_height)

	for index in 0..<NUM_NUKE_PU
	{
		// initialize our NukePowerUp
		game.nuke_power_ups[index] = NukePowerUp{
			dest = SDL.Rect{
				w = (pu_width / 7),
				h = (pu_height / 7),
			},
			animation = Animation{
				is_active = false,
				current_frame = 0,
				frames = make([dynamic]Frame, 3, 3),
			},
		}

		/// MORE
	}
}

```

The `NukePowerUp` entity is a bit unique in that it will be animated. They should only float around the screen for a brief time, and we want them to blink a bit before vanishing altogether.

Each powerup object will have its own animation and timing to keep track of, so we embed the animation right in the instance of the entity.

Animations have a few key pieces: on each game frame, a `maybe_run` function is called. This function checks to see if the animation is active. If it is, it'll determine the current frame and render it.

Animations are activated by calling a `start()` function. This function resets `current_frame`, toggles the `is_active` boolean, etc.

Animations also contain `Frames`, and each frame has its own `action` function which is called when that frame is active.

You can [review Animations here](https://youtu.be/hhjlcmn9Zks).

```odin

NukePowerUp :: struct
{
	dest: SDL.Rect,
	dx: f64,
	dy: f64,
	animation: Animation,
	counter: int,
	alpha: u8,
}

```

This is the first time we've needed multiple instances of the same `Animation`, though, so you'll notice we've had to make some updates to the Animation and Frame struct fields:

```odin

Animation :: struct
{
	is_active: bool,
	current_frame: int,
	frames: [dynamic]Frame,
	maybe_run: proc(index: int = 0),
	start: proc(index: int = 0, dest: ^SDL.Rect = nil, dx: f64 = 0),
}

Frame :: struct
{
	duration: f64,
	timer: f64,
	action: proc(index: int),
}

```

`action`, `maybe_run` and `start` have some optional arguments: `index`, `dest`, and `dx`

Since Odin is not object oriented, we cannot refer to `self` in these functions -- we need the `index` to identify the right `NukePowerUp` in our `game.nuke_power_ups` array.

We need `dest` so we know where to render our `NukePowerUp` texture.

Finally, we need `dx` so we know how fast our `NukePowerUp` texture should move around the screen. The `dx` is the speed, and it will be set to that of the destroyed drone.

These arguments aren't necessary for every Animation, though, so we've made them optional by giving them a default value.

## NukePowerUp.start()

Our animation will start once we destroy a drone:

```odin

// if laser hits drone:
if hit
{

	drone.health = 0
	laser.health = 0

	explode_drone(&drone)
	game.current_score += 1

	// new::
	spawn_nuke_pu: for index in 0..<NUM_NUKE_PU
	{

		pu := &game.nuke_power_ups[index].animation

		if !pu.is_active
		{
			pu.start(index, &drone.dest, drone.dx)

			break spawn_nuke_pu
		}

	}
}

```

After a collision is detected, we iterate through our `nuke_power_ups` to find the first with an animation that isn't currently active so we can `start()` it.

This is our `start` function as defined in our `create_entities()` function:

```odin

pu := &game.nuke_power_ups[index].animation

pu.start = proc(index: int, dest: ^SDL.Rect, dx: f64) {
	// Odin is not object oriented, we need `index` so we can
	// identify the correct NukePowerUp object in our array.
	pu := &game.nuke_power_ups[index]
	pu.alpha = 255
	pu.counter = 0
	pu.dest.x = dest.x
	pu.dest.y = dest.y
	pu.dx = dx
	pu.animation.current_frame = 0
	pu.animation.is_active = true
}

```

As mentioned above and in the comments, Odin is not object-oriented, so we pass in the index so we can correctly identify the `NukePowerUp` we need to activate.

With our `NukePowerUp` and its animation activated, it will play through when `maybe_run` fires. We run each powerup `maybe_run` before we run our other animations to make sure our fade out covers our floating powerups:

```odin

for index in 0..<NUM_NUKE_PU
{
	nuke_pu := &game.nuke_power_ups[index]
	nuke_pu.animation.maybe_run(index)
}

game.begin_stage_animation.maybe_run()
game.fade_animation.maybe_run()
game.reset_animation.maybe_run()

```

## NukePowerUp.maybe_run()

There are a few key parts to a `maybe_run` function:

First, we need to check that we're still within the bounds of our array of `Frames`.

If we're done with all the frames, the animation has finished, and is no longer active.

If the animation is still active, then we need to grab our `current_frame` and call the frame's `action()` function along with any other work that should be done on each frame.

`maybe_run(index: int)` also takes the `index` as an argument. We need to identify the correct powerup so we can keep track of our animation frames and deactivate the animation when we reach the end.

```odin

pu.maybe_run = proc(index: int) {
	pu := &game.nuke_power_ups[index]

	if pu.animation.current_frame > 2
	{
		pu.animation.is_active = false
	}

	if pu.animation.is_active
	{

		frame := &pu.animation.frames[pu.animation.current_frame]

		hit := collision(
			game.player.dest.x,
			game.player.dest.y,
			game.player.dest.w,
			game.player.dest.h,

			pu.dest.x,
			pu.dest.y,
			pu.dest.w,
			pu.dest.h,
			)

		if hit
		{
			pu.animation.is_active = false

			if game.player_nukes < NUM_OF_NUKES
			{
				game.player_nukes += 1
			}
		}

		frame.action(index)

		frame.timer -= TARGET_DELTA_TIME

		// reset and move to the next frame
		if frame.timer < 0
		{
			frame.timer = frame.duration
			pu.animation.current_frame += 1
		}

	}
}

```

Unique to this animation is the collision check. This collision check should be done on each frame. When our ship collides with the floating power up we want to stop rendering the powerup and increase the number of nukes we have to fire.

If we don't have a collision we'll continue to render the powerup so it can progress through its frames.

## Animation Frames

We have 3 frames for this animation. Once again we need our `index` in our `action` function so we can identify the correct `NukePowerUp` in our procedure.

In each frame the powerup changes direction, and moves at slightly different speeds across the `x` and `y` axises to create the floating effect.

In the final 2 frames you'll see that we add a blinking effect to the texture by altering the `alpha`. We use `SDL.SetTextureAlphaMod(game.nuke_power_up_tex, pu.alpha)` to change the alpha before rendering the texture -- `SDL.RenderCopy(game.renderer, game.nuke_power_up_tex, nil, &pu.dest)`

In the second frame the alpha changes every 15 frames `if pu.counter > 15`, and in the final frame the alpha changes every 3 frames `if pu.counter > 3`. Of course, this makes the powerup blink more quickly, and hopefully communicates to the player that it will soon disappear.

## Update Our reset_entities() Function

`reset_entities()` is called whenever we reset the game after death

```odin
	for nuke_pu in &game.nuke_power_ups
	{
		nuke_pu.animation.is_active = false
	}

```
