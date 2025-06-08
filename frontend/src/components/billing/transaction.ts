import { Box, Grid } from "@mui/material";
import React from "react";
import MasterCard from "../../components/billing/mastercard";
import DefaultInfoCard from "../../components/billing/defaultcardinfo";
import AccountBalanceIcon from "@mui/icons-material/AccountBalance";
import RedeemIcon from "@mui/icons-material/Redeem";
import PaymentMethod from "../../components/billing/paymentmethod";
import Invoices from "../../components/billing/invoices";
import BillingInformation from "../../components/billing/billinginformation";
import Transactions from "../../components/billing/transactions";

export const SrPayment = () => {
  return (
    <Box mt={8} sx={{ backgroundColor: "#f0f2f5", height: "120vh" }}>
      <Box mb={3}>
        <Grid container spacing={3}>
          <Grid item xs={12} lg={8}>
            <Grid container spacing={3}>
              <Grid item xs={12} xl={6}>
                <MasterCard
                  number={4562112245947852}
                  holder="feyi ologs"
                  expires="11/22"
                />
              </Grid>
              <Grid item xs={12} md={6} xl={3}>
                <DefaultInfoCard
                  icon={<AccountBalanceIcon />}
                  title="salary"
                  description="Belong Interactive"
                  value="+$2000"
                />
              </Grid>
              <Grid item xs={12} md={6} xl={3}>
                <DefaultInfoCard
                  icon={<RedeemIcon />}
                  title="paypal"
                  description="Freelance Payment"
                  value="$455.00"
                />
              </Grid>
              <Grid item xs={12}>
                <PaymentMethod />
              </Grid>
            </Grid>
          </Grid>
          <Grid item xs={12} lg={4}>
            <Invoices />
          </Grid>
        </Grid>
      </Box>
      <Box mb={3}>
        <Grid container spacing={3}>
          <Grid item xs={12} md={7}>
            <BillingInformation />
          </Grid>
          <Grid item xs={12} md={5}>
            <Transactions />
          </Grid>
        </Grid>
      </Box>
    </Box>
  );
};