// @mui material components
import Card from "@mui/material/Card";
import Divider from "@mui/material/Divider";
import Icon from "@mui/material/Icon";

// Material Dashboard 2 React components
// import Box from "components/Box";
// import Typography from "components/Typography";
import { Box, Typography } from "@mui/material";

function DefaultInfoCard({ icon, title, description, value }) {
  return (
    <Card>
      <Box p={2} mx={3} display="flex" justifyContent="center">
        <Box
          display="grid"
          justifyContent="center"
          alignItems="center"
          bgcolor={"#49a3f1"}
          color="white"
          width="4rem"
          height="4rem"
          shadow="md"
          borderRadius="lg"
          variant="gradient"
        >
          {/* <Icon fontSize="default">{icon}</Icon> */}
          {icon}
        </Box>
      </Box>
      <Box pb={2} px={2} textAlign="center" lineHeight={1.25}>
        <Typography variant="h6" fontWeight="medium" textTransform="capitalize">
          {title}
        </Typography>
        {description && (
          <Typography variant="caption" color="text" fontWeight="regular">
            {description}
          </Typography>
        )}
        {description && !value ? null : <Divider />}
        {value && (
          <Typography variant="h5" fontWeight="medium">
            {value}
          </Typography>
        )}
      </Box>
    </Card>
  );
}

// Setting default values for the props of DefaultInfoCard
DefaultInfoCard.defaultProps = {
  color: "info",
  value: "",
  description: "",
};

// Typechecking props for the DefaultInfoCard
DefaultInfoCard.propTypes = {
  color: PropTypes.oneOf([
    "primary",
    "secondary",
    "info",
    "success",
    "warning",
    "error",
    "dark",
  ]),
  icon: PropTypes.node.isRequired,
  title: PropTypes.string.isRequired,
  description: PropTypes.string,
  value: PropTypes.oneOfType([PropTypes.string, PropTypes.number]),
};

export default DefaultInfoCard;
