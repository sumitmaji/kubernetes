import React, { useState } from 'react';
import { useTheme } from '../theme/ThemeContext';
import Tile from "./Tile";
import CommandRunner from "./CommanRunner";
import ServiceConsole from "./ServiceConsole";

const ServiceTile = ({ title, onOpen }) => (
    <Tile title={title}>
        <div style={{ minWidth: 300, minHeight: 120, display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
            <div style={{ flex: 1 }}>
                {/* You can add service-specific content here if needed */}
            </div>
            <div style={{ display: "flex", gap: 12, justifyContent: "flex-end", marginTop: 24 }}>
                <button
                    onClick={onOpen}
                    style={{
                        padding: "0.5rem 1.2rem",
                        borderRadius: 4,
                        border: "none",
                        background: "#1976d2",
                        color: "#fff",
                        fontWeight: 600,
                        cursor: "pointer",
                        fontSize: 15
                    }}
                >
                    Open Console
                </button>
            </div>
        </div>
    </Tile>
);

const Main = () => {
    const { theme } = useTheme();
    const [showRabbitmq, setShowRabbitmq] = useState(false);

    return (
        <main
            className="main"
            style={{
                background: theme.colors.background
            }}
        >
            <Tile title="Run Commands">
                <CommandRunner />
            </Tile>
            <Tile
                title="Rabbit MQ"
            >
                <ServiceConsole
                    onClose={() => setShowRabbitmq(false)}
                    apiPrefix="rabbitmq"
                    actions={[
                        { label: "Logs", apiRoute: "logs" },
                        { label: "Pods", apiRoute: "pods" }
                    ]}
                />
            </Tile>
        </main>
    );
};

export default Main;