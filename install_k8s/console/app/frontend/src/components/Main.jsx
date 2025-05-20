import React from 'react';
import { useTheme } from '../theme/ThemeContext';

const Main = () => {
    const { theme } = useTheme();
    return (
        <main
            className="main"
            style={{
                background: theme.colors.background
            }}
        >
            <h1>MAIN</h1>
        </main>
    );
};

export default Main;