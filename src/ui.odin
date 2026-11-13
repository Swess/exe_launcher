package launcher

import "core:fmt"
import "core:math"
import "core:path/filepath"
import "core:strings"
import "core:time"
import mu "vendor:microui"
import rl "vendor:raylib"

BG :: mu.Color{12, 14, 19, 255}
SURFACE :: mu.Color{20, 23, 31, 255}
SURFACE_HI :: mu.Color{30, 34, 45, 255}
INPUT :: mu.Color{14, 16, 22, 255}
BORDER :: mu.Color{38, 43, 56, 255}
BORDER_HI :: mu.Color{60, 67, 86, 255}
TEXT :: mu.Color{231, 234, 241, 255}
TEXT_DIM :: mu.Color{146, 153, 172, 255}
TEXT_FAINT :: mu.Color{92, 99, 118, 255}
ACCENT :: mu.Color{129, 112, 255, 255}
ACCENT_HI :: mu.Color{150, 136, 255, 255}
GREEN :: mu.Color{52, 211, 153, 255}
RED :: mu.Color{248, 92, 112, 255}
WHITE :: mu.Color{255, 255, 255, 255}

GROUP_COLORS := [?]mu.Color {
	{129, 112, 255, 255},
	{45, 212, 191, 255},
	{251, 191, 36, 255},
	{244, 114, 182, 255},
	{56, 189, 248, 255},
	{163, 230, 53, 255},
}

THEME_COLORS :: [mu.Color_Type]mu.Color {
	.TEXT         = TEXT,
	.SELECTION_BG = {129, 112, 255, 110},
	.BORDER       = BORDER,
	.WINDOW_BG    = BG,
	.TITLE_BG     = SURFACE,
	.TITLE_TEXT   = TEXT,
	.PANEL_BG     = {},
	.BUTTON       = SURFACE_HI,
	.BUTTON_HOVER = BORDER,
	.BUTTON_FOCUS = BORDER_HI,
	.BASE         = INPUT,
	.BASE_HOVER   = INPUT,
	.BASE_FOCUS   = {10, 11, 16, 255},
	.SCROLL_BASE  = {},
	.SCROLL_THUMB = {255, 255, 255, 36},
}

ROOT_PAD :: 20
TOPBAR_H :: 68
CARD_PAD :: 10
CARD_GAP :: 12
DOCK_PAD :: 14
CAPTION_H :: 16
GRIP_W :: 22
ICON_BTN :: 34
RUN_BTN :: 82
NEW_GROUP_BTN :: 132
META_W :: 170

Button_Kind :: enum u8 {
	Ghost,
	Accent,
	Run,
	Danger,
}

fade :: #force_inline proc(c: mu.Color, a: u8) -> mu.Color {
	return mu.Color{c.r, c.g, c.b, a}
}

shape :: #force_inline proc(ctx: ^mu.Context, g: Glyph, r: mu.Rect, c: mu.Color) {
	mu.draw_icon(ctx, mu.Icon(g), r, c)
}

text_in :: proc(ctx: ^mu.Context, kind: Font_Kind, str: string, x: i32, r: mu.Rect, color: mu.Color) -> i32 {
	f := mu_font(kind)
	mu.draw_text(ctx, f, str, mu.Vec2{x, r.y + (r.h - ctx.text_height(f)) / 2}, color)
	return ctx.text_width(f, str)
}

text_centered :: proc(ctx: ^mu.Context, kind: Font_Kind, str: string, r: mu.Rect, color: mu.Color) {
	w := ctx.text_width(mu_font(kind), str)
	text_in(ctx, kind, str, r.x + (r.w - w) / 2, r, color)
}

badge :: proc(ctx: ^mu.Context, str: string, x: i32, r: mu.Rect, bg, fg: mu.Color) -> i32 {
	b := mu.Rect{x, r.y + (r.h - 20) / 2, ctx.text_width(mu_font(.Caption), str) + 16, 20}
	shape(ctx, .Pill, b, bg)
	text_in(ctx, .Caption, str, b.x + 8, b, fg)
	return b.w
}

draw_card :: proc(ctx: ^mu.Context, r: mu.Rect) {
	shape(ctx, .Shadow, r, {0, 0, 0, 90})
	shape(ctx, .Round_Lg, r, BORDER)
	shape(ctx, .Round_Lg, mu.expand_rect(r, -1), SURFACE)
}

draw_frame :: proc(ctx: ^mu.Context, rect: mu.Rect, colorid: mu.Color_Type) {
	color := ctx.style.colors[colorid]
	#partial switch colorid {
	case .SCROLL_THUMB:
		shape(ctx, .Pill, mu.Rect{rect.x + 3, rect.y, rect.w - 6, rect.h}, color)
	case .BASE, .BASE_HOVER, .BASE_FOCUS:
		border := BORDER
		if colorid == .BASE_HOVER {border = BORDER_HI}
		if colorid == .BASE_FOCUS {
			border = ACCENT
			shape(ctx, .Round_Lg, mu.expand_rect(rect, 3), fade(ACCENT, 45))
		}
		shape(ctx, .Round, rect, border)
		shape(ctx, .Round, mu.expand_rect(rect, -1), color)
	case:
		if color.a > 0 {mu.draw_rect(ctx, rect, color)}
	}
}

button :: proc(ctx: ^mu.Context, key, label: string, glyph: Glyph, kind: Button_Kind) -> bool {
	id := mu.get_id(ctx, key)
	r := mu.layout_next(ctx)
	mu.update_control(ctx, id, r, {})
	is_hot := ctx.hover_id == id || ctx.focus_id == id

	bg, fg: mu.Color
	switch kind {
	case .Ghost:
		bg = SURFACE_HI if is_hot else {}
		fg = TEXT if is_hot else TEXT_DIM
	case .Accent:
		bg = ACCENT_HI if is_hot else ACCENT
		fg = WHITE
	case .Run:
		bg = fade(GREEN, 64 if is_hot else 30)
		fg = GREEN
	case .Danger:
		bg = fade(RED, 44) if is_hot else {}
		fg = RED if is_hot else TEXT_FAINT
	}
	if bg.a > 0 {shape(ctx, .Round, r, bg)}

	font := mu_font(.UI_Bold)
	tw := ctx.text_width(font, label) if len(label) > 0 else 0
	gw: i32 = 16 if glyph != .None else 0
	gap: i32 = 8 if gw > 0 && tw > 0 else 0
	x := r.x + (r.w - gw - gap - tw) / 2
	if gw > 0 {shape(ctx, glyph, mu.Rect{x, r.y, gw, r.h}, fg)}
	if tw > 0 {text_in(ctx, .UI_Bold, label, x + gw + gap, r, fg)}

	return ctx.mouse_pressed_bits == {.LEFT} && ctx.focus_id == id
}

text_field :: proc(
	ctx: ^mu.Context,
	buf: []u8,
	length: ^int,
	font: Font_Kind,
	placeholder: string,
	glyph := Glyph.None,
) -> mu.Result_Set {
	id := mu.get_id(ctx, uintptr(&buf[0]))
	r := mu.layout_next(ctx)
	inset := ctx.style.padding + 2
	if glyph != .None {inset += 24}

	// textbox_raw reads font and text inset from style, so swap them in for this one call.
	saved_font, saved_pad := ctx.style.font, ctx.style.padding
	ctx.style.font, ctx.style.padding = mu_font(font), inset
	res := mu.textbox_raw(ctx, buf, length, id, r)
	ctx.style.font, ctx.style.padding = saved_font, saved_pad

	if glyph != .None {
		shape(ctx, glyph, mu.Rect{r.x + 8, r.y, 22, r.h}, ACCENT if ctx.focus_id == id else TEXT_FAINT)
	}
	if length^ == 0 && ctx.focus_id != id {
		text_in(ctx, font, placeholder, r.x + inset, r, TEXT_FAINT)
	}
	return res
}

caption :: proc(ctx: ^mu.Context, str: string) -> mu.Rect {
	mu.layout_row(ctx, {-1}, CAPTION_H)
	r := mu.layout_next(ctx)
	text_in(ctx, .Caption, str, r.x + 2, r, TEXT_FAINT)
	return r
}

spacer :: proc(ctx: ^mu.Context, h: i32) -> mu.Rect {
	mu.layout_row(ctx, {-1}, h)
	return mu.layout_next(ctx)
}

config_matches_filter :: proc(c: ^Config, filter_lower: string) -> bool {
	args_lower := strings.to_lower(string(c.args_buf[:c.args_len]), context.temp_allocator)
	return strings.contains(args_lower, filter_lower)
}

config_is_running :: proc(app: ^App, exe, args: string) -> bool {
	for &r in app.running {
		if r.exe == exe && r.args == args {return true}
	}
	return false
}

plural :: proc(n: int, word: string) -> string {
	return fmt.tprintf("%d %s%s", n, word, "" if n == 1 else "s")
}

draw_top_bar :: proc(app: ^App, ctx: ^mu.Context, w: i32) {
	mu.draw_rect(ctx, mu.Rect{0, 0, w, TOPBAR_H}, SURFACE)
	mu.draw_rect(ctx, mu.Rect{0, TOPBAR_H - 1, w, 1}, BORDER)

	logo := mu.Rect{ROOT_PAD, (TOPBAR_H - 36) / 2, 36, 36}
	shape(ctx, .Round_Lg, logo, ACCENT)
	shape(ctx, .Play, logo, WHITE)

	n_cfg := 0
	for g in app.groups {n_cfg += len(g.configs)}
	x := logo.x + logo.w + 14
	mu.draw_text(ctx, mu_font(.Title), "Launcher", mu.Vec2{x, 11}, TEXT)
	sub := fmt.tprintf("%s  \u00b7  %s", plural(len(app.groups), "group"), plural(n_cfg, "config"))
	mu.draw_text(ctx, mu_font(.Small), sub, mu.Vec2{x, 39}, TEXT_DIM)

	n := len(app.running)
	label := fmt.tprintf("%d running", n) if n > 0 else "Idle"
	color := GREEN if n > 0 else TEXT_FAINT
	tw := ctx.text_width(mu_font(.UI_Bold), label)
	pill := mu.Rect{w - ROOT_PAD - tw - 38, (TOPBAR_H - 32) / 2, tw + 38, 32}
	shape(ctx, .Pill, pill, fade(color, 28))
	shape(ctx, .Circle, mu.Rect{pill.x + 14, pill.y + 12, 8, 8}, color)
	text_in(ctx, .UI_Bold, label, pill.x + 28, pill, color)
}

group_card :: proc(app: ^App, ctx: ^mu.Context, gi: int, visible: int, filter_lower: string) {
	g := &app.groups[gi]
	spacing := ctx.style.spacing
	row_h := ctx.style.size.y + ctx.style.padding * 2
	body := mu.get_layout(ctx).body
	accent := GROUP_COLORS[gi % len(GROUP_COLORS)]
	exe := string(app.exe_buf[:app.exe_len])

	rows := 1
	if g.expanded {rows += visible + 1}

	is_renaming := app.renaming == gi
	name_id := mu.get_id(ctx, uintptr(&g.name_buf[0]))
	buttons_w := ICON_BTN * 2 + spacing * 2
	if is_renaming {
		mu.layout_row(ctx, {GRIP_W, body.w - GRIP_W - spacing - buttons_w, ICON_BTN, ICON_BTN}, 0)
	} else {
		mu.layout_row(ctx, {body.w - buttons_w, ICON_BTN, ICON_BTN}, 0)
	}
	hr := mu.layout_next(ctx)
	card_h := i32(rows) * row_h + i32(rows - 1) * spacing + CARD_PAD * 2
	draw_card(ctx, mu.Rect{body.x - CARD_PAD, hr.y - CARD_PAD, body.w + CARD_PAD * 2, card_h})

	hdr_id := mu.get_id(ctx, "hdr")
	mu.update_control(ctx, hdr_id, hr, {})
	if ctx.mouse_pressed_bits == {.LEFT} && ctx.focus_id == hdr_id {
		g.expanded = !g.expanded
	}
	if ctx.hover_id == hdr_id {shape(ctx, .Round, hr, SURFACE_HI)}
	chevron := Glyph.Chevron_Down if g.expanded else Glyph.Chevron_Right
	shape(ctx, chevron, mu.Rect{hr.x, hr.y, GRIP_W, hr.h}, accent)

	if is_renaming {
		res := text_field(ctx, g.name_buf[:], &g.name_len, .UI_Bold, "Group name")
		if .CHANGE in res {mark_dirty(app)}
		if .SUBMIT in res || ctx.focus_id != name_id {app.renaming = -1}
	} else {
		mu.push_clip_rect(ctx, hr)
		name := string(g.name_buf[:g.name_len])
		name_color := TEXT
		if len(name) == 0 {name, name_color = "Untitled group", TEXT_DIM}
		x := hr.x + GRIP_W + spacing + 10
		x += text_in(ctx, .UI_Bold, name, x, hr, name_color) + 10
		count := fmt.tprint(len(g.configs))
		if len(filter_lower) > 0 {count = fmt.tprintf("%d / %d", visible, len(g.configs))}
		badge(ctx, count, x, hr, fade(accent, 36), accent)
		mu.pop_clip_rect(ctx)
	}

	if button(ctx, "rename", "", .Rename, .Ghost) {
		app.renaming = gi
		mu.set_focus(ctx, name_id)
		// Select the whole name so typing replaces it, like F2 in Explorer.
		ctx.textbox_state.id = u64(name_id)
		ctx.textbox_state.selection = {g.name_len, 0}
	}
	if button(ctx, "del_group", "", .Delete, .Danger) {
		append(&app.pending_del_group, gi)
	}

	if !g.expanded {return}

	for ci := 0; ci < len(g.configs); ci += 1 {
		c := &g.configs[ci]
		if len(filter_lower) > 0 && !config_matches_filter(c, filter_lower) {
			continue
		}
		mu.push_id(ctx, uintptr(ci + 1))

		mu.layout_row(ctx, {GRIP_W, body.w - GRIP_W - RUN_BTN - ICON_BTN - spacing * 3, RUN_BTN, ICON_BTN}, 0)
		handle_rect := mu.layout_next(ctx)

		if app.drag.active {
			append(&app.drop_zones, Drop_Zone{group = gi, cfg = ci, y = handle_rect.y})
			if ci == len(g.configs) - 1 {
				append(
					&app.drop_zones,
					Drop_Zone{group = gi, cfg = ci + 1, y = handle_rect.y + handle_rect.h},
				)
			}
		}

		args := string(c.args_buf[:c.args_len])
		is_source := app.drag.active && app.drag.src_group == gi && app.drag.src_cfg == ci
		if is_source {
			row := mu.Rect{body.x - 4, handle_rect.y - 2, body.w + 8, handle_rect.h + 4}
			shape(ctx, .Round, row, fade(ACCENT, 40))
		}
		if config_is_running(app, exe, args) {
			bar := mu.Rect{body.x - CARD_PAD + 3, handle_rect.y + 8, 3, handle_rect.h - 16}
			shape(ctx, .Pill, bar, GREEN)
		}
		grip_color := TEXT_FAINT
		if mu.mouse_over(ctx, handle_rect) {grip_color = TEXT}
		if is_source {grip_color = ACCENT}
		shape(ctx, .Grip, handle_rect, grip_color)

		if !app.drag.active && rl.IsMouseButtonPressed(.LEFT) {
			mx := rl.GetMouseX()
			my := rl.GetMouseY()
			if mx >= handle_rect.x &&
			   mx < handle_rect.x + handle_rect.w &&
			   my >= handle_rect.y &&
			   my < handle_rect.y + handle_rect.h {
				app.drag = Drag {
					active    = true,
					src_group = gi,
					src_cfg   = ci,
				}
			}
		}

		if .CHANGE in text_field(ctx, c.args_buf[:], &c.args_len, .Mono, "--arguments") {
			mark_dirty(app)
		}
		if button(ctx, "run", "Run", .Play, .Run) {
			launch_config(app, exe, args)
		}
		if button(ctx, "del", "", .Close, .Danger) {
			append(&app.pending_del_cfg, [2]int{gi, ci})
		}

		mu.pop_id(ctx)
	}

	if app.drag.active && len(g.configs) == 0 {
		append(&app.drop_zones, Drop_Zone{group = gi, cfg = 0, y = hr.y + hr.h})
	}

	mu.layout_row(ctx, {-1}, 0)
	if button(ctx, "add_cfg", "Add config", .Add, .Ghost) {
		append(&g.configs, Config{})
		mark_dirty(app)
	}
}

running_row :: proc(app: ^App, ctx: ^mu.Context, ri: int) {
	r := &app.running[ri]
	spacing := ctx.style.spacing
	body := mu.get_layout(ctx).body

	mu.layout_row(ctx, {body.w - META_W - ICON_BTN * 2 - spacing * 3, META_W, ICON_BTN, ICON_BTN}, 0)
	info := mu.layout_next(ctx)
	shape(ctx, .Round, mu.Rect{info.x, info.y, body.w, info.h}, SURFACE_HI)

	pulse := 0.5 + 0.5 * math.sin(f32(rl.GetTime()) * 3 + f32(ri))
	dot := mu.Rect{info.x + 13, info.y + info.h / 2 - 4, 8, 8}
	shape(ctx, .Circle, mu.expand_rect(dot, 4), fade(GREEN, u8(20 + 40 * pulse)))
	shape(ctx, .Circle, dot, GREEN)

	mu.push_clip_rect(ctx, info)
	x := info.x + 34
	x += text_in(ctx, .UI_Bold, filepath.base(r.exe), x, info, TEXT) + 12
	text_in(ctx, .Mono, r.args, x, info, TEXT_DIM)
	mu.pop_clip_rect(ctx)

	meta := mu.layout_next(ctx)
	secs := int(time.duration_seconds(time.since(r.started)))
	uptime := fmt.tprintf("%02d:%02d", secs / 60, secs % 60)
	if secs >= 3600 {uptime = fmt.tprintf("%d:%02d:%02d", secs / 3600, secs / 60 % 60, secs % 60)}
	meta_str := fmt.tprintf("PID %d  %s", r.pid, uptime)
	tw := ctx.text_width(mu_font(.Mono), meta_str)
	text_in(ctx, .Mono, meta_str, meta.x + meta.w - tw - 4, meta, TEXT_FAINT)

	if button(ctx, "restart", "", .Restart, .Ghost) {
		append(&app.pending_restart, ri)
	}
	if button(ctx, "kill", "", .Stop, .Danger) {
		append(&app.pending_kill, ri)
	}
}

build_ui :: proc(app: ^App, ctx: ^mu.Context) {
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()

	clear(&app.drop_zones)

	// Keep the mu root container sized to the raylib window (one frame lag is fine).
	if cnt := mu.get_container(ctx, "launcher"); cnt != nil {
		cnt.rect = mu.Rect{0, 0, w, h}
	}

	pad := ctx.style.padding
	spacing := ctx.style.spacing
	row_h := ctx.style.size.y + pad * 2

	// The window inset comes from style.padding at begin time; controls keep the normal padding.
	ctx.style.padding = ROOT_PAD
	is_open := mu.begin_window(ctx, "launcher", mu.Rect{0, 0, w, h}, {.NO_CLOSE, .NO_TITLE, .NO_RESIZE})
	ctx.style.padding = pad
	if !is_open {return}
	defer mu.end_window(ctx)

	draw_top_bar(app, ctx, w)
	spacer(ctx, TOPBAR_H + 16 - ROOT_PAD - spacing)

	caption(ctx, "EXECUTABLE")
	mu.layout_row(ctx, {-1}, 0)
	exe_res := text_field(ctx, app.exe_buf[:], &app.exe_len, .Mono, "C:\\path\\to\\program.exe", .Terminal)
	if .CHANGE in exe_res {
		mark_dirty(app)
	}

	spacer(ctx, 4)
	mu.layout_row(ctx, {mu.get_layout(ctx).body.w - NEW_GROUP_BTN - spacing, NEW_GROUP_BTN}, 0)
	text_field(ctx, app.search_buf[:], &app.search_len, .UI, "Filter configs", .Search)
	if button(ctx, "new_group", "New group", .Add, .Accent) {
		append(&app.groups, Group{expanded = true})
		mark_dirty(app)
	}
	gap := spacer(ctx, 4)

	n_dock := max(1, len(app.running))
	dock_h := spacing + DOCK_PAD + spacing + CAPTION_H + i32(n_dock) * (row_h + spacing) + ROOT_PAD
	groups_y := gap.y + gap.h + spacing
	groups_h := h - groups_y - dock_h
	if groups_h < 120 {groups_h = 120}

	mu.layout_row(ctx, {-1}, groups_h)
	ctx.style.padding = CARD_PAD
	mu.begin_panel(ctx, "groups", {.NO_FRAME})
	ctx.style.padding = pad
	{
		filter_lower := strings.to_lower(string(app.search_buf[:app.search_len]), context.temp_allocator)
		n_shown := 0
		for gi := 0; gi < len(app.groups); gi += 1 {
			g := &app.groups[gi]
			visible := len(g.configs)
			if len(filter_lower) > 0 {
				visible = 0
				for ci in 0 ..< len(g.configs) {
					if config_matches_filter(&g.configs[ci], filter_lower) {visible += 1}
				}
				if visible == 0 {continue}
			}
			n_shown += 1

			mu.push_id(ctx, uintptr(gi + 1))
			group_card(app, ctx, gi, visible, filter_lower)
			mu.pop_id(ctx)
			spacer(ctx, CARD_PAD * 2 + CARD_GAP - spacing * 2)
		}

		if n_shown == 0 {
			mu.layout_row(ctx, {-1}, 132)
			r := mu.layout_next(ctx)
			draw_card(ctx, r)
			title := "No groups yet"
			sub := "Create a group to save launch configs for your executable."
			if len(app.groups) > 0 {
				title = "No matches"
				sub = fmt.tprintf("No config contains \"%s\".", string(app.search_buf[:app.search_len]))
			}
			text_centered(ctx, .UI_Bold, title, mu.Rect{r.x, r.y + 38, r.w, 24}, TEXT)
			text_centered(ctx, .Small, sub, mu.Rect{r.x, r.y + 66, r.w, 24}, TEXT_DIM)
		}
	}
	mu.end_panel(ctx)

	// Compute hot drop zone (closest to mouse Y)
	if app.drag.active && len(app.drop_zones) > 0 {
		my := rl.GetMouseY()
		best := app.drop_zones[0]
		for z in app.drop_zones[1:] {
			if abs(z.y - my) < abs(best.y - my) {best = z}
		}
		app.hot_drop = best
	}

	dock := spacer(ctx, DOCK_PAD)
	mu.draw_rect(ctx, mu.Rect{0, dock.y, w, h - dock.y}, SURFACE)
	mu.draw_rect(ctx, mu.Rect{0, dock.y, w, 1}, BORDER)

	cr := caption(ctx, "RUNNING")
	cw := ctx.text_width(mu_font(.Caption), "RUNNING")
	n_running := len(app.running)
	badge_color := GREEN if n_running > 0 else TEXT_FAINT
	badge(ctx, fmt.tprint(n_running), cr.x + cw + 10, cr, fade(badge_color, 36), badge_color)

	if n_running == 0 {
		mu.layout_row(ctx, {-1}, 0)
		r := mu.layout_next(ctx)
		text_in(ctx, .Small, "Nothing running. Press Run on a config to start it.", r.x + 2, r, TEXT_FAINT)
	}
	for ri := 0; ri < n_running; ri += 1 {
		mu.push_id(ctx, uintptr(ri + 1))
		running_row(app, ctx, ri)
		mu.pop_id(ctx)
	}
}

draw_drag_overlay :: proc(app: ^App, ctx: ^mu.Context) {
	if app.hot_drop.group >= 0 {
		w := f32(rl.GetScreenWidth())
		y := f32(app.hot_drop.y - ctx.style.spacing / 2)
		accent := to_rl_color(ACCENT)
		draw_round({ROOT_PAD, y - 1, w - ROOT_PAD * 2, 3}, 1.5, accent)
		rl.DrawCircleV({ROOT_PAD, y + 0.5}, 5, accent)
	}

	sg := &app.groups[app.drag.src_group]
	if app.drag.src_cfg < len(sg.configs) {
		c := &sg.configs[app.drag.src_cfg]
		args := string(c.args_buf[:c.args_len])
		if len(args) == 0 {args = "(empty)"}
		f := &fonts[.Mono]
		cstr := strings.clone_to_cstring(args, context.temp_allocator)
		tw := rl.MeasureTextEx(f.rl, cstr, f.size, f.spacing).x
		r := rl.Rectangle{f32(rl.GetMouseX()) + 14, f32(rl.GetMouseY()) - 18, tw + 32, 36}
		draw_round({r.x, r.y + 5, r.width, r.height}, 8, {0, 0, 0, 120})
		draw_round(r, 8, to_rl_color(ACCENT))
		draw_round({r.x + 1, r.y + 1, r.width - 2, r.height - 2}, 7, to_rl_color(SURFACE_HI))
		rl.DrawTextEx(f.rl, cstr, {r.x + 16, r.y + (r.height - f.size) / 2}, f.size, f.spacing, to_rl_color(TEXT))
	}
}
