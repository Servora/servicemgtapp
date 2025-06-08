/**
=========================================================
* Material Dashboard 2 React - v2.2.0
=========================================================

* Product Page: https://www.creative-tim.com/product/material-dashboard-react
* Copyright 2023 Creative Tim (https://www.creative-tim.com)

Coded by www.creative-tim.com

 =========================================================

* The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
*/

// @mui material components
import { Box, Typography } from "@mui/material";
import Card from "@mui/material/Card";
// import Divider from "@mui/material/Divider";
import Icon from "@mui/material/Icon";
import ExpandMoreIcon from "@mui/icons-material/ExpandMore";
import ExpandLessIcon from "@mui/icons-material/ExpandLess";
import DateRangeIcon from "@mui/icons-material/DateRange";

// Material Dashboard 2 React components
// import Box from "components/Box";
// import Typography from "components/Typography";
// import MDButton from "components/MDButton";

// Billing page components
import Transaction from "./transaction";

function Transactions() {
  return (
    <Card sx={{ height: "100%" }}>
      <Box
        display="flex"
        justifyContent="space-between"
        alignItems="center"
        pt={3}
        px={2}
      >
        <Typography variant="h6" fontWeight="medium" textTransform="capitalize">
          Your Transaction&apos;s
        </Typography>
        <Box display="flex" alignItems="flex-start">
          <Box color="text" mr={0.5} lineHeight={0}>
            {/* <Icon color="inherit" fontSize="small">
              date_range
            </Icon> */}
            <DateRangeIcon />
          </Box>
          <Typography variant="button" color="text" fontWeight="regular">
            23 - 30 March 2020
          </Typography>
        </Box>
      </Box>
      <Box pt={3} pb={2} px={2}>
        <Box mb={2}>
          <Typography
            variant="caption"
            color="text"
            fontWeight="bold"
            textTransform="uppercase"
          >
            newest
          </Typography>
        </Box>
        <Box
          component="ul"
          display="flex"
          flexDirection="column"
          p={0}
          m={0}
          sx={{ listStyle: "none" }}
        >
          <Transaction
            color="error"
            icon={<ExpandMoreIcon />}
            name="Netflix"
            description="27 March 2020, at 12:30 PM"
            value="- $ 2,500"
          />
          <Transaction
            color="success"
            icon={<ExpandLessIcon />}
            name="Apple"
            description="27 March 2020, at 04:30 AM"
            value="+ $ 2,000"
          />
        </Box>
        <Box mt={1} mb={2}>
          <Typography
            variant="caption"
            color="text"
            fontWeight="bold"
            textTransform="uppercase"
          >
            yesterday
          </Typography>
        </Box>
        <Box
          component="ul"
          display="flex"
          flexDirection="column"
          p={0}
          m={0}
          sx={{ listStyle: "none" }}
        >
          <Transaction
            color="success"
            icon={<ExpandLessIcon />}
            name="Stripe"
            description="26 March 2020, at 13:45 PM"
            value="+ $ 750"
          />
          <Transaction
            color="success"
            icon={<ExpandLessIcon />}
            name="HubSpot"
            description="26 March 2020, at 12:30 PM"
            value="+ $ 1,000"
          />
          <Transaction
            color="success"
            icon={<ExpandLessIcon />}
            name="Creative Tim"
            description="26 March 2020, at 08:30 AM"
            value="+ $ 2,500"
          />
          <Transaction
            color="dark"
            icon="priority_high"
            name="Webflow"
            description="26 March 2020, at 05:00 AM"
            value="Pending"
          />
        </Box>
      </Box>
    </Card>
  );
}

export default Transactions;