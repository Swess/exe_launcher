package launcher

import "core:fmt"
import mu "vendor:microui"
import rl "vendor:raylib"

build_ui :: proc(app: ^App, ctx: ^mu.Context) {
	w := rl.GetScreenWidth()
	h := rl.GetScreenHeight()

	// Keep the mu root container sized to the raylib window (one frame lag is fine).
	if cnt := mu.get_container(ctx, "launcher"); cnt != nil {
		cnt.rect = mu.Rect{0, 0, w, h}
	}

	opts := mu.Options{.NO_CLOSE, .NO_TITLE, .NO_RESIZE}
	if mu.window(ctx, "launcher", mu.Rect{0, 0, w, h}, opts) {
		// -- Executable path ------------------------------------------------
		mu.layout_row(ctx, {110, -1}, 0)
		mu.label(ctx, "Executable:")
		if .CHANGE in mu.textbox(ctx, app.exe_buf[:], &app.exe_len) {
			mark_dirty(app)
		}

		// -- Groups panel ---------------------------------------------------
		// Reserve space for Add Group + Running panel below.
		row_h := ctx.style.size.y + ctx.style.padding * 2
		running_block_h := ctx.style.title_height + i32(len(app.running)) * row_h
		reserve := row_h + running_block_h
		groups_h := h - row_h * 2 - reserve
		if groups_h < 120 { groups_h = 120 }

		mu.layout_row(ctx, {-1}, groups_h)
		mu.begin_panel(ctx, "groups")
		{
			for gi := 0; gi < len(app.groups); gi += 1 {
				g := &app.groups[gi]
				mu.push_id(ctx, uintptr(gi + 1))

				title := string(g.name_buf[:g.name_len])
				label_text := title
				if len(label_text) == 0 { label_text = "(unnamed group)" }

				if .ACTIVE in mu.header(ctx, label_text, {.EXPANDED}) {
					mu.layout_row(ctx, {70, -150, 130}, 0)
					mu.label(ctx, "Name:")
					if .CHANGE in mu.textbox(ctx, g.name_buf[:], &g.name_len) {
						mark_dirty(app)
					}
					if .SUBMIT in mu.button(ctx, "Delete group") {
						append(&app.pending_del_group, gi)
					}

					for ci := 0; ci < len(g.configs); ci += 1 {
						c := &g.configs[ci]
						mu.push_id(ctx, uintptr(ci + 1))

						mu.layout_row(ctx, {-180, 80, 80}, 0)
						if .CHANGE in mu.textbox(ctx, c.args_buf[:], &c.args_len) {
							mark_dirty(app)
						}
						if .SUBMIT in mu.button(ctx, "Launch") {
							exe  := string(app.exe_buf[:app.exe_len])
							args := string(c.args_buf[:c.args_len])
							launch_config(app, exe, args)
						}
						if .SUBMIT in mu.button(ctx, "Delete") {
							append(&app.pending_del_cfg, [2]int{gi, ci})
						}

						mu.pop_id(ctx)
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

		// -- Add group ------------------------------------------------------
		mu.layout_row(ctx, {-1}, 0)
		if .SUBMIT in mu.button(ctx, "+ Add Group") {
			append(&app.groups, Group{})
			mark_dirty(app)
		}

		// -- Running --------------------------------------------------------
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
