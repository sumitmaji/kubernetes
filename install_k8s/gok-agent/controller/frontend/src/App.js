import React, { useState, useRef, useEffect } from "react";
import io from "socket.io-client";

// Example: Get OIDC config from environment
const API_URL = process.env.REACT_APP_API_URL || "";

function App() {
  const [commands, setCommands] = useState("");
  const [batchId, setBatchId] = useState("");
  const [results, setResults] = useState([]);
  const [connected, setConnected] = useState(false);
  const [idToken, setIdToken] = useState(localStorage.getItem("id_token") || "");
  const [user, setUser] = useState("");
  const socketRef = useRef(null);

  // OIDC login redirect
  const login = () => {
    // Redirect to your OIDC provider (example: Auth0, Azure AD, etc)
    window.location.href = `https://YOUR_OIDC_DOMAIN/authorize?client_id=YOUR_CLIENT_ID&response_type=id_token&scope=openid%20profile%20email&redirect_uri=${encodeURIComponent(window.location.origin)}/callback&nonce=xyz`;
  };

  // On OIDC callback, extract id_token from URL
  useEffect(() => {
    if (window.location.pathname === "/callback") {
      const hash = window.location.hash.substr(1);
      const params = new URLSearchParams(hash);
      const token = params.get("id_token");
      if (token) {
        localStorage.setItem("id_token", token);
        setIdToken(token);
        window.location.replace("/");
      }
    }
    // Optionally, fetch user info from backend for display
    if (idToken) {
      fetch(`${API_URL}/logininfo`, {
        headers: { "Authorization": "Bearer " + idToken }
      })
      .then(res => res.json())
      .then(data => setUser(data.user || ""))
      .catch(() => setUser(""));
    }
  }, [idToken]);

  const sendCommands = async () => {
    setResults([]);
    setBatchId("");
    const res = await fetch(`${API_URL}/send-command-batch`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + idToken
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
      auth: { token: idToken }
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
      {!idToken ? (
        <div>
          <h2>Login</h2>
          <button onClick={login}>Login with OAuth2</button>
        </div>
      ) : (
        <>
          <h2>K8s Host Command Web Controller</h2>
          <div>Signed in as: <b>{user}</b> <button onClick={() => {localStorage.clear(); window.location.reload();}}>Logout</button></div>
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
            <strong>Batch ID:</strong> {batchId}<br/>
            <strong>Socket Connected:</strong> {connected ? "Yes" : "No"}
          </div>
          <h3>Results</h3>
          <pre style={{ background: "#eee", padding: 10, minHeight: 100 }}>
            {results.map((r, idx) => <div key={idx}><b>Cmd {r.command_id}:</b> {r.output}</div>)}
          </pre>
        </>
      )}
    </div>
  );
}

export default App;