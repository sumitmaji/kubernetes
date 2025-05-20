import React from 'react';
import Header from './Header';
import Main from './Main';
import Footer from './Footer';

const ConsoleApp = () => {
    return (
        <div style={{
            display: 'flex',
            flexDirection: 'column',
            minHeight: '100vh'
        }}>
            <Header />
            <Main />
            {/* <Footer /> */}
        </div>
    );
};

export default ConsoleApp;