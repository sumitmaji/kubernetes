import React from 'react';
import User from './User';
import { useTheme } from '../theme/ThemeContext';
import { FaSearch } from 'react-icons/fa';

const Header = ({ username, onLogin, onLogout }) => {
    const { theme } = useTheme();
    return (
        <header
            className="header"
            style={{
                background: theme.colors.primary,
                color: theme.colors.text
            }}
        >
            <div className="header-search" style={{ display: 'flex', alignItems: 'center', margin: '0 1rem' }}>
                <span style={{ color: theme.colors.text, marginRight: '0.5rem', display: 'flex', alignItems: 'center' }}>
                    <FaSearch />
                </span>
                <input
                    type="text"
                    placeholder="Search..."
                    style={{
                        padding: '0.4rem 0.8rem',
                        borderRadius: '4px',
                        border: `1px solid ${theme.colors.text}`,
                        background: theme.colors.background,
                        color: theme.colors.inputText || theme.colors.text, // Use inputText if available, fallback to text
                        outline: 'none',
                        transition: 'color 0.2s, background 0.2s, border 0.2s'
                    }}
                    key={theme.colors.text + theme.colors.background + (theme.colors.inputText || '')}
                />
            </div>
            <div className="header-left" />

            <div className="header-right">
                <span
                    role="img"
                    aria-label="console"
                    style={{ fontSize: '1.5rem', cursor: 'pointer' }}
                    onClick={() => window.open("http://kube.gokcloud.com/cloudshell/home", "_blank")}
                >🖥️</span>
                <span
                    className="header-divider"
                    style={{ background: theme.colors.text }}
                />
                <User username={username} onLogin={onLogin} onLogout={onLogout} />
            </div>
        </header>
    );
};
export default Header;