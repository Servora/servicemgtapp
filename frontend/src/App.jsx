import { BrowserRouter, Routes, Route } from 'react-router-dom';
import Headline from './components/Headline';

function Register() {
  return <h1>Register Page</h1>;
}

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Headline />} />
        <Route path="/register" element={<Register />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
