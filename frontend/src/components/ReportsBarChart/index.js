/**
=========================================================
* Material Dashboard 2  React - v2.2.0
=========================================================

* Product Page: https://www.creative-tim.com/product/material-dashboard-react
* Copyright 2023 Creative Tim (https://www.creative-tim.com)

Coded by www.creative-tim.com

 =========================================================

* The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
*/

import { useMemo } from "react";

// porp-types is a library for typechecking of props
import PropTypes from "prop-types";

// react-chartjs-2 components
import { Bar } from "react-chartjs-2";
import {
  Chart as ChartJS,
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend,
} from "chart.js";

// @mui material components
import Card from "@mui/material/Card";
import Divider from "@mui/material/Divider";
import Icon from "@mui/material/Icon";
import ContentCopyIcon from "@mui/icons-material/ContentCopy";
import ScheduleIcon from "@mui/icons-material/Schedule";

// Material Dashboard 2 React components
// import MDBox from "components/MDBox";
// import MDTypography from "components/MDTypography";

// ReportsBarChart configurations
import configs from "./configs";
import { Box, Grid, Typography } from "@mui/material";

ChartJS.register(
  CategoryScale,
  LinearScale,
  BarElement,
  Title,
  Tooltip,
  Legend
);

function ReportsBarChart({ color, title, description, date, chart, bgColor }) {
  const { data, options } = configs(chart.labels || [], chart.datasets || {});

  options.responsive = true;

  return (
    // <Grid item xs={6} md={6} lg={12}>
    <Card sx={{ height: "100%" }}>
      <Box padding="1rem">
        {useMemo(
          () => (
            <Box
              // variant="gradient"
              bgcolor={bgColor}
              borderRadius="lg"
              // coloredShadow={color}
              py={2}
              pr={0.5}
              mt={-5}
              height="12.5rem"
              // border={"1px solid red"}
              p={3}
              boxShadow={7}
            >
              <Bar data={data} options={options} redraw />
            </Box>
          ),
          [color, chart, data, options, bgColor]
        )}
        <Box pt={3} pb={1} px={1}>
          <Typography variant="h6" textTransform="capitalize">
            {title}
          </Typography>
          <Typography
            component="div"
            variant="button"
            color="text"
            fontWeight="light"
          >
            {description}
          </Typography>
          <Divider />
          <Box display="flex" alignItems="center">
            <Typography
              variant="button"
              color="text"
              lineHeight={1}
              sx={{ mt: 0.15, mr: 0.5 }}
            >
              {/* <Icon>schedule</Icon> */}
              {<ContentCopyIcon fontSize="medium" style={{ color: "black" }} />}
            </Typography>
            <Typography variant="button" color="text" fontWeight="light">
              {date}
            </Typography>
          </Box>
        </Box>
      </Box>
    </Card>
    // </Grid>
  );
}

// Setting default values for the props of ReportsBarChart
// ReportsBarChart.defaultProps = {
//   color: "info",
//   description: "",
// };

// Typechecking props for the ReportsBarChart
// ReportsBarChart.propTypes = {
//   color: PropTypes.oneOf([
//     "primary",
//     "secondary",
//     "info",
//     "success",
//     "warning",
//     "error",
//     "dark",
//   ]),
//   title: PropTypes.string.isRequired,
//   description: PropTypes.oneOfType([PropTypes.string, PropTypes.node]),
//   date: PropTypes.string.isRequired,
//   chart: PropTypes.objectOf(
//     PropTypes.oneOfType([PropTypes.array, PropTypes.object])
//   ).isRequired,
// };

export default ReportsBarChart;
