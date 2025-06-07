import React from 'react';
import { useTheme } from '../theme/ThemeContext';
import Tile from "./Tile";
import CommandRunner from "./CommanRunner";


const Main = () => {
    const { theme } = useTheme();
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
        </main>
    );
};

export default Main;