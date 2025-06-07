import React, { useState, useRef } from "react";
import io from "socket.io-client";
import { useTheme } from "../theme/ThemeContext";
const TOKEN_KEY = "user_provided_token";
const API_URL = ""; // Use proxy from package.json

const CommandRunner = () => {
  const [commands, setCommands] = useState([""]);
  const [results, setResults] = useState([]);
  const [batchId, setBatchId] = useState(null);
  const [connected, setConnected] = useState(false);
  const [loading, setLoading] = useState(false);
  const socketRef = useRef(null);
  const { theme } = useTheme();

  const handleCommandChange = (idx, value) => {
    const newCommands = [...commands];
    newCommands[idx] = value;
    setCommands(newCommands);
  };

  const addCommand = () => setCommands([...commands, ""]);

  const removeCommand = (idx) => {
    setCommands(commands.filter((_, i) => i !== idx));
  };

  const sendCommands = async () => {
    setResults([]);
    setBatchId(null);
    setLoading(true);
    if (socketRef.current) {
      socketRef.current.disconnect();
      socketRef.current = null;
    }
    try {
      const token = localStorage.getItem(TOKEN_KEY);
      const isLocalhost = window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1";
      const headers = { "Content-Type": "application/json" };
      if (isLocalhost && token) {
        headers["Authorization"] = `Bearer ${token}`;
      }
      const resp = await fetch(`/api/v1/command/send_command`, {
        method: "POST",
        headers,
        body: JSON.stringify({ commands: commands.filter(Boolean) }),
        credentials: "include"
      });
      const data = await resp.json();
      if (resp.ok && data.batch_id) {
        setBatchId(data.batch_id);
        connectSocket(data.batch_id);
      } else {
        setResults([data.error || "Failed to send command"]);
      }
    } catch (err) {
      setResults([err.message]);
    }
    setLoading(false);
  };

  const connectSocket = (batch_id) => {
    const socket = io(API_URL || undefined, { transports: ["websocket"] });
    socketRef.current = socket;
    socket.on("connect", () => {
      setConnected(true);
      socket.emit("join", { batch_id });
    });
    socket.on("result", (msg) => setResults((prev) => [...prev, msg]));
    socket.on("disconnect", () => setConnected(false));
  };

  return (
    <div
      style={{
        background: theme.colors.background,
        color: theme.colors.text,
        border: `1px solid ${theme.colors.border}`,
        borderRadius: 8,
        padding: 24,
        maxWidth: 600,
        margin: "2rem auto",
        boxShadow: "0 2px 8px rgba(0,0,0,0.07)"
      }}
    >
      <h2 style={{ color: theme.colors.primary }}>Run Commands</h2>
      {commands.map((cmd, idx) => (
        <div key={idx} style={{ display: "flex", alignItems: "center", marginBottom: 8 }}>
          <input
            type="text"
            value={cmd}
            onChange={e => handleCommandChange(idx, e.target.value)}
            placeholder={`Command #${idx + 1}`}
            style={{
              flex: 1,
              padding: "0.5rem",
              borderRadius: 4,
              border: `1px solid ${theme.colors.border}`,
              marginRight: 8,
              background: theme.colors.background,
              color: theme.colors.text,
              fontFamily: "monospace"
            }}
          />
          {commands.length > 1 && (
            <button
              onClick={() => removeCommand(idx)}
              style={{
                background: theme.colors.accent,
                color: "#fff",
                border: "none",
                borderRadius: 4,
                padding: "0.3rem 0.7rem",
                cursor: "pointer"
              }}
              title="Remove"
            >
              &times;
            </button>
          )}
        </div>
      ))}
      <div style={{ margin: "1rem 0" }}>
        <button
          onClick={addCommand}
          style={{
            background: theme.colors.primary,
            color: theme.colors.text,
            border: "none",
            borderRadius: 4,
            padding: "0.5rem 1rem",
            marginRight: 8,
            cursor: "pointer"
          }}
        >
          Add Command
        </button>
        <button
          onClick={sendCommands}
          disabled={commands.filter(Boolean).length === 0 || loading}
          style={{
            background: theme.colors.accent,
            color: "#fff",
            border: "none",
            borderRadius: 4,
            padding: "0.5rem 1rem",
            cursor: commands.filter(Boolean).length === 0 || loading ? "not-allowed" : "pointer",
            opacity: commands.filter(Boolean).length === 0 || loading ? 0.7 : 1
          }}
        >
          {loading ? "Sending..." : "Send Commands"}
        </button>
      </div>
      <div style={{ marginTop: 24 }}>
        <div><strong>Batch ID:</strong> {batchId || <span style={{ color: "#888" }}>None</span>}</div>
        <div><strong>Socket:</strong> {connected ? <span style={{ color: "#4caf50" }}>Connected</span> : <span style={{ color: "#f44336" }}>Disconnected</span>}</div>
        <div style={{ marginTop: 16 }}>
          <strong>Results:</strong>
          <pre style={{
            background: "#222",
            color: "#fff",
            padding: 12,
            borderRadius: 4,
            minHeight: 80,
            marginTop: 8,
            fontSize: 14,
            fontFamily: "monospace"
          }}>
            {results.length === 0
              ? <span style={{ color: "#888" }}>No results yet.</span>
              : results.map((r, i) => (
                <div key={i}>{typeof r === "string" ? r : JSON.stringify(r)}</div>
              ))}
          </pre>
        </div>
      </div>
    </div>
  );
};

export default CommandRunner;