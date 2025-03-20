import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Box, Typography, Grid2, ButtonBase } from '@mui/material';
import { styled } from '@mui/material/styles';

const MyButton = styled(ButtonBase)(({ theme }) => ({
  padding: theme.spacing(1.75, 6),
  backgroundColor: theme.palette.secondary.main,
  color: theme.palette.secondary.contrastText,
  borderRadius: theme.shape.borderRadius * 2,
  fontFamily: theme.typography.fontFamily,
  fontSize: '1.125rem',
  fontWeight: 600,
  letterSpacing: '0.06em',
  textTransform: 'uppercase',
  boxShadow: theme.shadows[4],
  transition: 'background-color 0.3s ease, box-shadow 0.3s ease, transform 0.2s ease',
  '&:hover': {
    backgroundColor: theme.palette.secondary.dark,
    boxShadow: theme.shadows[8],
    transform: 'translateY(-3px)',
  },
}));

const Headline = () => {
  const navigate = useNavigate();

  const handleButtonClick = () => {
    navigate('/register');
  };

  return (
    <Box
      sx={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: 'linear-gradient(145deg, #1e3a8a 0%, #3b82f6 100%)',
        position: 'relative',
        overflow: 'hidden',
        px: { xs: 2, sm: 3, md: 6 },
        py: { xs: 4, md: 8 },
        '&:before': {
          content: '""',
          position: 'absolute',
          top: 0,
          left: 0,
          width: '100%',
          height: '100%',
          background: 'radial-gradient(circle, rgba(255, 255, 255, 0.1) 0%, rgba(0, 0, 0, 0.2) 100%)',
          zIndex: 1,
        },
      }}
    >
      <Grid2
        container
        spacing={{ xs: 2, md: 4 }}
        justifyContent="center"
        alignItems="center"
        sx={{ position: 'relative', zIndex: 2, maxWidth: '1400px' }}
      >
        <Grid2 xs={12}>
          <Box sx={{ textAlign: { xs: 'center', md: 'left' }, px: { xs: 1, md: 0 } }}>
            <Typography
              variant="h1"
              component="h1"
              gutterBottom
              sx={{
                fontSize: { xs: '2.25rem', sm: '3.25rem', md: '4.5rem' },
                fontWeight: 800,
                lineHeight: 1.15,
                color: '#ffffff',
                textShadow: '0 4px 12px rgba(0, 0, 0, 0.25)',
              }}
            >
              Elevate Your Workflow
            </Typography>
            <Typography
              variant="h5"
              component="p"
              sx={{
                fontSize: { xs: '1rem', sm: '1.25rem', md: '1.5rem' },
                fontWeight: 400,
                lineHeight: 1.5,
                color: '#f0f4ff',
                mb: { xs: 3, md: 4 },
                maxWidth: '90%',
              }}
            >
              Optimize efficiency with cutting-edge tools.
            </Typography>
            <MyButton onClick={handleButtonClick}>
              Get Started
            </MyButton>
          </Box>
        </Grid2>
      </Grid2>
    </Box>
  );
};

export default Headline;