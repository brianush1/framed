module framed;
import framed.win32;
import core.stdc.stdlib;

version (Windows) {
	import core.sys.windows.windows;

	enum FramedWindowSupport = true;
}
else {
	enum FramedWindowSupport = false;
}

nothrow:

package enum FramebufferType {
	Null,
	Window,
}

package struct WindowData {
nothrow:

	void* udata;
	int function(void*) getWidth;
	int function(void*) getHeight;
	Cursors function(void*) getCursor;
	void function(void*, Cursors) setCursor;
	void function(void*) close;
	void function(void*, uint[]) update;
	void function(void*) yield;
	bool function(void*) evqEmpty;
	Event function(void*) evqFront;
	void function(void*) evqPopFront;
	version (Windows) {
		HWND function(void*) getHwnd;
	}
}

enum Cursors {
	None,
	Arrow,
}

enum EventType {
	CloseRequest,
	Resize,
	KeyDown,
	KeyRepeat,
	KeyUp,
	MouseMove,
	MouseDown,
	MouseUp,
	MouseEnter,
	MouseLeave,
}

enum MouseButton {
	Left,
	Middle,
	Right,
}

// dfmt off
enum KeyCode {
	Space,
	Quote,
	Comma,
	Minus,
	Period,
	Slash,
	D0, D1, D2, D3, D4, D5, D6, D7, D8, D9,
	Semicolon,
	Equal,
	A, B, C, D, E, F, G, H, I, J, K, L, M,
	N, O, P, Q, R, S, T, U, V, W, X, Y, Z,
	LeftBracket,
	Backslash,
	RightBracket,
	Backtick,
	Escape,
	Enter,
	Tab,
	Backspace,
	Insert,
	Delete,
	Right,
	Left,
	Down,
	Up,
	PageUp,
	PageDown,
	Home,
	End,
	CapsLock,
	ScrollLock,
	NumLock,
	PrintScreen,
	Pause,
	F1, F2, F3, F4, F5, F6, F7, F8, F9, F10,
	F11, F12, F13, F14, F15, F16, F17, F18,
	F19, F20, F21, F22, F23, F24, F25,
	Numpad0, Numpad1, Numpad2,
	Numpad3, Numpad4, Numpad5,
	Numpad6, Numpad7, Numpad8,
	Numpad9, NumpadPeriod, NumpadSlash, NumpadMultiply,
	NumpadMinus, NumpadPlus, NumpadEnter, NumpadEqual,
	LeftShift, LeftCtrl, LeftAlt, LeftSuper,
	RightShift, RightCtrl, RightAlt, RightSuper,
	Menu,
}
// dfmt on

struct Event {
nothrow:
	EventType type;
	long a;
	long b;

	int width() const @property {
		return cast(int) a;
	}

	void width(int value) @property {
		a = (cast(ulong) height << 32UL) | cast(uint) value;
	}

	int height() const @property {
		return cast(int)(a >> 32UL);
	}

	void height(int value) @property {
		a = (cast(ulong) value << 32UL) | cast(uint) width;
	}

	int x() const @property {
		return width;
	}

	void x(int value) @property {
		width = value;
	}

	int y() const @property {
		return height;
	}

	void y(int value) @property {
		height = value;
	}

	MouseButton button() const @property {
		return cast(MouseButton) b;
	}

	void button(MouseButton value) @property {
		b = cast(long) value;
	}

	KeyCode key() const @property {
		return cast(KeyCode) b;
	}

	void key(KeyCode value) @property {
		b = cast(long) value;
	}
}

package struct EventRange {
nothrow:

	Framebuffer buffer;

	bool empty() {
		final switch (buffer.type) {
		case FramebufferType.Null:
			return true;
		case FramebufferType.Window:
			return buffer.window.evqEmpty(buffer.window.udata);
		}
	}

	Event front() {
		switch (buffer.type) {
		case FramebufferType.Window:
			return buffer.window.evqFront(buffer.window.udata);
		default:
			assert(0);
		}
	}

	void popFront() {
		final switch (buffer.type) {
		case FramebufferType.Null:
			break;
		case FramebufferType.Window:
			buffer.window.evqPopFront(buffer.window.udata);
			break;
		}
	}

}

struct Framebuffer {
nothrow:

	private FramebufferType type = FramebufferType.Null;
	private void* data;
	private int* count;

	package this(FramebufferType type, void* data) {
		this.type = type;
		this.data = data;
		count = cast(int*) malloc(int.sizeof);
		*count = 1;
	}

	this(ref return scope inout(Framebuffer) rhs) inout {
		type = rhs.type;
		data = rhs.data;
		count = rhs.count;
		*cast(int*) count += 1;
	}

	~this() {
		if (count == null)
			return;
		*count -= 1;
		if (*count == 0) {
			final switch (type) {
			case FramebufferType.Null:
				break;
			case FramebufferType.Window:
				window.close(window.udata);
			}
			free(data);
			free(count);
		}
	}

	private WindowData* window() inout {
		return cast(WindowData*) data;
	}

	int width() {
		final switch (type) {
		case FramebufferType.Null:
			return 0;
		case FramebufferType.Window:
			return window.getWidth(window.udata);
		}
	}

	int height() {
		final switch (type) {
		case FramebufferType.Null:
			return 0;
		case FramebufferType.Window:
			return window.getHeight(window.udata);
		}
	}

	void update(uint[] buffer) {
		assert(buffer.length == width * cast(size_t) height, "Wrong buffer size");
		final switch (type) {
		case FramebufferType.Null:
			break;
		case FramebufferType.Window:
			window.update(window.udata, buffer);
			break;
		}
	}

	void yield() {
		final switch (type) {
		case FramebufferType.Null:
			break;
		case FramebufferType.Window:
			window.yield(window.udata);
			break;
		}
	}

	Cursors cursor() const @property {
		final switch (type) {
		case FramebufferType.Null:
			return Cursors.None;
		case FramebufferType.Window:
			return window.getCursor(window.udata);
		}
	}

	void cursor(Cursors value) @property {
		final switch (type) {
		case FramebufferType.Null:
			break;
		case FramebufferType.Window:
			window.setCursor(window.udata, value);
			break;
		}
	}

	EventRange eventQueue() {
		return EventRange(this);
	}

}

struct WindowOptions {
nothrow:

	int initialWidth = 640;
	int initialHeight = 480;
	bool resizable = true;
	string title = "Untitled window";

	this(string title) {
		this.title = title;
	}

	this(int initialWidth, int initialHeight) {
		this.initialWidth = initialWidth;
		this.initialHeight = initialHeight;
	}

	this(string title, int initialWidth, int initialHeight) {
		this.title = title;
		this.initialWidth = initialWidth;
		this.initialHeight = initialHeight;
	}
}

static if (FramedWindowSupport) {
	version (Windows) {
		Framebuffer openWindow(WindowOptions options) {
			return win32OpenWindow(options);
		}

		HWND getWin32Hwnd(Framebuffer buffer) {
			return buffer.window.getHwnd(buffer.window.udata);
		}
	}
	else {
		static assert(0);
	}

	Framebuffer openWindow(Args...)(Args args) {
		return openWindow(WindowOptions(args));
	}
}
