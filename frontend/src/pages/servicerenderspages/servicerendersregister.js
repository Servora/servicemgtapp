import React, { useState } from "react";
import { TextField, Button, Typography, Container, Box } from "@mui/material";
import { Link, useNavigate } from "react-router-dom";
import { getRequest, postRequest } from "../../utils/apicalls";

const SrRegistrationPage = () => {
  const [formData, setFormData] = useState({});
  const [error, setError] = useState();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    // Perform registration logic here
    console.log(formData);
    try {
      const res = await postRequest("/services/", formData);

      if (res) {
        navigate("/login");
      }
    } catch (error) {
      setError(error);
    }
  };

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
        <form onSubmit={handleSubmit}>
          <TextField
            label="Name"
            name="serviceRendererName"
            fullWidth
            //   value={name}
            onChange={(e) =>
              setFormData({ ...formData, [e.target.name]: e.target.value })
            }
            sx={{ mb: 2 }}
          />
          <TextField
            label="Phone Number"
            name="phoneNumber"
            fullWidth
            //   value={name}
            onChange={(e) =>
              setFormData({ ...formData, [e.target.name]: e.target.value })
            }
            sx={{ mb: 2 }}
          />
          <TextField
            label="Service to offer"
            name="services"
            fullWidth
            //   value={name}
            onChange={(e) =>
              setFormData({ ...formData, [e.target.name]: e.target.value })
            }
            sx={{ mb: 2 }}
          />
          <TextField
            label="Address"
            name="permanentAddress"
            fullWidth
            //   value={name}
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
            Register
          </Button>
        </form>
        <p
          style={{
            textDecoration: "none",
            textAlign: "center",
            color: "green",
            fontSize: "15px",
          }}
        >
          Already have an account?
          <Link
            style={{
              textDecoration: "none",
              textAlign: "center",
              color: "green",
              fontSize: "17px",
              fontWeight: "bolder",
            }}
            to={"/login"}
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

export default SrRegistrationPage;