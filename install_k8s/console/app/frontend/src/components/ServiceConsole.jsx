import React, { useState, useRef } from "react";
import io from "socket.io-client";
import { useTheme } from "../theme/ThemeContext";
const TOKEN_KEY = "user_provided_token";

const WS_URL =
  window.location.hostname === "localhost" || window.location.hostname === "127.0.0.1"
    ? "ws://127.0.0.1:8080"
    : process.env.REACT_APP_WS_URL || undefined;

/**
 * ServiceConsole is a reusable console for any backend service.
 * 
 * Props:
 * - apiPrefix: API prefix for commands, e.g. "rabbitmq", "vault"
 * - actions: array of { label: string, apiRoute: string }
 *   Example: [{ label: "Logs", apiRoute: "logs" }, { label: "Pods", apiRoute: "pods" }]
 */
const ServiceConsole = ({ apiPrefix, actions }) => {
  const [output, setOutput] = useState([]);
  const [connected, setConnected] = useState(false);
  const [joinedBatchId, setJoinedBatchId] = useState(null);
  const [loading, setLoading] = useState(false);
  const socketRef = useRef(null);
  const { theme } = useTheme();

  // Call this with the API route you want to trigger (e.g. "logs" or "pods")
  const runServiceCommand = async (apiRoute) => {
    setOutput([]);
    setLoading(true);
    try {
      const token = localStorage.getItem(TOKEN_KEY);
      const isLocalhost =
        window.location.hostname === "localhost" ||
        window.location.hostname === "127.0.0.1";
      const headers = { "Content-Type": "application/json" };
      if (isLocalhost && token) {
        headers["Authorization"] = `Bearer ${token}`;
      }
      const resp = await fetch(`/api/v1/command/${apiPrefix}/${apiRoute}`, {
        method: "POST",
        headers,
        credentials: "include"
      });
      const data = await resp.json();
      if (resp.ok && data.batch_id) {
        connectSocket(data.batch_id);
      } else {
        setOutput([data.error || "Failed to send command"]);
      }
    } catch (err) {
      setOutput([err.message]);
    }
    setLoading(false);
  };

  const connectSocket = (batch_id) => {
    if (
      socketRef.current &&
      socketRef.current.connected &&
      joinedBatchId === batch_id
    ) {
      return;
    }
    if (socketRef.current) {
      socketRef.current.disconnect();
      socketRef.current = null;
    }
    const socket = io(WS_URL, { transports: ["websocket"] });
    socketRef.current = socket;
    socket.on("connect", () => {
      setConnected(true);
      socket.emit("join", { batch_id });
      setJoinedBatchId(batch_id);
    });
    socket.on("result", (msg) => setOutput((prev) => [...prev, msg]));
    socket.on("disconnect", () => {
      setConnected(false);
      setJoinedBatchId(null);
    });
  };

  return (
    <div
      style={{
        background: theme.colors.background,
        color: theme.colors.text,
        borderRadius: 10,
        minWidth: 500,
        minHeight: 300,
        width: "90vw",
        maxWidth: 700,
        boxShadow: "0 2px 16px rgba(0,0,0,0.18)",
        padding: 0,
        position: "relative",
        overflow: "hidden"
      }}
    >
      <div style={{ display: "flex", alignItems: "center", borderBottom: `1px solid ${theme.colors.border}`, background: "#f5f5f5" }}>
        {actions.map(({ label, apiRoute }, idx) => (
          <button
            key={label}
            onClick={() => runServiceCommand(apiRoute)}
            style={{
              margin: 12,
              padding: "0.4rem 1.1rem",
              borderRadius: 4,
              border: "none",
              background: "#1976d2",
              color: "#fff",
              fontWeight: 600,
              cursor: "pointer",
              fontSize: 15,
              marginLeft: idx > 0 ? 8 : 0
            }}
            disabled={loading}
          >
            {label}
          </button>
        ))}
        <div style={{ flex: 1 }} />
        <span style={{ marginRight: 16, color: connected ? "#4caf50" : "#f44336" }}>
          {connected ? "Connected" : "Disconnected"}
        </span>
      </div>
      <div style={{ padding: 24, minHeight: 200, background: "#222", color: "#fff", fontFamily: "monospace", fontSize: 15 }}>
        <div style={{ marginBottom: 8, color: "#aaa" }}>
          <b>Console Output:</b>
        </div>
        <div style={{ maxHeight: 300, overflowY: "auto" }}>
          {output.length === 0 ? (
            <span style={{ color: "#888" }}>No output yet.</span>
          ) : (
            output.map((msg, i) => (
              <div key={i}>
                {typeof msg === "string"
                  ? msg
                  : msg.output || JSON.stringify(msg)}
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  );
};

export default ServiceConsole;