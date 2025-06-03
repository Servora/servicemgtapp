import { Box, Button, Grid, Typography } from "@mui/material";
import React from "react";
import { useLocation, useNavigate } from "react-router-dom";

export const Layout = ({ children, name, info }) => {
  const location = useLocation();

  const navigate = useNavigate();
  const path = location.pathname.split("/")[1];
  const changeRoute = () => {
    navigate(-1);
    // switch (path) {
    //   case "login":
    //     navigate("/");
    //     break;
    //   case "regpage":
    //     navigate("/login");
    //     break;
    //   case "consumerreg":
    //     navigate("/regpage");
    //     break;
    //   case "renderreg":
    //     navigate("/regpage");
    //     break;
    //   default:
    //     navigate("/");
    //     break;
    // }
  };
  return (
    <Grid
      container
      gap={1}
      flexDirection={"column"}
      flexWrap={"nowrap"}
      sx={{
        padding: 4,
        maxHeight: "100vh",
        maxWidth: "100vw",
        m: 2,
        background: "white",
        backdropFilter: "blur(10px)",
        borderRadius: 3,
        position: "absolute",
        color: "black",
      }}
    >
      <Box
        sx={{
          position: "absolute",
          top: "5px",
          left: "5px",
        }}
      >
        <Button
          variant="contained"
          color="success"
          onClick={() => {
            changeRoute();
          }}
        >
          Back
        </Button>
      </Box>
      {/* <Typography
        fontWeight={700}
        sx={{
          mb: 0,
          fontSize: 22,
          textAlign: "center",
        }}
      >
        {name}
      </Typography> */}
      <h4
        style={{
          textAlign: "center",
          fontFamily: "Roboto,Helvetica, Arial,sans-serif",
          fontWeight: "400",
          fontSize: "2.125rem",
          lineHeight: "1.235",
        }}
      >
        {name}
      </h4>
      <Typography
        fontWeight={100}
        sx={{
          mb: 1,
          fontSize: 16,
          textAlign: "center",
        }}
      >
        {info}
      </Typography>
      {children}
    </Grid>
  );
};