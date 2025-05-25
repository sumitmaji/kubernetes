import React from 'react';
import ReactDOM from 'react-dom';
import App from './App';
import './components/ConsoleApp.css';
import { ThemeProvider } from './theme/ThemeContext';

ReactDOM.render(
  <React.StrictMode>
    <ThemeProvider>
      <App />
    </ThemeProvider>
  </React.StrictMode>,
  document.getElementById('root')
);