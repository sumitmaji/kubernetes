import threading
import socketio  # pip install "python-socketio[client]"

class SocketBridge:
    def __init__(self, socketio_ws, target_host, target_port):
        self.socketio_ws = socketio_ws  # Flask-SocketIO instance
        self.target_host = target_host
        self.target_port = target_port
        self.sio = socketio.Client()
        self.thread = None

    def start(self, batch_id):
        if self.thread and self.thread.is_alive():
            return
        self.thread = threading.Thread(target=self._run, args=(batch_id,), daemon=True)
        self.thread.start()

    def _run(self, batch_id):
        @self.sio.event
        def connect():
            self.sio.emit("join", {"batch_id": batch_id})

        @self.sio.on("results")
        def on_results(data):
            # Forward as "result" to match React client expectation
            self.socketio_ws.emit("result", data, room=batch_id)

        try:
            self.sio.connect(f"http://{self.target_host}:{self.target_port}")
            self.sio.wait()
        except Exception as e:
            self.socketio_ws.emit("result", {"error": str(e)}, room=batch_id)

    def stop(self):
        if self.sio.connected:
            self.sio.disconnect()