import React, { useState, useRef, useEffect } from "react";
import io from "socket.io-client";

const API_URL = process.env.REACT_APP_API_URL || "https://kube.gokcloud.com/controller";

function App() {
  const [commands, setCommands] = useState("");
  const [batchId, setBatchId] = useState("");
  const [results, setResults] = useState([]);
  const [connected, setConnected] = useState(false);
  const [user, setUser] = useState("");
  const socketRef = useRef(null);

  useEffect(() => {
    fetch(`${API_URL}/logininfo`)
      .then(res => res.json())
      .then(data => setUser(data.user || ""))
      .catch(() => setUser(""));
  }, []);

  const sendCommands = async () => {
    setResults([]);
    setBatchId("");
    const res = await fetch(`${API_URL}/send-command-batch`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json"
      },
      body: JSON.stringify({ commands: commands.split("\n").filter(Boolean) }),
    });
    const data = await res.json();
    if (data.batch_id) {
      setBatchId(data.batch_id);
      connectSocket(data.batch_id);
    } else {
      alert(data.error || "Failed to send commands");
    }
  };

  const connectSocket = (batch_id) => {
    if (socketRef.current) socketRef.current.disconnect();
    const socket = io(API_URL, {
      transports: ["websocket"],
      path: "/controller/socket.io"
    });
    socketRef.current = socket;
    socket.on("connect", () => {
      setConnected(true);
      socket.emit("join", { batch_id });
    });
    socket.on("result", (msg) => setResults((prev) => [...prev, msg]));
    socket.on("disconnect", () => setConnected(false));
  };

  return (
    <div style={{ maxWidth: 600, margin: "2rem auto", fontFamily: "sans-serif" }}>
      <>
        <h2>K8s Host Command Web Controller</h2>
        <div>
          Signed in as: <b>{user}</b>{" "}
          <button onClick={() => { window.location = "/oauth2/sign_out"; }}>Logout</button>
        </div>
        <textarea
          rows={5}
          cols={60}
          value={commands}
          onChange={e => setCommands(e.target.value)}
          placeholder="Enter one command per line"
        />
        <br />
        <button onClick={sendCommands} disabled={!commands.trim()}>Send</button>
        <div>
          <strong>Batch ID:</strong> {batchId}<br />
          <strong>Socket Connected:</strong> {connected ? "Yes" : "No"}
        </div>
        <h3>Results</h3>
        <pre style={{ background: "#eee", padding: 10, minHeight: 100 }}>
          {results.map((r, idx) => <div key={idx}><b>Cmd {r.command_id}:</b> {r.output}</div>)}
        </pre>
      </>
    </div>
  );
}

export default App;