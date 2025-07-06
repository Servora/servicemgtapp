import { Box } from "@mui/material";
import React from "react";
import pagenotfound from "../images/404.png";

export const PageNotFound = () => {
  return (
    <Box
      sx={{
        display: "flex",
        justifyContent: "center",
        alignItems: "center",
        maxWidth: "100vw",
        maxHeight: "100vh",
      }}
    >
      <Box sx={{ minWidth: "500px", height: "500px" }}>
        <img width={"100%"} height={"100%"} src={pagenotfound} />
      </Box>
    </Box>
  );
};
