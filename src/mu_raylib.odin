package launcher

import "core:strings"
import "core:unicode/utf8"
import mu "vendor:microui"
import rl "vendor:raylib"

FONT_SIZE :: f32(20)
FONT_SPACING :: f32(1)

r_init_font :: proc() -> rl.Font {
	font := rl.LoadFontEx("C:/Windows/Fonts/segoeui.ttf", i32(FONT_SIZE), nil, 0)
	rl.SetTextureFilter(font.texture, .BILINEAR)
	return font
}

r_build_atlas :: proc() -> rl.Texture2D {
	pixels := make(
		[]u8,
		mu.DEFAULT_ATLAS_WIDTH * mu.DEFAULT_ATLAS_HEIGHT * 4,
		context.temp_allocator,
	)
	for a, i in mu.default_atlas_alpha {
		pixels[i * 4 + 0] = 255
		pixels[i * 4 + 1] = 255
		pixels[i * 4 + 2] = 255
		pixels[i * 4 + 3] = a
	}
	img := rl.Image {
		data    = raw_data(pixels),
		width   = mu.DEFAULT_ATLAS_WIDTH,
		height  = mu.DEFAULT_ATLAS_HEIGHT,
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}
	return rl.LoadTextureFromImage(img)
}

to_rl_color :: #force_inline proc(c: mu.Color) -> rl.Color {
	return rl.Color{c.r, c.g, c.b, c.a}
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

r_draw :: proc(ctx: ^mu.Context, atlas: rl.Texture2D) {
	sw := rl.GetScreenWidth()
	sh := rl.GetScreenHeight()
	rl.BeginScissorMode(0, 0, sw, sh)
	defer rl.EndScissorMode()

	cmd: ^mu.Command
	for mu.next_command(ctx, &cmd) {
		switch v in cmd.variant {
		case ^mu.Command_Text:
			f := (^rl.Font)(v.font)
			cstr := strings.clone_to_cstring(v.str, context.temp_allocator)
			rl.DrawTextEx(
				f^,
				cstr,
				rl.Vector2{f32(v.pos.x), f32(v.pos.y)},
				FONT_SIZE,
				FONT_SPACING,
				to_rl_color(v.color),
			)
		case ^mu.Command_Rect:
			rl.DrawRectangle(v.rect.x, v.rect.y, v.rect.w, v.rect.h, to_rl_color(v.color))
		case ^mu.Command_Icon:
			src := mu.default_atlas[int(v.id)]
			x := v.rect.x + (v.rect.w - src.w) / 2
			y := v.rect.y + (v.rect.h - src.h) / 2
			draw_atlas_quad(atlas, src, x, y, to_rl_color(v.color))
		case ^mu.Command_Clip:
			rl.EndScissorMode()
			rl.BeginScissorMode(v.rect.x, v.rect.y, v.rect.w, v.rect.h)
		case ^mu.Command_Jump:
		// handled by next_command
		}
	}
}

draw_atlas_quad :: proc(atlas: rl.Texture2D, src: mu.Rect, x, y: i32, color: rl.Color) {
	rl.DrawTexturePro(
		atlas,
		rl.Rectangle{f32(src.x), f32(src.y), f32(src.w), f32(src.h)},
		rl.Rectangle{f32(x), f32(y), f32(src.w), f32(src.h)},
		rl.Vector2{0, 0},
		0,
		color,
	)
}
