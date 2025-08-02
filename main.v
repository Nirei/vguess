import os
import math
import term.ui as tui

const window_size = 5
const possibilities = 64 // 2 ^ (window_size + 1)
const u_arrow_left = "<-"
const u_arrow_right = "->"
const arrow = [u_arrow_left, u_arrow_right]

enum Arrow {
	left
	right
}

struct App {
	debug bool
mut:
	tui &tui.Context = unsafe { nil }
	window [window_size]Arrow
	frequencies [possibilities]int
	count int
	success int
}

fn window_to_index(window [window_size]Arrow) int {
	mut accumulator := 0
	for index := 0; index < window_size; index += 1 {
		accumulator += int(math.powi(2, index+1)) * int(window[index])
	}
	return accumulator
}

fn push_to_window(mut window [window_size]Arrow, item Arrow) {
	for index := 0; index < window_size-1; index += 1 {
		window[index] = window[index+1]
	}
	window[window_size-1] = item
}

fn calculate_entropy(app App) f64 {
	mut accumulator := 0.0
	for freq in app.frequencies {
		probability := freq / f64(app.count)

		if probability > math.epsilon {
			accumulator += probability * math.log2(probability)
		}
	}
	return -accumulator / possibilities
}

fn (mut app App) show_header() {
	app.tui.clear()
	precission := if app.count > 0 { 100 * app.success / app.count } else { 0 }
	entropy := if app.count > 0 { 100 * calculate_entropy(app) } else { 0 }
	app.tui.set_cursor_position(0, 0)
	app.tui.write('Press <- or ->, press ESC to exit\n')
	app.tui.write('Attempt ${app.count} | Precission ${precission}% | Entropy ${entropy:.2}%\n')

	app.tui.flush()
}

fn event(e &tui.Event, mut app App) {
	app.show_header()

	if e.typ == .key_down && e.code == .escape {
		println('\nGood bye.')
		exit(0)
	}

	// Have we got enough input to start predicting?
	ready := app.count > window_size

	// Prediction
	index := window_to_index(app.window)
	freq_left := app.frequencies[index + int(Arrow.left)]
	freq_right := app.frequencies[index + int(Arrow.right)]
	predicted := if freq_left > freq_right { Arrow.left } else { Arrow.right }
	predicted_character := if ready { arrow[predicted] } else { "-" }

	// Actual
	if e.code !in [.left, .right] { return }
  pressed := if e.code == .left { Arrow.left } else { Arrow.right }

  app.tui.write("Predicted: ${predicted_character}\n")
	app.tui.write("Pressed: ${arrow[pressed]}\n")
	if pressed == predicted { 
		app.tui.write(":^) Gotcha!\n")
		app.success += 1
	} else {
		app.tui.write(":^( I missed!\n")
	}


	// Update
	if ready { app.frequencies[index + int(pressed)] += 1 }
	push_to_window(mut app.window, pressed)
	app.count += 1

	if app.debug {
		app.tui.write('Current sequence ${app.window}\n')
		app.tui.write('Current index ${window_to_index(app.window)} / ${possibilities-1}\n')
		app.tui.write('Current frequencies ${app.frequencies}\n')
	}

	app.tui.flush()
}

type EventFn = fn (&tui.Event, voidptr)

fn main() {
	mut app := &App{
		debug: 								os.args.len > 1 && os.args[1] == "-d"
	}
	app.tui = tui.init(
		user_data:            app
		event_fn:             EventFn(event)
		window_title:         'Guess my next key'
		hide_cursor:          true
		capture_events:       true
		frame_rate:           60
		use_alternate_buffer: false
	)
	app.show_header()
	app.tui.run()!
}