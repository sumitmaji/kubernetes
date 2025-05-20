import React from 'react';
import { useTheme } from '../theme/ThemeContext';

const Footer = () => {
    const { theme } = useTheme();
    return (
        <footer
            className="footer"
            style={{
                background: theme.colors.primary,
                color: theme.colors.text
            }}
        >
            <h3>FOOTER</h3>
        </footer>
    );
};

export default Footer;