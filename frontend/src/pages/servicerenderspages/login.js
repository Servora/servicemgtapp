import React, { useContext, useEffect, useState } from "react";
import { TextField, Button, Typography, Container, Box } from "@mui/material";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { postRequest } from "../utils/apicalls";
import { SocketContext } from "../utils/socketcontext";
import CircularProgress from "@mui/material/CircularProgress";
// import io from "socket.io-client";

const LoginPage = () => {
  const [formData, setFormData] = useState({});
  const [error, setError] = useState();
  const [loading, setLoading] = useState(false);
  // const [user, setUser] = useState();
  const navigate = useNavigate();
  // let socket;
  const { socket, id } = useContext(SocketContext);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    try {
      const res = await postRequest("/services/login", formData);

      if (res) {
        const { token, user } = res;
        localStorage.clear();
        localStorage.setItem("token", JSON.stringify(token));
        localStorage.setItem("id", JSON.stringify(user._id));
        localStorage.setItem("phoneId", JSON.stringify(user.phoneNumber));
        localStorage.setItem("socketIdn", JSON.stringify(id));
        // localStorage.setItem(user.phoneNumber, id);
        // setUser(user.phoneNumber);
        socket.emit("forRedis", user.phoneNumber, id);
        setTimeout(() => {
          //Dashboard

          setLoading(false);

          navigate("/dashboard");
        }, 1000);
      }
    } catch (error) {
      setLoading(false);
      setError(error);
    }
  };

  // useEffect(() => {
  //   // socket.on("socketId", (id) => {
  //   //   setId(id);
  //   // });
  //   socket = io("http://localhost:5000");
  //   socket.on("socketId", (id) => {
  //     setId(id);
  //   });
  //   socket.emit("forRedis", user, id);
  // }, [user]);

  return (
    <Box
      sx={{
        display: "flex",
        flexDirection: "column",
        justifyContent: "center",
        alignItems: "center",
        height: "100vh",
      }}
    >
      <Container maxWidth="sm">
        {loading ? (
          <Box
            sx={{
              display: "flex",
              justifyContent: "center",
            }}
          >
            <CircularProgress color="primary" size={60} sx={{ mb: 2 }} />
          </Box>
        ) : (
          <form onSubmit={handleSubmit}>
            <TextField
              label="Phone Number"
              name="phoneNumber"
              fullWidth
              //   value={email}
              onChange={(e) =>
                setFormData({ ...formData, [e.target.name]: e.target.value })
              }
              sx={{ mb: 2 }}
            />
            <TextField
              label="Password"
              type="password"
              name="password"
              fullWidth
              //   value={password}
              onChange={(e) =>
                setFormData({ ...formData, [e.target.name]: e.target.value })
              }
              sx={{ mb: 2 }}
            />
            {error && (
              <Typography
                variant="body1"
                color={"error"}
                sx={{ textAlign: "center", m: 1 }}
              >
                {error}
              </Typography>
            )}
            <Button type="submit" variant="contained" color="success" fullWidth>
              Sign In
            </Button>
          </form>
        )}

        <p
          style={{
            textDecoration: "none",
            textAlign: "center",
            color: "green",
            fontSize: "15px",
            marginTop: "35px",
          }}
        >
          Need an account?
          <Link
            style={{
              textDecoration: "none",
              textAlign: "center",
              color: "green",
              fontSize: "17px",
              fontWeight: "bolder",
            }}
            to={"/regpage"}
            state={{ initialPageUrl: window.location.pathname }}
          >
            {" "}
            Click Here
          </Link>
        </p>
      </Container>
    </Box>
  );
};

export default LoginPage;
