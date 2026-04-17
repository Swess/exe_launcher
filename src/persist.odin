package launcher

import "core:encoding/json"
import "core:os"
import "core:path/filepath"

CONFIG_FILENAME :: "launcher_config.json"

PConfig :: struct {
	args: string,
}

PGroup :: struct {
	name:    string,
	configs: []PConfig,
}

PRoot :: struct {
	exe_path: string,
	groups:   []PGroup,
}

config_path :: proc(allocator := context.allocator) -> string {
	exe := "."
	if len(os.args) > 0 { exe = os.args[0] }
	abs, abs_err := filepath.abs(exe, context.temp_allocator)
	if abs_err != nil { abs = exe }
	dir := filepath.dir(abs, context.temp_allocator)
	joined, _ := filepath.join({dir, CONFIG_FILENAME}, allocator)
	return joined
}

persist_save :: proc(app: ^App) {
	path := config_path(context.temp_allocator)

	groups := make([]PGroup, len(app.groups), context.temp_allocator)
	for &g, gi in app.groups {
		configs := make([]PConfig, len(g.configs), context.temp_allocator)
		for &c, ci in g.configs {
			configs[ci] = PConfig{ args = string(c.args_buf[:c.args_len]) }
		}
		groups[gi] = PGroup{
			name    = string(g.name_buf[:g.name_len]),
			configs = configs,
		}
	}

	root := PRoot{
		exe_path = string(app.exe_buf[:app.exe_len]),
		groups   = groups,
	}

	opts := json.Marshal_Options{ pretty = true, use_spaces = true, spaces = 2 }
	bytes, err := json.marshal(root, opts, context.temp_allocator)
	if err != nil { return }

	_ = os.write_entire_file(path, bytes)
}

persist_load :: proc(app: ^App) {
	path := config_path(context.temp_allocator)
	data, rerr := os.read_entire_file(path, context.temp_allocator)
	if rerr != nil { return }

	root: PRoot
	if err := json.unmarshal(data, &root, .JSON, context.temp_allocator); err != nil {
		return
	}

	set_buf(app.exe_buf[:], &app.exe_len, root.exe_path)

	for &g in app.groups {
		delete(g.configs)
	}
	clear(&app.groups)

	for pg in root.groups {
		g: Group
		set_buf(g.name_buf[:], &g.name_len, pg.name)
		for pc in pg.configs {
			c: Config
			set_buf(c.args_buf[:], &c.args_len, pc.args)
			append(&g.configs, c)
		}
		append(&app.groups, g)
	}
}
