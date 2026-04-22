package launcher

import "core:strings"
import "core:time"
import mu "vendor:microui"
import rl "vendor:raylib"

MAX_EXE :: 512
MAX_NAME :: 128
MAX_ARGS :: 1024

Config :: struct {
	args_buf: [MAX_ARGS]u8,
	args_len: int,
}

Group :: struct {
	name_buf: [MAX_NAME]u8,
	name_len: int,
	configs:  [dynamic]Config,
}

Running :: struct {
	handle:  rawptr,
	pid:     u32,
	started: time.Time,
	cmdline: string,
}

Drop_Zone :: struct {
	group: int,
	cfg:   int,
	y:     i32,
}

Config_Move :: struct {
	src_group: int,
	src_cfg:   int,
	dst_group: int,
	dst_cfg:   int,
}

Drag :: struct {
	active:    bool,
	src_group: int,
	src_cfg:   int,
}

App :: struct {
	exe_buf:           [MAX_EXE]u8,
	exe_len:           int,
	groups:            [dynamic]Group,
	running:           [dynamic]Running,
	dirty:             bool,
	save_at:           time.Time,
	pending_del_group: [dynamic]int,
	pending_del_cfg:   [dynamic][2]int,
	pending_kill:      [dynamic]int,
	pending_move_cfg:  [dynamic]Config_Move,
	drag:              Drag,
	drop_zones:        [dynamic]Drop_Zone,
	hot_drop:          Drop_Zone,
}

SAVE_DEBOUNCE :: 500 * time.Millisecond

set_buf :: proc(buf: []u8, length: ^int, s: string) {
	n := len(s)
	if n > len(buf) {
		n = len(buf)
	}
	copy(buf, s[:n])
	length^ = n
}

mark_dirty :: proc(app: ^App) {
	app.dirty = true
	app.save_at = time.time_add(time.now(), SAVE_DEBOUNCE)
}

apply_pending :: proc(app: ^App) {
	if len(app.pending_move_cfg) > 0 {
		for m in app.pending_move_cfg {
			if m.src_group < 0 || m.src_group >= len(app.groups) { continue }
			sg := &app.groups[m.src_group]
			if m.src_cfg < 0 || m.src_cfg >= len(sg.configs) { continue }
			if m.dst_group < 0 || m.dst_group >= len(app.groups) { continue }
			dg := &app.groups[m.dst_group]

			cfg := sg.configs[m.src_cfg]
			ordered_remove(&sg.configs, m.src_cfg)

			dst := m.dst_cfg
			if m.src_group == m.dst_group && m.src_cfg < dst { dst -= 1 }
			dst = clamp(dst, 0, len(dg.configs))

			inject_at(&dg.configs, dst, cfg)
		}
		clear(&app.pending_move_cfg)
		mark_dirty(app)
	}

	for idx in app.pending_kill {
		if idx >= 0 && idx < len(app.running) {
			kill_running(&app.running[idx])
		}
	}
	clear(&app.pending_kill)

	if len(app.pending_del_cfg) > 0 {
		pairs := app.pending_del_cfg[:]
		for i := 1; i < len(pairs); i += 1 {
			j := i
			for j > 0 {
				a, b := pairs[j - 1], pairs[j]
				if a[0] < b[0] || (a[0] == b[0] && a[1] < b[1]) {
					pairs[j - 1], pairs[j] = b, a
					j -= 1
				} else {break}
			}
		}
		for p in pairs {
			gi, ci := p[0], p[1]
			if gi < 0 || gi >= len(app.groups) {continue}
			g := &app.groups[gi]
			if ci < 0 || ci >= len(g.configs) {continue}
			ordered_remove(&g.configs, ci)
		}
		clear(&app.pending_del_cfg)
		mark_dirty(app)
	}

	if len(app.pending_del_group) > 0 {
		gs := app.pending_del_group[:]
		for i := 1; i < len(gs); i += 1 {
			j := i
			for j > 0 && gs[j - 1] < gs[j] {
				gs[j - 1], gs[j] = gs[j], gs[j - 1]
				j -= 1
			}
		}
		for gi in gs {
			if gi < 0 || gi >= len(app.groups) {continue}
			delete(app.groups[gi].configs)
			ordered_remove(&app.groups, gi)
		}
		clear(&app.pending_del_group)
		mark_dirty(app)
	}
}

text_width_cb :: proc(font: mu.Font, str: string) -> i32 {
	f := (^rl.Font)(font)
	cstr := strings.clone_to_cstring(str, context.temp_allocator)
	return i32(rl.MeasureTextEx(f^, cstr, FONT_SIZE, FONT_SPACING).x)
}
text_height_cb :: proc(font: mu.Font) -> i32 {return i32(FONT_SIZE)}

set_clipboard_cb :: proc(user_data: rawptr, text: string) -> (ok: bool) {
	c := strings.clone_to_cstring(text, context.temp_allocator)
	rl.SetClipboardText(c)
	return true
}

get_clipboard_cb :: proc(user_data: rawptr) -> (text: string, ok: bool) {
	c := rl.GetClipboardText()
	if c == nil {return "", false}
	return string(c), true
}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.SetTraceLogLevel(.WARNING)
	rl.InitWindow(960, 720, "Launcher")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	ctx := new(mu.Context)
	defer free(ctx)

	font := new(rl.Font)
	font^ = r_init_font()
	defer rl.UnloadFont(font^)
	defer free(font)

	mu.init(ctx, set_clipboard_cb, get_clipboard_cb)
	ctx.style.font         = mu.Font(font)
	ctx.style.size.y       = 20
	ctx.style.padding      = 6
	ctx.style.spacing      = 4
	ctx.style.indent       = 24
	ctx.style.title_height = 26
	ctx.text_width         = text_width_cb
	ctx.text_height        = text_height_cb

	atlas := r_build_atlas()
	defer rl.UnloadTexture(atlas)

	app: App
	persist_load(&app)
	defer persist_save(&app)

	for !rl.WindowShouldClose() {
		r_input(ctx, app.drag.active)
		launch_poll(&app)

		mu.begin(ctx)
		build_ui(&app, ctx)
		mu.end(ctx)

		if app.drag.active && rl.IsMouseButtonReleased(.LEFT) {
			z := app.hot_drop
			if z.group >= 0 {
				src_ci := app.drag.src_cfg
				is_noop := z.group == app.drag.src_group && (z.cfg == src_ci || z.cfg == src_ci + 1)
				if !is_noop {
					append(&app.pending_move_cfg, Config_Move{
						src_group = app.drag.src_group,
						src_cfg   = app.drag.src_cfg,
						dst_group = z.group,
						dst_cfg   = z.cfg,
					})
				}
			}
			app.drag.active = false
			app.hot_drop = {}
		}

		apply_pending(&app)

		if app.dirty && time.since(app.save_at) >= 0 {
			persist_save(&app)
			app.dirty = false
		}

		rl.BeginDrawing()
		rl.ClearBackground(rl.Color{32, 32, 32, 255})
		r_draw(ctx, atlas)
		if app.drag.active {
			draw_drag_overlay(&app, ctx)
		}
		rl.EndDrawing()

		free_all(context.temp_allocator)
	}
}
