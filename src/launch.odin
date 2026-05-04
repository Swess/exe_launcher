package launcher

import "core:fmt"
import "core:strings"
import win "core:sys/windows"
import "core:time"

launch_config :: proc(app: ^App, exe_path, args: string) -> bool {
	if len(exe_path) == 0 {
		return false
	}

	cmdline: string
	if len(args) > 0 {
		cmdline = fmt.tprintf("\"%s\" %s", exe_path, args)
	} else {
		cmdline = fmt.tprintf("\"%s\"", exe_path)
	}

	exe_w := win.utf8_to_wstring(exe_path, context.temp_allocator)
	cmd_w := win.utf8_to_wstring(cmdline, context.temp_allocator)
	if exe_w == nil || cmd_w == nil {
		return false
	}

	si: win.STARTUPINFOW
	si.cb = size_of(si)
	pi: win.PROCESS_INFORMATION

	ok := win.CreateProcessW(exe_w, cmd_w, nil, nil, false, 0, nil, nil, &si, &pi)
	if !ok {
		return false
	}

	win.CloseHandle(pi.hThread)

	append(
		&app.running,
		Running {
			handle = rawptr(pi.hProcess),
			pid = u32(pi.dwProcessId),
			started = time.now(),
			cmdline = strings.clone(cmdline),
		},
	)
	return true
}

launch_poll :: proc(app: ^App) {
	for i := len(app.running) - 1; i >= 0; i -= 1 {
		r := &app.running[i]
		code := win.WaitForSingleObject(win.HANDLE(r.handle), 0)
		if code == win.WAIT_OBJECT_0 {
			win.CloseHandle(win.HANDLE(r.handle))
			delete(r.cmdline)
			unordered_remove(&app.running, i)
		}
	}
}

kill_running :: proc(r: ^Running) {
	win.TerminateProcess(win.HANDLE(r.handle), 1)
	// launch_poll will reap the handle + free cmdline next frame.
}
