import React, { useEffect, useState } from 'react';
import { FaRegCopy } from 'react-icons/fa';
import api from './api';

const UserDataPopup = ({ open, onClose }) => {
    const [idToken, setIdToken] = useState('');
    const [copied, setCopied] = useState(false);

    useEffect(() => {
        if (open) {
            api.accesstoken.get()
                .then(res => setIdToken(res.data?.id_token || ''))
                .catch(() => setIdToken(''));
        }
    }, [open]);

    const handleCopy = () => {
        navigator.clipboard.writeText(idToken);
        setCopied(true);
        setTimeout(() => setCopied(false), 1200);
    };

    if (!open) return null;

    return (
        <div className="popup-overlay">
            <div className="popup-content">
                <h3>Id Token</h3>
                <div style={{ position: 'relative' }}>
                    <textarea
                        value={idToken}
                        readOnly
                        rows={6}
                        style={{
                            width: '100%',
                            fontFamily: 'monospace',
                            resize: 'vertical'
                        }}
                    />
                    <span
                        onClick={handleCopy}
                        style={{
                            position: 'absolute',
                            top: 8,
                            right: 8,
                            cursor: 'pointer',
                            color: copied ? '#4caf50' : '#888'
                        }}
                        title={copied ? 'Copied!' : 'Copy'}
                    >
                        <FaRegCopy size={18} />
                    </span>
                </div>
                <button onClick={onClose} style={{ marginTop: 16 }}>Close</button>
            </div>
            <style>{`
                .popup-overlay {
                    position: fixed;
                    top: 0; left: 0; right: 0; bottom: 0;
                    background: rgba(0,0,0,0.3);
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    z-index: 1000;
                }
                .popup-content {
                    background: #fff;
                    padding: 24px;
                    border-radius: 8px;
                    width: 50vw;
                    min-width: 350px;
                    max-width: 50vw;
                    height: 50vh;
                    max-height: 50vh;
                    box-shadow: 0 2px 16px rgba(0,0,0,0.2);
                    display: flex;
                    flex-direction: column;
                }
                .popup-content textarea {
                    height: 100%;
                    min-height: 150px;
                    max-height: 100%;
                }
            `}</style>
        </div>
    );
};

export default UserDataPopup;