import React, { useState } from "react";

/**
 * Tile component that acts as a button to open a popup with any child component.
 * Usage:
 * <Tile title="Run Commands">
 *   <CommandRunner />
 * </Tile>
 */
const Tile = ({ title, children, tileStyle, popupStyle }) => {
  const [open, setOpen] = useState(false);

  return (
    <>
      <div
        style={{
          display: "inline-block",
          padding: 24,
          margin: 16,
          borderRadius: 12,
          background: "#f5f5f5",
          boxShadow: "0 2px 8px rgba(0,0,0,0.07)",
          cursor: "pointer",
          minWidth: 180,
          textAlign: "center",
          ...tileStyle,
        }}
        onClick={() => setOpen(true)}
      >
        <span style={{ fontWeight: 600, fontSize: 18 }}>{title}</span>
      </div>
      {open && (
        <div
          style={{
            position: "fixed",
            top: 0, left: 0, right: 0, bottom: 0,
            background: "rgba(0,0,0,0.35)",
            zIndex: 1000,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
          }}
          onClick={() => setOpen(false)}
        >
          <div
            style={{
              background: "#fff",
              borderRadius: 10,
              minWidth: 350,
              minHeight: 200,
              maxWidth: "90vw",
              maxHeight: "90vh",
              overflow: "auto",
              padding: 32,
              position: "relative",
              ...popupStyle,
            }}
            onClick={e => e.stopPropagation()}
          >
            <button
              onClick={() => setOpen(false)}
              style={{
                position: "absolute",
                top: 12,
                right: 16,
                background: "transparent",
                border: "none",
                fontSize: 24,
                cursor: "pointer",
                color: "#888",
              }}
              aria-label="Close"
            >
              &times;
            </button>
            {children}
          </div>
        </div>
      )}
    </>
  );
};

export default Tile;