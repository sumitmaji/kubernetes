import React, { useState, useRef } from "react";
import io from "socket.io-client";

const API_URL = process.env.REACT_APP_API_URL || "";

function App() {
  const [commands, setCommands] = useState("");
  const [batchId, setBatchId] = useState("");
  const [results, setResults] = useState([]);
  const [connected, setConnected] = useState(false);
  const [jwt, setJwt] = useState(localStorage.getItem("jwt") || "");
  const [loginUser, setLoginUser] = useState("");
  const [loginPass, setLoginPass] = useState("");
  const socketRef = useRef(null);

  const login = async () => {
    const res = await fetch(`${API_URL}/login`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ username: loginUser, password: loginPass }),
    });
    const data = await res.json();
    if (data.access_token) {
      setJwt(data.access_token);
      localStorage.setItem("jwt", data.access_token);
    } else {
      alert("Login failed");
    }
  };

  const sendCommands = async () => {
    setResults([]);
    setBatchId("");
    const res = await fetch(`${API_URL}/send-command-batch`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${jwt}`
      },
      body: JSON.stringify({ commands: commands.split("\n").filter(Boolean) }),
    });
    const data = await res.json();
    if (data.batch_id) {
      setBatchId(data.batch_id);
      connectSocket(data.batch_id);
    } else {
      alert("Failed to send commands");
    }
  };

  const connectSocket = (batch_id) => {
    if (socketRef.current) {
      socketRef.current.disconnect();
    }
    const socket = io(API_URL, { transports: ["websocket"] });
    socketRef.current = socket;
    socket.on("connect", () => {
      setConnected(true);
      socket.emit("join", { batch_id });
    });
    socket.on("result", (msg) => {
      setResults((prev) => [...prev, msg]);
    });
    socket.on("disconnect", () => setConnected(false));
  };

  return (
    <div style={{ maxWidth: 600, margin: "2rem auto", fontFamily: "sans-serif" }}>
      {!jwt ? (
        <div>
          <h2>Login</h2>
          <input placeholder="Username" value={loginUser} onChange={e => setLoginUser(e.target.value)} />
          <input type="password" placeholder="Password" value={loginPass} onChange={e => setLoginPass(e.target.value)} />
          <button onClick={login}>Login</button>
        </div>
      ) : (
        <>
          <h2>K8s Host Command Web Controller</h2>
          <textarea
            rows={5}
            cols={60}
            value={commands}
            onChange={e => setCommands(e.target.value)}
            placeholder="Enter one command per line (e.g. ls, whoami, uptime)"
          />
          <br />
          <button onClick={sendCommands} disabled={!commands.trim()}>Send</button>
          <div>
            <strong>Batch ID:</strong> {batchId}
            <br />
            <strong>Socket Connected:</strong> {connected ? "Yes" : "No"}
          </div>
          <h3>Results</h3>
          <pre style={{ background: "#eee", padding: 10, minHeight: 100 }}>
            {results.map((r, idx) =>
              <div key={idx}>
                <b>Cmd {r.command_id}:</b> {r.output}
              </div>
            )}
          </pre>
        </>
      )}
    </div>
  );
}

export default App;