package launcher

import "core:strings"
import "core:unicode/utf8"
import mu "vendor:microui"
import rl "vendor:raylib"

Font :: struct {
	rl:      rl.Font,
	size:    f32,
	spacing: f32,
}

Font_Kind :: enum u8 {
	UI,
	UI_Bold,
	Title,
	Small,
	Caption,
	Mono,
	Icon,
}

fonts: [Font_Kind]Font

// microui has no rounded rects or custom icons, so shapes and icon-font glyphs travel as Command_Icon ids.
Glyph :: enum u32 {
	None     = 0,
	Round    = 64,
	Round_Lg,
	Pill,
	Circle,
	Grip,
	Shadow,
	Stop,
	Play     = 128,
	Restart,
	Delete,
	Close,
	Search,
	Add,
	Chevron_Down,
	Chevron_Right,
	Terminal,
	Rename,
}

// Segoe Fluent Icons / Segoe MDL2 Assets codepoints, in Glyph order starting at .Play.
ICON_CODEPOINTS := [?]rune{0xF5B0, 0xE72C, 0xE74D, 0xE711, 0xE721, 0xE710, 0xE70D, 0xE76C, 0xE756, 0xE8AC}

load_font :: proc(paths: []cstring, size, spacing: f32, codepoints: []rune) -> Font {
	for p in paths {
		if rl.FileExists(p) {
			f := rl.LoadFontEx(p, i32(size), raw_data(codepoints), i32(len(codepoints)))
			rl.SetTextureFilter(f.texture, .BILINEAR)
			return Font{f, size, spacing}
		}
	}
	return Font{rl.GetFontDefault(), size, spacing}
}

r_init_fonts :: proc() {
	text_cps := make([dynamic]rune, context.temp_allocator)
	for c in rune(32) ..= 255 {append(&text_cps, c)}
	append(&text_cps, 0x2022, 0x2026)
	cps := text_cps[:]

	fonts[.UI] = load_font({"C:/Windows/Fonts/segoeui.ttf"}, 17, 0, cps)
	fonts[.UI_Bold] = load_font({"C:/Windows/Fonts/seguisb.ttf", "C:/Windows/Fonts/segoeuib.ttf"}, 17, 0, cps)
	fonts[.Title] = load_font({"C:/Windows/Fonts/segoeuib.ttf"}, 22, 0, cps)
	fonts[.Small] = load_font({"C:/Windows/Fonts/segoeui.ttf"}, 14, 0, cps)
	fonts[.Caption] = load_font({"C:/Windows/Fonts/seguisb.ttf", "C:/Windows/Fonts/segoeuib.ttf"}, 12, 1.5, cps)
	fonts[.Mono] = load_font({"C:/Windows/Fonts/CascadiaMono.ttf", "C:/Windows/Fonts/consola.ttf"}, 15, 0, cps)
	fonts[.Icon] = load_font({"C:/Windows/Fonts/SegoeIcons.ttf", "C:/Windows/Fonts/segmdl2.ttf"}, 16, 0, ICON_CODEPOINTS[:])
}

mu_font :: #force_inline proc(k: Font_Kind) -> mu.Font {
	return mu.Font(&fonts[k])
}

to_rl_color :: #force_inline proc(c: mu.Color) -> rl.Color {
	return rl.Color{c.r, c.g, c.b, c.a}
}

draw_round :: proc(r: rl.Rectangle, radius: f32, c: rl.Color) {
	m := min(r.width, r.height)
	if m <= 0 {return}
	rl.DrawRectangleRounded(r, min(1, 2 * radius / m), 8, c)
}

r_input :: proc(ctx: ^mu.Context, drag_active: bool) {
	mx := rl.GetMouseX()
	my := rl.GetMouseY()
	mu.input_mouse_move(ctx, mx, my)

	wheel := rl.GetMouseWheelMoveV()
	if wheel.x != 0 || wheel.y != 0 {
		mu.input_scroll(ctx, i32(-wheel.x * 30), i32(-wheel.y * 30))
	}

	mouse_pairs := [?]struct {
		rl_btn: rl.MouseButton,
		mu_btn: mu.Mouse,
	}{{.LEFT, .LEFT}, {.RIGHT, .RIGHT}, {.MIDDLE, .MIDDLE}}
	for p in mouse_pairs {
		if !drag_active {
			if rl.IsMouseButtonPressed(p.rl_btn) {
				mu.input_mouse_down(ctx, mx, my, p.mu_btn)
			}
			if rl.IsMouseButtonReleased(p.rl_btn) {
				mu.input_mouse_up(ctx, mx, my, p.mu_btn)
			}
		}
	}

	for {
		ch := rl.GetCharPressed()
		if ch == 0 {break}
		buf, n := utf8.encode_rune(ch)
		mu.input_text(ctx, string(buf[:n]))
	}

	key_pairs := [?]struct {
		rl_key: rl.KeyboardKey,
		mu_key: mu.Key,
	} {
		{.LEFT_SHIFT, .SHIFT},
		{.RIGHT_SHIFT, .SHIFT},
		{.LEFT_CONTROL, .CTRL},
		{.RIGHT_CONTROL, .CTRL},
		{.LEFT_ALT, .ALT},
		{.RIGHT_ALT, .ALT},
		{.BACKSPACE, .BACKSPACE},
		{.DELETE, .DELETE},
		{.ENTER, .RETURN},
		{.KP_ENTER, .RETURN},
		{.LEFT, .LEFT},
		{.RIGHT, .RIGHT},
		{.HOME, .HOME},
		{.END, .END},
		{.A, .A},
		{.X, .X},
		{.C, .C},
		{.V, .V},
	}
	for k in key_pairs {
		if rl.IsKeyPressed(k.rl_key) || rl.IsKeyPressedRepeat(k.rl_key) {
			mu.input_key_down(ctx, k.mu_key)
		}
		if rl.IsKeyReleased(k.rl_key) {
			mu.input_key_up(ctx, k.mu_key)
		}
	}
}

r_draw_shape :: proc(g: Glyph, rect: mu.Rect, color: mu.Color) {
	r := rl.Rectangle{f32(rect.x), f32(rect.y), f32(rect.w), f32(rect.h)}
	c := to_rl_color(color)
	#partial switch g {
	case .Round:
		draw_round(r, 7, c)
	case .Round_Lg:
		draw_round(r, 12, c)
	case .Pill:
		draw_round(r, min(r.width, r.height) / 2, c)
	case .Circle:
		rl.DrawCircleV({r.x + r.width / 2, r.y + r.height / 2}, min(r.width, r.height) / 2, c)
	case .Grip:
		cx := r.x + r.width / 2
		cy := r.y + r.height / 2
		for row in -1 ..= 1 {
			for col in 0 ..< 2 {
				rl.DrawCircleV({cx - 2.5 + f32(col) * 5, cy + f32(row) * 5}, 1.6, c)
			}
		}
	case .Shadow:
		draw_round({r.x - 2, r.y + 1, r.width + 4, r.height + 6}, 14, {c.r, c.g, c.b, c.a / 2})
		draw_round({r.x, r.y + 3, r.width, r.height}, 12, c)
	case .Stop:
		draw_round({r.x + r.width / 2 - 5, r.y + r.height / 2 - 5, 10, 10}, 2.5, c)
	case:
		f := &fonts[.Icon]
		cp := ICON_CODEPOINTS[int(g) - int(Glyph.Play)]
		size := i32(f.size)
		pos := rl.Vector2{f32(rect.x + (rect.w - size) / 2), f32(rect.y + (rect.h - size) / 2)}
		rl.DrawTextCodepoint(f.rl, cp, pos, f.size, c)
	}
}

r_draw :: proc(ctx: ^mu.Context) {
	sw := rl.GetScreenWidth()
	sh := rl.GetScreenHeight()
	rl.BeginScissorMode(0, 0, sw, sh)
	defer rl.EndScissorMode()

	cmd: ^mu.Command
	for mu.next_command(ctx, &cmd) {
		switch v in cmd.variant {
		case ^mu.Command_Text:
			f := (^Font)(v.font)
			cstr := strings.clone_to_cstring(v.str, context.temp_allocator)
			rl.DrawTextEx(f.rl, cstr, rl.Vector2{f32(v.pos.x), f32(v.pos.y)}, f.size, f.spacing, to_rl_color(v.color))
		case ^mu.Command_Rect:
			rl.DrawRectangle(v.rect.x, v.rect.y, v.rect.w, v.rect.h, to_rl_color(v.color))
		case ^mu.Command_Icon:
			r_draw_shape(Glyph(v.id), v.rect, v.color)
		case ^mu.Command_Clip:
			rl.EndScissorMode()
			rl.BeginScissorMode(v.rect.x, v.rect.y, v.rect.w, v.rect.h)
		case ^mu.Command_Jump:
		// handled by next_command
		}
	}
}
