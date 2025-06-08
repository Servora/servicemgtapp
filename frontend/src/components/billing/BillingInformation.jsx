// @mui material components
import { Box, Typography } from "@mui/material";
import Card from "@mui/material/Card";

// Material Dashboard 2 React components
// import Box from "components/Box";
// import Typography from "components/Typography";

// Billing page components
import Bill from "./bill";

function BillingInformation() {
  return (
    <Card id="delete-account">
      <Box pt={3} px={2}>
        <Typography variant="h6" fontWeight="medium">
          Billing Information
        </Typography>
      </Box>
      <Box pt={1} pb={2} px={2}>
        <Box component="ul" display="flex" flexDirection="column" p={0} m={0}>
          <Bill
            name="oliver liam"
            company="viking burrito"
            email="oliver@burrito.com"
            vat="FRB1235476"
          />
          <Bill
            name="lucas harper"
            company="stone tech zone"
            email="lucas@stone-tech.com"
            vat="FRB1235476"
          />
          <Bill
            name="ethan james"
            company="fiber notion"
            email="ethan@fiber.com"
            vat="FRB1235476"
            noGutter
          />
        </Box>
      </Box>
    </Card>
  );
}

export default BillingInformation;
