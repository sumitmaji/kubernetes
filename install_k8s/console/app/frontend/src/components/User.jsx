import React, { useState, useEffect } from 'react';
import { useTheme } from '../theme/ThemeContext';
import api from './api';
import UserDataPopup from './UserDataPopup';
import ProvideTokenPopup from './ProvideTokenPopup';
const TOKEN_KEY = "user_provided_token";
const User = ({ username: propUsername, onLogin, onLogout }) => {
    const [open, setOpen] = useState(false);
    const { theme, switchTheme } = useTheme();
    const [username, setUsername] = useState(propUsername);
    const [showTokenPopup, setShowTokenPopup] = useState(false);
    const [showProvideToken, setShowProvideToken] = useState(false);

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
                    {username && (
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
                    )}
                    {!username && (
                        <div
                            className="user-dropdown-item"
                            onClick={() => {
                                setOpen(false);
                                setShowProvideToken(true);
                            }}
                            style={{
                                color: theme.colors.primary,
                                borderBottom: `1px solid ${theme.colors.border}`
                            }}
                        >
                            Provide Token
                        </div>
                    )}
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
                                localStorage.removeItem(TOKEN_KEY);
                                setUsername(null);
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
            <UserDataPopup open={showTokenPopup} onClose={() => setShowTokenPopup(false)} />
            <ProvideTokenPopup open={showProvideToken} onClose={() => setShowProvideToken(false)} />
        </div>
    );
};

export default User;