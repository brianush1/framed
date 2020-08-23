import std.stdio;
import std.random;
import std.parallelism;
import framed;

void main() {
	Framebuffer win = openWindow("Noise");
	bool running = true;
	bool colored = false;
	uint[] data;
	while (running) {
		if (data.length != win.width * win.height) {
			// resize buffer if necessary
			data = new uint[win.width * win.height];
		}

		// fill with random noise
		if (colored) {
			foreach (i, ref elem; data.parallel) {
				elem = uniform!"[]"(0x404040, 0xFFFFFF);
			}
		}
		else {
			foreach (i, ref elem; data.parallel) {
				elem = 0x010101 * uniform!"[]"(0x00, 0xFF);
			}
		}

		win.update(data); // set the display buffer

		foreach (event; win.eventQueue) {
			switch (event.type) {
			case EventType.CloseRequest:
				running = false;
				break;
			case EventType.Resize:
				// writeln("Old size: ", event.width, ", ", event.height);
				// writeln("New size: ", win.width, ", ", win.height);
				break;
			case EventType.KeyDown:
				if (event.key == KeyCode.C) {
					colored = !colored;
				}
				// writeln("Key ", event.key, " down");
				break;
			case EventType.KeyRepeat:
				// writeln("Key ", event.key, " repeat");
				break;
			case EventType.KeyUp:
				// writeln("Key ", event.key, " up");
				break;
			default:
				break;
			}
		}
	}
}
