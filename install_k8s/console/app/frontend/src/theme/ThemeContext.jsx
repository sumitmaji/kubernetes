import React, { createContext, useContext, useState } from 'react';

const lightTheme = {
    colors: {
        primary: '#e0e0e0',      // light grey
        background: '#f5f5f5',   // very light grey
        text: '#222',            // dark text for contrast
        accent: '#1976d2',       // blue accent
        border: '#bdbdbd'
    }
};

const blueTheme = {
    colors: {
        primary: '#1976d2',      // blue
        background: '#f5f5f5',   // very light grey
        text: '#fff',            // white text
        accent: '#d32f2f',       // red accent
        border: '#ccc'
    }
};

const ThemeContext = createContext({
    theme: lightTheme,
    setTheme: () => {},
    switchTheme: () => {}
});

export const ThemeProvider = ({ children }) => {
    const [theme, setTheme] = useState(lightTheme);

    const switchTheme = () => {
        setTheme(theme === blueTheme ? lightTheme : blueTheme);
    };

    return (
        <ThemeContext.Provider value={{ theme, setTheme, switchTheme }}>
            {children}
        </ThemeContext.Provider>
    );
};

export const useTheme = () => useContext(ThemeContext);