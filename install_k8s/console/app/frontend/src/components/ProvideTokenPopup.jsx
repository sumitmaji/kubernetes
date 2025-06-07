import React, { useState, useEffect } from "react";

const TOKEN_KEY = "user_provided_token";

const ProvideTokenPopup = ({ open, onClose }) => {
    const [token, setToken] = useState("");
    const [saved, setSaved] = useState(false);

    useEffect(() => {
        if (open) {
            setToken(localStorage.getItem(TOKEN_KEY) || "");
            setSaved(false);
        }
    }, [open]);

    const handleSave = () => {
        localStorage.setItem(TOKEN_KEY, token);
        setSaved(true);
        setTimeout(() => {
            setSaved(false);
            onClose();
        }, 1000);
    };

    if (!open) return null;

    return (
        <div className="popup-overlay">
            <div className="popup-content">
                <h3>Provide Bearer Token</h3>
                <textarea
                    value={token}
                    onChange={e => setToken(e.target.value)}
                    rows={4}
                    style={{ width: "100%", fontFamily: "monospace", resize: "vertical" }}
                    placeholder="Paste your token here"
                />
                <div style={{ marginTop: 16, display: "flex", gap: 8 }}>
                    <button onClick={handleSave}>Save</button>
                    <button onClick={onClose}>Cancel</button>
                    {saved && <span style={{ color: "#4caf50" }}>Saved!</span>}
                </div>
            </div>
            <style>{`
                .popup-overlay {
                    position: fixed;
                    top: 0; left: 0; right: 0; bottom: 0;
                    background: rgba(0,0,0,0.3);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    z-index: 1000;
                }
                .popup-content {
                    background: #fff;
                    padding: 24px;
                    border-radius: 8px;
                    min-width: 350px;
                    box-shadow: 0 2px 16px rgba(0,0,0,0.2);
                }
            `}</style>
        </div>
    );
};

export default ProvideTokenPopup;