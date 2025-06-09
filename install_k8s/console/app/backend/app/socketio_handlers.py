from flask_socketio import join_room

def register_socketio_handlers(app):
    socketio = app.extensions["socketio"]

    @socketio.on("join")
    def handle_join(data):
        batch_id = data.get("batch_id")
        if batch_id:
            join_room(batch_id)

    @socketio.on("connect")
    def handle_connect():
        print("A client connected.")