import React, { useState, useEffect } from 'react';
import { useTheme } from '../theme/ThemeContext';
import api from './api';
// Change import to new component name
import UserDataPopup from './UserDataPopup';

const User = ({ username: propUsername, onLogin, onLogout }) => {
    const [open, setOpen] = useState(false);
    const { theme, switchTheme } = useTheme();
    const [username, setUsername] = useState(propUsername);
    const [showTokenPopup, setShowTokenPopup] = useState(false);

    useEffect(() => {
        api.userinfo.get()
            .then(res => {
                if (res.data && res.data.username) {
                    setUsername(res.data.username);
                }
            })
            .catch(() => {
                setUsername(propUsername || null);
            });
    }, [propUsername]);

    const handleToggle = () => setOpen(!open);

    return (
        <div className="user-container">
            <button
                className="user-button"
                onClick={handleToggle}
                style={{
                    background: theme.colors.text,
                    border: `1px solid ${theme.colors.primary}`,
                    color: theme.colors.primary
                }}
            >
                {username ? username : 'User'}
                <span style={{ marginLeft: 8 }}>▼</span>
            </button>
            {open && (
                <div
                    className="user-dropdown"
                    style={{
                        background: theme.colors.text,
                        border: `1px solid ${theme.colors.border}`
                    }}
                >
                    <div
                        className="user-dropdown-item"
                        onClick={() => {
                            setOpen(false);
                            setShowTokenPopup(true);
                        }}
                        style={{
                            color: theme.colors.primary,
                            borderBottom: `1px solid ${theme.colors.border}`
                        }}
                    >
                        Show Id Token
                    </div>
                    <div
                        className="user-dropdown-item"
                        onClick={() => {
                            setOpen(false);
                            switchTheme();
                        }}
                        style={{
                            color: theme.colors.primary,
                            borderBottom: `1px solid ${theme.colors.border}`
                        }}
                    >
                        Switch Theme
                    </div>
                    {username ? (
                        <div
                            className="user-dropdown-item"
                            onClick={() => {
                                setOpen(false);
                                onLogout && onLogout();
                            }}
                            style={{
                                color: theme.colors.accent,
                                borderBottom: 'none'
                            }}
                        >
                            Logout
                        </div>
                    ) : (
                        <div
                            className="user-dropdown-item"
                            onClick={() => {
                                setOpen(false);
                                onLogin && onLogin();
                            }}
                            style={{
                                color: theme.colors.primary,
                                borderBottom: 'none'
                            }}
                        >
                            Login
                        </div>
                    )}
                </div>
            )}
            {/* Use UserDataPopup instead of AccessTokenPopup */}
            <UserDataPopup open={showTokenPopup} onClose={() => setShowTokenPopup(false)} />
        </div>
    );
};

export default User;