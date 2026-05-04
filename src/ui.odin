package launcher

import "core:fmt"
import "core:strings"
import mu "vendor:microui"
import rl "vendor:raylib"

build_ui :: proc(app: ^App, ctx: ^mu.Context) {
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()

	clear(&app.drop_zones)

	// Keep the mu root container sized to the raylib window (one frame lag is fine).
	if cnt := mu.get_container(ctx, "launcher"); cnt != nil {
		cnt.rect = mu.Rect{0, 0, w, h}
	}

	opts := mu.Options{.NO_CLOSE, .NO_TITLE, .NO_RESIZE}
	if mu.window(ctx, "launcher", mu.Rect{0, 0, w, h}, opts) {
		mu.layout_row(ctx, {110, -1}, 0)
		mu.label(ctx, "Executable:")
		if .CHANGE in mu.textbox(ctx, app.exe_buf[:], &app.exe_len) {
			mark_dirty(app)
		}

		row_h := ctx.style.size.y + ctx.style.padding * 2
		running_block_h := ctx.style.title_height + i32(len(app.running)) * row_h
		reserve := row_h + running_block_h
		groups_h := h - row_h * 2 - reserve
		if groups_h < 120 {groups_h = 120}

		mu.layout_row(ctx, {-1}, groups_h)
		mu.begin_panel(ctx, "groups")
		{
			for gi := 0; gi < len(app.groups); gi += 1 {
				g := &app.groups[gi]
				mu.push_id(ctx, uintptr(gi + 1))

				title := string(g.name_buf[:g.name_len])
				label_text := title
				if len(label_text) == 0 {label_text = "(unnamed group)"}

				mu.layout_row(ctx, {-1}, 0)
				r := mu.layout_next(ctx)
				hdr_id := mu.get_id(ctx, "hdr")
				mu.update_control(ctx, hdr_id, r, {})
				if ctx.mouse_pressed_bits == {.LEFT} && ctx.focus_id == hdr_id {
					g.expanded = !g.expanded
				}
				mu.draw_control_frame(ctx, hdr_id, r, .BUTTON)
				icon := mu.Icon.EXPANDED if g.expanded else mu.Icon.COLLAPSED
				mu.draw_icon(ctx, icon, mu.Rect{r.x, r.y, r.h, r.h}, ctx.style.colors[.TEXT])
				text_r := mu.Rect{r.x + r.h - ctx.style.padding, r.y, r.w - r.h + ctx.style.padding, r.h}
				mu.draw_control_text(ctx, label_text, text_r, .TEXT)

				if g.expanded {
					mu.layout_row(ctx, {70, -150, 130}, 0)
					name_rect := mu.layout_next(ctx)
					mu.draw_control_text(ctx, "Name:", name_rect, .TEXT, {})
					if .CHANGE in mu.textbox(ctx, g.name_buf[:], &g.name_len) {
						mark_dirty(app)
					}
					if .SUBMIT in mu.button(ctx, "Delete group") {
						append(&app.pending_del_group, gi)
					}

					for ci := 0; ci < len(g.configs); ci += 1 {
						c := &g.configs[ci]
						mu.push_id(ctx, uintptr(ci + 1))

						mu.layout_row(ctx, {28, -180, 80, 80}, 0)
						handle_rect := mu.layout_next(ctx)

						if app.drag.active {
							append(
								&app.drop_zones,
								Drop_Zone{group = gi, cfg = ci, y = handle_rect.y},
							)
							if ci == len(g.configs) - 1 {
								append(
									&app.drop_zones,
									Drop_Zone {
										group = gi,
										cfg = ci + 1,
										y = handle_rect.y + handle_rect.h,
									},
								)
							}
						}

						is_source :=
							app.drag.active && app.drag.src_group == gi && app.drag.src_cfg == ci
						handle_color :=
							ctx.style.colors[.BUTTON_HOVER] if is_source else ctx.style.colors[.BUTTON]
						mu.draw_rect(ctx, handle_rect, handle_color)
						mu.draw_control_text(ctx, "::", handle_rect, .TEXT, {})

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

						if .CHANGE in mu.textbox(ctx, c.args_buf[:], &c.args_len) {
							mark_dirty(app)
						}
						if .SUBMIT in mu.button(ctx, "Launch") {
							exe := string(app.exe_buf[:app.exe_len])
							args := string(c.args_buf[:c.args_len])
							launch_config(app, exe, args)
						}
						if .SUBMIT in mu.button(ctx, "Delete") {
							append(&app.pending_del_cfg, [2]int{gi, ci})
						}

						mu.pop_id(ctx)
					}

					if app.drag.active && len(g.configs) == 0 {
						append(
							&app.drop_zones,
							Drop_Zone{group = gi, cfg = 0, y = name_rect.y + name_rect.h},
						)
					}

					mu.layout_row(ctx, {-1}, 0)
					if .SUBMIT in mu.button(ctx, "+ Add Config") {
						append(&g.configs, Config{})
						mark_dirty(app)
					}
				}

				mu.pop_id(ctx)
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

		mu.layout_row(ctx, {-1}, 0)
		if .SUBMIT in mu.button(ctx, "+ Add Group") {
			append(&app.groups, Group{})
			mark_dirty(app)
		}

		run_title := fmt.tprintf("Running (%d)", len(app.running))
		if .ACTIVE in mu.header(ctx, run_title, {.EXPANDED}) {
			for ri := 0; ri < len(app.running); ri += 1 {
				r := &app.running[ri]
				mu.push_id(ctx, uintptr(ri + 1))

				mu.layout_row(ctx, {-80, 70}, 0)
				mu.label(ctx, r.cmdline)
				if .SUBMIT in mu.button(ctx, "Kill") {
					append(&app.pending_kill, ri)
				}

				mu.pop_id(ctx)
			}
		}
	}
}

draw_drag_overlay :: proc(app: ^App, ctx: ^mu.Context) {
	if app.hot_drop.group >= 0 {
		w := rl.GetScreenWidth()
		rl.DrawRectangle(0, app.hot_drop.y - 1, w, 2, rl.Color{100, 180, 255, 220})
	}

	sg := &app.groups[app.drag.src_group]
	if app.drag.src_cfg < len(sg.configs) {
		c := &sg.configs[app.drag.src_cfg]
		args := string(c.args_buf[:c.args_len])
		if len(args) == 0 {args = "(empty)"}
		my := f32(rl.GetMouseY())
		f := (^rl.Font)(ctx.style.font)
		cstr := strings.clone_to_cstring(args, context.temp_allocator)
		rl.DrawTextEx(
			f^,
			cstr,
			rl.Vector2{40, my},
			FONT_SIZE,
			FONT_SPACING,
			rl.Color{220, 220, 220, 180},
		)
	}
}
