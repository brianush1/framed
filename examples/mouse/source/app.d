import std.stdio;
import std.random;
import std.parallelism;
import framed;

void main() {
	WindowOptions opts = WindowOptions("Mouse 🐭🖱");
	opts.resizable = false;
	Framebuffer win = openWindow(opts);
	bool running = true;
	bool colored = false;
	uint[] data;
	int mouseX, mouseY;
	bool mouseIn = false;
	bool mouseDown = false;
	while (running) {
		if (data.length != win.width * win.height) {
			// resize buffer if necessary
			data = new uint[win.width * win.height];
		}

		// fill with solid background
		data[] = mouseIn ? 0x007FFF : 0x00;

		// fill rectangle near mouse
		foreach (x; mouseX - 10 .. mouseX + 10) {
			foreach (y; mouseY - 10 .. mouseY + 10) {
				if (x < 0 || y < 0 || x >= win.width || y >= win.height) {
					continue;
				}
				data[y * win.width + x] = mouseDown ? 0xFFFFFF : 0xFF7F00;
			}
		}

		win.update(data); // set the display buffer

		win.yield(); // wait for new events
		foreach (event; win.eventQueue) {
			switch (event.type) {
			case EventType.CloseRequest:
				running = false;
				break;
			case EventType.MouseMove:
				mouseX = event.x;
				mouseY = event.y;
				break;
			case EventType.MouseEnter:
				mouseIn = true;
				break;
			case EventType.MouseLeave:
				mouseIn = false;
				break;
			case EventType.MouseDown:
				win.cursor = Cursors.None;
				mouseDown = true;
				break;
			case EventType.MouseUp:
				win.cursor = Cursors.Arrow;
				mouseDown = false;
				break;
			default:
				break;
			}
		}
	}
}
