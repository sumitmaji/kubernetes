import React from 'react';
import { BrowserRouter as Router, Route, Switch } from 'react-router-dom';
import ConsoleApp from './components/ConsoleApp';


function App() {
    return (
        <Router>
            <div>
                <Switch>
                    <Route path="/" exact component={ConsoleApp} />
                    {/* Add more routes here as needed */}
                </Switch>
            </div>
        </Router>
    );
}

export default App;