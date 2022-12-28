# Track Scoring

Steps

1. Track Score -> fmt.println()
2. Display Score -> Dynamic Text

Before getting into the how-to, I want to highlight some minor refactoring I completed:

- Make testing easier by allowing player to destroy drones when is_invincible is TRUE.


## Setup

I often like to work my way backwards when programming a new feature. This helps me program the bare minimum needed to accomplish the task.

Since we know that we want our score to increase when we destroy drones, that's where we'll start -- incrementing a counter when our laser hits a drone:

```odin

if hit
{

	drone.health = 0
	laser.health = 0

	explode_drone(&drone)

	// new
	game.current_score += 1
	// fmt.println("Score :: ", game.current_score)
	// end new

	break detect_collision
}

```

We're keeping track of our score with `game.current_score`, so let's add this `int` to our Game struct:

```odin

Game :: struct
{
	// all existing code +

	current_score: int,
}

game := Game{
	// all existing code +

	current_score = 0,
}

```

`game.current_score` will initialize to ZERO by default, but I like to add the initialization in manually for learning.

Finally we have to make sure to clear our score if our player dies. We can reset the score in our `game.reset_animation`

```odin

game.reset_animation.start = proc()
{
	game.reset_animation.current_frame = 0
	game.reset_animation.is_active = true

	// new
	game.current_score = 0
}

```

We know that this `game.reset_animation.start()` function is called each time our game is reset, so we're sure to start with a fresh score each time.

To test this out you can use `fmt.println(game.current_score)` to print the score each time you increment it. But to make things more interesting, we'll render our score to the window:

## Rendering our Score to the Window

First we have to create our score label texture where we create our other text textures:

```odin
// existing game.texts code...

game.texts[TextId.ScoreLabel] = make_text("Score : ")

```

Then, we'll render this label at the top-left of the window:

```odin

// NEW ...

// Render Score
if game.screen == Screen.Play
{

	// score label
	score := game.texts[TextId.ScoreLabel]
	score.dest.x = 10
	score.dest.y = 10
	SDL.RenderCopy(game.renderer, score.tex, nil, &score.dest)

}

// End NEW ...

game.begin_stage_animation.maybe_run()
game.fade_animation.maybe_run()
game.reset_animation.maybe_run()

```

We render our score before we render our scene transition animations to ensure our fade-in and fade-out, etc. overlays our score.

Next we'll render the `game.current_score`. Rendering the score means rendering dynamic text -- text that will change regularly. So far we've only rendered static text -- text we've known before hand.

In the case of a score, we know beforehand that the only characters we need at ZERO through NINE. Of course, with these characters we can create any number we need.

In our `create_statics()` function we'll iterate through a string of numbers, create a `Text` object for each one, and store it in a map.

Note that we cannot use an array as we did with `game.texts` because we want to key our `Text` objects by a `rune` type -- arrays require integer indexes / keys, and `enum` variants can be cast to an integer easily.

```odin

game.texts[TextId.ScoreLabel] = make_text("Score : ")

// New
chars := "0123456789"
for c in chars[:]
{
	str := utf8.runes_to_string([]rune{c})
	defer delete(str)

	game.chars[c] = make_text(cstring(raw_data(str)))
}

// Background

```

Why key by a `rune` type? When we iterate through our string of numbers, we get individual runes. The `rune` type is a DISTINCT type to i32, meaning it's an i32 but distinct from other i32 types. It represents a Unicode code point.

We can change our `rune` to an actual `string` using `utf8.runes_to_string()`. Our `for _ in` loop assumes utf8 encoding. Notice we `defer delete(str)` immediately after our `utf8.runes_to_string()` call. `utf8.runes_to_string()` allocates memory for the string, so we're careful to delete it at the end of our loop to free that memory. We only need it to create our texture with `make_text()`.

To make rendering possible, we use `cstring(raw_data(str))` to give our `make_text()` function what it needs so we get our `Text` object for our rune-to-Text mapping. This map is keyed by `rune`s because we'll render our score by assembling our digit textures when we iterate through the digits of our score.

## Rendering Our Ever-Changing Score

```odin

// NEW ...
// Render Score
if game.screen == Screen.Play
{

	// score label
	score := game.texts[TextId.ScoreLabel]
	SDL.RenderCopy(game.renderer, score.tex, nil, &score.dest)

	// current_score
	score_str : string = (fmt.tprintf("%v", game.current_score))[:]
	char_spacing : i32 = 2
	prev_chars_w : i32 = 0

	starting_x : i32 = score.dest.x + score.dest.w + 10
	starting_y : i32 = score.dest.y

	// iterate characters in the string
	for c in score_str
	{
		// grab the texture for the single character
		char : Text = game.chars[c]

		// render this character after the previous one
		char.dest.x = starting_x + prev_chars_w
		char.dest.y = starting_y

		SDL.RenderCopy(game.renderer, char.tex, nil, &char.dest)

		prev_chars_w += char.dest.w + char_spacing
	}

}

// End NEW ...

game.begin_stage_animation.maybe_run()
game.fade_animation.maybe_run()
game.reset_animation.maybe_run()

```

`tprintf` change integers to strings. We iterate through a slice of that string to start assembling our digit textures.

Rendering our score requires us to cast our `game.current_score`, which is an integer, to a string. We can then iterate through our int-turned-string to look up our textures for each digit. Once we have our texture, we just have to ensure we render it next to the digit that came before.

