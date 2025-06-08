// @mui material components
import Card from "@mui/material/Card";
import Grid from "@mui/material/Grid";
import Icon from "@mui/material/Icon";
import Tooltip from "@mui/material/Tooltip";
import AddIcon from "@mui/icons-material/Add";
import EditIcon from "@mui/icons-material/Edit";

// Material Dashboard 2 React components
// import Box from "components/Box";
// import Typography from "components/Typography";
// import Button from "components/Button";

// Images
import masterCardLogo from "./images/mastercard.png";
import visaLogo from "./images/visa.png";

// Material Dashboard 2 React context
// import { useMaterialUIController } from "context";
import { Box, Button, Typography } from "@mui/material";

function PaymentMethod() {
  //   const [controller] = useMaterialUIController();
  //   const { darkMode } = controller;
  const borderWidth = "1px"; // Example border width
  const borderColor = "#000"; // Example border color

  return (
    <Card id="delete-account">
      <Box
        pt={2}
        px={2}
        display="flex"
        justifyContent="space-between"
        alignItems="center"
      >
        <Typography variant="h6" fontWeight="medium">
          Payment Method
        </Typography>
        <Button
          variant="gradient"
          color="dark"
          sx={{ backgroundColor: "black" }}
        >
          {/* <Icon sx={{ fontWeight: "bold" }}>add</Icon> */}
          <AddIcon style={{ color: "white" }} />
          <span style={{ color: "white" }}>&nbsp;add new card</span>
        </Button>
      </Box>
      <Box p={2}>
        <Grid container spacing={3}>
          <Grid item xs={12} md={6}>
            <Box
              borderRadius="lg"
              display="flex"
              justifyContent="space-between"
              alignItems="center"
              p={3}
              sx={{
                border: ${borderWidth} solid ${borderColor},
              }}
            >
              <Box
                component="img"
                src={masterCardLogo}
                alt="master card"
                width="10%"
                mr={2}
              />
              <Typography variant="h6" fontWeight="medium">
                *&nbsp;&nbsp;*&nbsp;&nbsp;**&nbsp;&nbsp;7852
              </Typography>
              <Box ml="auto" lineHeight={0} color={"dark"}>
                <Tooltip title="Edit Card" placement="top">
                  {/* <Icon sx={{ cursor: "pointer" }} fontSize="small">
                    edit
                  </Icon> */}
                  <EditIcon />
                </Tooltip>
              </Box>
            </Box>
          </Grid>
          <Grid item xs={12} md={6}>
            <Box
              borderRadius="lg"
              display="flex"
              justifyContent="space-between"
              alignItems="center"
              p={3}
              //   sx={{
              //     border: ({ borders: { borderWidth, borderColor } }) =>
              //       ${borderWidth[1]} solid ${borderColor},
              //   }}
              sx={{
                border: ${borderWidth} solid ${borderColor},
              }}
            >
              <Box
                component="img"
                src={visaLogo}
                alt="master card"
                width="10%"
                mr={2}
              />
              <Typography variant="h6" fontWeight="medium">
                *&nbsp;&nbsp;*&nbsp;&nbsp;**&nbsp;&nbsp;5248
              </Typography>
              <Box ml="auto" lineHeight={0} color={"dark"}>
                <Tooltip title="Edit Card" placement="top">
                  {/* <Icon sx={{ cursor: "pointer" }} fontSize="small">
                    edit
                  </Icon> */}
                  <EditIcon />
                </Tooltip>
              </Box>
            </Box>
          </Grid>
        </Grid>
      </Box>
    </Card>
  );
}

export default PaymentMethod;