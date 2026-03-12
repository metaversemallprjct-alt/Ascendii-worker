
// src/Components/Model.jsx
import { useState, useEffect, useRef } from 'react';

const Model = () => {
  const [wheelAngle, setWheelAngle] = useState(0);

  useEffect(() => {
    const animate = (time) => {
      setWheelAngle((time / 50) % 360);
      requestAnimationFrame(animate);
    };
    requestAnimationFrame(animate);
  }, []);

  return (
    <div style={{
      width: '100vw',
      height: '100vh',
      background: '#060b18',
      color: '#c8f0ff',
      fontFamily: 'sans-serif',
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
    }}>
      <h1 style={{ color: '#3af0ff', textShadow: '0 0 20px #3af0ff' }}>
        Ascendii Dashboard (Model.jsx)
      </h1>
      
      {/* Simple rotating wheel test */}
      <svg width="200" height="200" viewBox="-100 -100 200 200">
        <circle cx="0" cy="0" r="90" fill="none" stroke="#3af0ff" strokeWidth="8" />
        <g transform={`rotate(${wheelAngle})`}>
          <line x1="0" y1="-80" x2="0" y2="80" stroke="#a8e6ff" strokeWidth="4" />
        </g>
      </svg>

      <p style={{ marginTop: '40px', fontSize: '18px' }}>
        Rituals, Flywheel, Waitlist – loading...
      </p>
    </div>
  );
};

export default Model;
