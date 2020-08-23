module framed.win32;
import framed;

// dfmt off
version (Windows):
// dfmt on

import core.stdc.stdlib;
import core.sys.windows.windows;

nothrow:

private:

struct LinkedNode {
	Event ev;
	LinkedNode* next;
}

struct Win32Data {
	HWND hwnd;
	uint[] buffer;
	LinkedNode* evqHead;
	LinkedNode* evqTail;
	int rWidth;
	int rHeight;
	bool[cast(size_t) KeyCode.Menu + 1] keysDown;
	bool mouseOutside;
	bool cursorTracked;
}

void advanceQueue(Win32Data* self) {
	MSG msg;
	while (PeekMessageW(&msg, self.hwnd, 0, 0, PM_REMOVE)) {
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}
}

void addToEvq(Win32Data* self, Event ev) {
	LinkedNode* node = cast(LinkedNode*) malloc(LinkedNode.sizeof);
	node.ev = ev;
	node.next = null;
	if (self.evqTail == null) {
		self.evqHead = node;
	}
	else {
		self.evqTail.next = node;
	}
	self.evqTail = node;
}

int getWidth(Win32Data* self) {
	RECT r;
	if (!GetClientRect(self.hwnd, &r)) {
		return 0;
	}
	return cast(int)(r.right - r.left);
}

int getHeight(Win32Data* self) {
	RECT r;
	if (!GetClientRect(self.hwnd, &r)) {
		return 0;
	}
	return cast(int)(r.bottom - r.top);
}

void close(Win32Data* self) {
	DestroyWindow(self.hwnd);
	free(self);
}

void update(Win32Data* self, uint[] buffer) {
	self.buffer = buffer;
	InvalidateRect(self.hwnd, NULL, TRUE);
}

void yield(Win32Data* self) {
	MSG msg;
	while (self.evqHead == null) {
		GetMessage(&msg, self.hwnd, 0, 0);
		TranslateMessage(&msg);
		DispatchMessage(&msg);
	}
}

bool evqEmpty(Win32Data* self) {
	advanceQueue(self);
	return self.evqHead == null;
}

Event evqFront(Win32Data* self) {
	advanceQueue(self);
	assert(self.evqHead != null);
	return self.evqHead.ev;
}

void evqPopFront(Win32Data* self) {
	advanceQueue(self);
	auto next = self.evqHead.next;
	free(self.evqHead);
	self.evqHead = next;
	if (self.evqHead == null) {
		self.evqTail = null;
	}
}

int translateKey(WPARAM wParam, LPARAM lParam) {
	WPARAM vk = wParam;
	UINT scancode = (lParam >> 16) & 0xFF;
	int extended = (lParam >> 24) & 1;

	switch (wParam) {
	case VK_SHIFT:
		vk = MapVirtualKey(scancode, MAPVK_VSC_TO_VK_EX);
		break;
	case VK_CONTROL:
		vk = extended ? VK_RCONTROL : VK_LCONTROL;
		break;
	case VK_MENU:
		vk = extended ? VK_RMENU : VK_LMENU;
		break;
	default:
		break;
	}

	// dfmt off
	switch (vk) {
	case VK_SPACE: return KeyCode.Space;
	case VK_OEM_7: return KeyCode.Quote;
	case VK_OEM_COMMA: return KeyCode.Comma;
	case VK_OEM_MINUS: return KeyCode.Minus;
	case VK_OEM_PERIOD: return KeyCode.Period;
	case VK_OEM_2: return KeyCode.Slash;
	case '0': .. case '9': return KeyCode.D0 + cast(int)(wParam - '0');
	case VK_OEM_1: return KeyCode.Semicolon;
	case VK_OEM_PLUS: return KeyCode.Equal;
	case 'A': .. case 'Z': return KeyCode.A + cast(int)(wParam - 'A');
	case VK_OEM_4: return KeyCode.LeftBracket;
	case VK_OEM_5: return KeyCode.Backslash;
	case VK_OEM_6: return KeyCode.RightBracket;
	case VK_OEM_3: return KeyCode.Backtick;
	case VK_ESCAPE: return KeyCode.Escape;
	case VK_RETURN: return KeyCode.Enter;
	case VK_TAB: return KeyCode.Tab;
	case VK_BACK: return KeyCode.Backspace;
	case VK_INSERT: return KeyCode.Insert;
	case VK_DELETE: return KeyCode.Delete;
	case VK_RIGHT: return KeyCode.Right;
	case VK_LEFT: return KeyCode.Left;
	case VK_DOWN: return KeyCode.Down;
	case VK_UP: return KeyCode.Up;
	case VK_PRIOR: return KeyCode.PageUp;
	case VK_NEXT: return KeyCode.PageDown;
	case VK_HOME: return KeyCode.Home;
	case VK_END: return KeyCode.End;
	case VK_CAPITAL: return KeyCode.CapsLock;
	case VK_SCROLL: return KeyCode.ScrollLock;
	case VK_NUMLOCK: return KeyCode.NumLock;
	case VK_SNAPSHOT: return KeyCode.PrintScreen;
	case VK_PAUSE: return KeyCode.Pause;
	case VK_F1: .. case VK_F24: return KeyCode.F1 + cast(int)(wParam - VK_F1);
	case VK_NUMPAD0: .. case VK_NUMPAD9: return KeyCode.Numpad0 + cast(int)(wParam - VK_NUMPAD0);
	case VK_DECIMAL: return KeyCode.NumpadPeriod;
	case VK_DIVIDE: return KeyCode.NumpadSlash;
	case VK_MULTIPLY: return KeyCode.NumpadMultiply;
	case VK_SUBTRACT: return KeyCode.NumpadMinus;
	case VK_ADD: return KeyCode.NumpadPlus;
	// TODO: KeyCode.NumpadEqual
	case VK_LSHIFT: return KeyCode.LeftShift;
	case VK_LCONTROL: return KeyCode.LeftCtrl;
	case VK_LMENU: return KeyCode.LeftAlt;
	case VK_LWIN: return KeyCode.LeftSuper;
	case VK_RSHIFT: return KeyCode.RightShift;
	case VK_RCONTROL: return KeyCode.RightCtrl;
	case VK_RMENU: return KeyCode.RightAlt;
	case VK_RWIN: return KeyCode.RightSuper;
	case VK_APPS: return KeyCode.Menu;
	default:
		import core.stdc.stdio : printf;
		debug printf("Unrecognized virtual key code: %x\n", cast(int) wParam);
		return -1;
	}
	// dfmt on
}

extern (Windows) LRESULT wndProc(HWND hwnd, UINT Msg, WPARAM wParam, LPARAM lParam) nothrow {
	Win32Data* self = cast(Win32Data*) GetWindowLongPtr(hwnd, GWLP_USERDATA);

	if (self == null) {
		return DefWindowProc(hwnd, Msg, wParam, lParam);
	}

	switch (Msg) {
	case WM_CLOSE:
		addToEvq(self, Event(EventType.CloseRequest));
		return 0;
	case WM_ENTERSIZEMOVE:
		self.rWidth = getWidth(self);
		self.rHeight = getHeight(self);
		break;
	case WM_EXITSIZEMOVE:
		auto ev = Event(EventType.Resize);
		if (self.rWidth != getWidth(self) || self.rHeight != getHeight(self)) {
			ev.width = self.rWidth;
			ev.height = self.rHeight;
			self.rWidth = getWidth(self);
			self.rHeight = getHeight(self);
			addToEvq(self, ev);
		}
		break;
	case WM_SIZE:
		if (wParam == 0 && self.rWidth != 0 && self.rHeight != 0)
			break;
		auto ev = Event(EventType.Resize);
		if (self.rWidth != getWidth(self) || self.rHeight != getHeight(self)) {
			ev.width = self.rWidth;
			ev.height = self.rHeight;
			self.rWidth = getWidth(self);
			self.rHeight = getHeight(self);
			addToEvq(self, ev);
		}
		break;
	case WM_MOUSEMOVE:
		if (!self.cursorTracked) {
			self.cursorTracked = true;

			TRACKMOUSEEVENT track;
			track.cbSize = TRACKMOUSEEVENT.sizeof;
			track.dwFlags = TME_LEAVE;
			track.hwndTrack = self.hwnd;
			track.dwHoverTime = 0;

			TrackMouseEvent(&track);
		}

		auto ev = Event(EventType.MouseMove);
		ev.x = cast(int)(lParam & 0xFFFF);
		ev.y = cast(int)(lParam >> 16);
		if (self.mouseOutside) {
			self.mouseOutside = false;
			addToEvq(self, Event(EventType.MouseEnter));
		}
		addToEvq(self, ev);
		break;
	case WM_MOUSELEAVE:
		self.mouseOutside = true;
		self.cursorTracked = false;
		addToEvq(self, Event(EventType.MouseLeave));
		break;
	case WM_LBUTTONDOWN:
	case WM_MBUTTONDOWN:
	case WM_RBUTTONDOWN:
	case WM_LBUTTONUP:
	case WM_MBUTTONUP:
	case WM_RBUTTONUP:
		MouseButton button;

		if (Msg == WM_LBUTTONDOWN || Msg == WM_LBUTTONUP) {
			button = MouseButton.Left;
		}
		else if (Msg == WM_MBUTTONDOWN || Msg == WM_MBUTTONUP) {
			button = MouseButton.Middle;
		}
		else if (Msg == WM_RBUTTONDOWN || Msg == WM_RBUTTONUP) {
			button = MouseButton.Right;
		}

		EventType type;

		if (Msg == WM_LBUTTONDOWN || Msg == WM_MBUTTONDOWN
			|| Msg == WM_RBUTTONDOWN) {
			type = EventType.MouseDown;
		}
		else {
			type = EventType.MouseUp;
		}

		auto ev = Event(type);
		ev.button = button;
		addToEvq(self, ev);

		return 0;
	case WM_KEYDOWN:
	case WM_SYSKEYDOWN:
		auto ev = Event(EventType.KeyDown);
		int key = translateKey(wParam, lParam);
		if (key == -1) {
			break;
		}
		ev.key = cast(KeyCode) key;
		if (self.keysDown[ev.key]) {
			ev.type = EventType.KeyRepeat;
		}
		else {
			self.keysDown[ev.key] = true;
		}
		addToEvq(self, ev);
		break;
	case WM_KEYUP:
	case WM_SYSKEYUP:
		auto ev = Event(EventType.KeyUp);
		int key = translateKey(wParam, lParam);
		if (key == -1) {
			break;
		}
		ev.key = cast(KeyCode) key;
		self.keysDown[ev.key] = false;
		addToEvq(self, ev);
		break;
	case WM_ERASEBKGND:
		return TRUE;
	case WM_PAINT:
		PAINTSTRUCT ps;
		HDC hdc = BeginPaint(hwnd, &ps);

		RECT r;
		GetClientRect(hwnd, &r);

		int width = cast(int)(r.right - r.left);
		int height = cast(int)(r.bottom - r.top);

		if (width == 0 || height == 0) {
			return 0;
		}

		BYTE[BITMAPINFO.bmiColors.offsetof + (3 * DWORD.sizeof)] bitmapinfo;
		BITMAPINFOHEADER* bih = cast(BITMAPINFOHEADER*) bitmapinfo;
		bih.biSize = BITMAPINFOHEADER.sizeof;
		bih.biWidth = width;
		bih.biHeight = height;
		bih.biPlanes = 1;
		bih.biBitCount = 32;
		bih.biCompression = BI_BITFIELDS;
		DWORD* pMasks = cast(DWORD*)&bitmapinfo[bih.biSize];
		pMasks[0] = 0xFF0000;
		pMasks[1] = 0x00FF00;
		pMasks[2] = 0x0000FF;

		if (self.buffer.length == width * cast(size_t) height) {
			StretchDIBits(hdc, 0, 0, width, height, 0, height + 1, width,
					-height, cast(void*) self.buffer.ptr,
					cast(BITMAPINFO*) bih, DIB_RGB_COLORS, SRCCOPY);
		}

		EndPaint(hwnd, &ps);

		return 0;
	default:
		break;
	}

	return DefWindowProc(hwnd, Msg, wParam, lParam);
}

HMODULE hInstance;

bool win32Inited = false;
void win32Init() {
	if (win32Inited)
		return;

	win32Inited = true;

	hInstance = GetModuleHandle(NULL);

	WNDCLASSEX wc;
	wc.cbSize = WNDCLASSEX.sizeof;
	wc.style = 0;
	wc.lpfnWndProc = &wndProc;
	wc.cbClsExtra = 0;
	wc.cbWndExtra = 0;
	wc.hInstance = hInstance;
	wc.hIcon = LoadIcon(NULL, IDI_APPLICATION);
	wc.hCursor = LoadCursor(NULL, IDC_ARROW);
	wc.hbrBackground = cast(HBRUSH) GetStockObject(BLACK_BRUSH);
	wc.lpszMenuName = NULL;
	wc.lpszClassName = "WindowClass"w.ptr;
	wc.hIconSm = LoadIcon(NULL, IDI_APPLICATION);

	if (!RegisterClassEx(&wc)) {
		assert(0);
	}
}

wchar* toWStr(string s) {
	int length = MultiByteToWideChar(CP_UTF8, MB_PRECOMPOSED, s.ptr, cast(int) s.length, NULL, 0,);
	wchar* result = cast(wchar*) calloc(length, wchar.sizeof);
	MultiByteToWideChar(CP_UTF8, MB_PRECOMPOSED, s.ptr, cast(int) s.length, result, length,);
	return result;
}

package:

Framebuffer win32OpenWindow(WindowOptions options) {
	WindowData* data = cast(WindowData*) malloc(WindowData.sizeof);
	data.getWidth = cast(int function(void*) nothrow)&getWidth;
	data.getHeight = cast(int function(void*) nothrow)&getHeight;
	data.close = cast(void function(void*) nothrow)&close;
	data.update = cast(void function(void*, uint[]) nothrow)&update;
	data.yield = cast(void function(void*) nothrow)&yield;
	data.evqEmpty = cast(bool function(void*) nothrow)&evqEmpty;
	data.evqFront = cast(Event function(void*) nothrow)&evqFront;
	data.evqPopFront = cast(void function(void*) nothrow)&evqPopFront;

	win32Init();

	wchar* wtitle = options.title.toWStr;

	RECT r;
	r.left = 0;
	r.top = 0;
	r.right = options.initialWidth;
	r.bottom = options.initialHeight;
	AdjustWindowRect(&r, WS_OVERLAPPEDWINDOW, FALSE);

	// dfmt off
	HWND hwnd = CreateWindowW(
		"WindowClass"w.ptr,
		wtitle,
		WS_OVERLAPPEDWINDOW,
		0, 0,
		r.right - r.left, r.bottom - r.top,
		GetDesktopWindow(),
		NULL, hInstance, NULL,
	);
	// dfmt on

	free(wtitle);

	Win32Data* self = cast(Win32Data*) calloc(Win32Data.sizeof, 1);
	self.hwnd = hwnd;
	self.rWidth = options.initialWidth;
	self.rHeight = options.initialHeight;
	self.mouseOutside = true;
	self.cursorTracked = false;
	self.buffer = null;
	self.evqHead = null;
	self.evqTail = null;

	SetWindowLongPtr(hwnd, GWLP_USERDATA, cast(LONG_PTR) self);

	data.udata = self;

	ShowWindow(hwnd, SW_SHOW);

	return Framebuffer(FramebufferType.Window, data);
}
