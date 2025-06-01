import { Box, Container } from "@mui/material";
import consumer from "../images/consumer.jpg";
import service from "../images/service2.jpg";
import { Link } from "react-router-dom";

export const LinksToRegPage = () => {
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
      <Container
        maxWidth="md"
        sx={{
          display: "flex",
          flexDirection: "column",
          gap: 5,
          margin: "auto",
        }}
      >
        <Box
          sx={{
            display: "flex",
            flexDirection: "row",
            gap: 5,
            border: "1px solid grey",
          }}
        >
          <Box sx={{ maxHeight: "400px", maxWidth: "400px" }}>
            <img
              src={consumer}
              alt="consumer image"
              width={"100%"}
              height={"100%"}
            />
          </Box>
          <Box
            sx={{
              maxHeight: "400px",
              maxWidth: "600px",
              display: "flex",
              justifyContent: "center",
              alignItems: "center",
              textAlign: "center",
            }}
          >
            <h5
              style={{
                textDecoration: "none",
                textAlign: "center",
                fontSize: "1.5rem",
                fontFamily: "Roboto,Helvetica,Arial,sans-serif",
                fontWeight: "400",
              }}
            >
              To Register as a service consumer
              <br />
              <Link
                style={{
                  textDecoration: "none",
                  textAlign: "center",
                  color: "green",
                  fontSize: "1.7rem",
                  fontWeight: "400",
                }}
                to={"/consumerreg"}
              >
                {" "}
                Click Here
              </Link>
            </h5>
          </Box>
        </Box>
        <Box
          sx={{
            display: "flex",
            flexDirection: "row-reverse",
            gap: 5,
            border: "1px solid grey",
          }}
        >
          <Box sx={{ maxHeight: "400px", maxWidth: "400px" }}>
            <img
              src={service}
              alt="consumer image"
              width={"100%"}
              height={"100%"}
            />
          </Box>
          <Box
            sx={{
              maxHeight: "400px",
              maxWidth: "600px",
              display: "flex",
              justifyContent: "center",
              alignItems: "center",
              textAlign: "center",
            }}
          >
            <h5
              style={{
                textDecoration: "none",
                textAlign: "center",
                fontSize: "1.5rem",
                fontFamily: "Roboto,Helvetica,Arial,sans-serif",
                fontWeight: "400",
              }}
            >
              To Register as a service Render
              <br />
              <Link
                style={{
                  textDecoration: "none",
                  textAlign: "center",
                  color: "green",
                  fontSize: "1.7rem",
                  fontWeight: "400",
                }}
                to={"/renderreg"}
                state={{ initialPageUrl: window.location.pathname }}
              >
                {" "}
                Click Here
              </Link>
            </h5>
          </Box>
        </Box>
      </Container>
    </Box>
  );
};