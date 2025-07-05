apps/servicerenderingpage

// import "../App.css";
import "mapbox-gl/dist/mapbox-gl.css";
import { React, useState, useEffect, useContext } from "react";
import ReactMapGl, { Marker, Popup } from "react-map-gl";
import { env } from "../../config";
import { SocketContext } from "../../utils/socketcontext";
import { useNavigate } from "react-router-dom";
import { fectchApi } from "../../utils/fetch";
// import "./landingpage.css";
import {
  Box,
  Button,
  Grid,
  InputAdornment,
  TextField,
  Typography,
  CircularProgress,
} from "@mui/material";
import { postRequest } from "../../utils/apicalls";
// import { SocketContext } from "../../utils/socketcontext";

function ServiceRendering() {
  const [viewport, setViewport] = useState({
    longitude: 7.4892974, // center of the map  {This should be gotten by the app i.e current location; currently dis is set to Abuja
    latitude: 9.0643305, // center of the map
    zoom: 6,
  });

  // const [viewport, setViewport] = useState({});

  const [selectedServices, setSelectedServices] = useState([]);

  const [isPopupOpen, setPopupOpen] = useState(false);

  const [selectedMarker, setSelectedMarker] = useState(null);

  const [formVal, setFormVal] = useState({});

  const [chooseAddress, setChooseAddress] = useState(false);

  const { socket, id, setRecipient } = useContext(SocketContext);

  const [sockId, setSockId] = useState();

  const [loading, setLoading] = useState(false);

  const navigate = useNavigate();

  socket.on("sockId", (res) => {
    console.log({ "res >>>>>": res });
    setSockId(res);
  });
  console.log({ sockId });
  // const [idx, setId] = useState(id);

  // const [Id, setId] = useState();

  // const socket = useContext(SocketContext);

  // socket.on("socketId", (id) => {
  //   console.log({ id });
  //   setId(id);
  // });

  const handleMarkerClick = (marker) => {
    setSelectedMarker(marker);
    setPopupOpen(true);
  };

  const getCurrentLocation = () => {
    navigator.geolocation.getCurrentPosition((pos) => {
      setTimeout(() => {
        setFormVal({
          ...formVal,
          lat: pos.coords.latitude,
          lng: pos.coords.longitude,
        });
        console.log({ formVal });
      }, 500);
    });
  };

  const getServices = async () => {
    setLoading(true);
    try {
      // const service = "hotel"; // service in search for
      // const lng = viewport.longitude; // your present location
      // const lat = viewport.latitude; // your present location
      // const meters = 5000; // radius of search in meters

      // const body = {
      //   service,
      //   lng,
      //   lat,
      //   meters,
      // };
      Object.keys(formVal).forEach((key) => {
        if (key == "meters") {
          formVal[key] = parseInt(formVal[key]);
        }
      });

      Object.keys(formVal).forEach(async (key) => {
        if (key == "address") {
          // const response = await fectchApi(
          //   ${env.baseUrl}/services/searchaddr,
          //   "POST",
          //   formVal
          // );
          const response = await postRequest("/services/searchaddr", formVal);
          setLoading(false);
          setSelectedServices(response);
        } else {
          // const response = await fectchApi(
          //   ${env.baseUrl}/services/search,
          //   "POST",
          //   formVal
          // );
          const response = await postRequest("/services/search", formVal);
          setLoading(false);
          setSelectedServices(response);
          console.log({ selectedServices: response });
        }
      });
    } catch (error) {
      setSelectedServices([]);
      console.log(error);
    }
  };

  useEffect(() => {
    // This effect runs when 'sockId' changes
    if (sockId) {
      setRecipient(sockId);
      navigate("/chat");
    }
  }, [sockId, setRecipient, navigate]);

  const handleChatButtonClick = () => {
    if (selectedMarker && selectedMarker.phoneNumber) {
      // Emitting user event to socket
      socket.emit("user", selectedMarker.phoneNumber);
      console.log(selectedMarker.phoneNumber);
    } else {
      console.log("No selected marker or phone number available.");
    }
  };

  useEffect(() => {
    getCurrentLocation();
    // const sockettRef = io("http://localhost:5000");
    // sockettRef.on("socketId", (id) => {
    //   setId(id);
    //   // console.log({ testId: id });
    // });

    // This is supposed to get current location and set it as the viewport
    // navigator.geolocation.getCurrentPosition((pos) => {
    //   setViewport({
    //     ...viewport,
    //     latitude: pos.coords.latitude || 9.0643305,
    //     longitude: pos.coords.longitude || 7.4892974,
    //     zoom: 6,
    //     // transitionDuration: 100,
    //   });
    // });
    // const fetchServices = async () => {
    //   try {
    //     const service = "hotel"; // service in search for
    //     const lng = viewport.longitude; // your present location
    //     const lat = viewport.latitude; // your present location
    //     const meters = 5000; // radius of search in meters
    //     const body = {
    //       service,
    //       lng,
    //       lat,
    //       meters,
    //     };
    //     const response = await fectchApi(env.baseUrl, "POST", body);
    //     setSelectedServices(response);
    //     console.log({ selectedServices: response });
    //   } catch (error) {
    //     setSelectedServices([]);
    //     console.log(error);
    //   }
    // };
    // fetchServices();
    const handleSockId = (res) => {
      console.log({ res });
      setSockId(res);
    };

    socket.on("sockId", handleSockId);

    // Cleanup on unmount
    return () => {
      socket.off("sockId", handleSockId);
    };
  }, [socket]);

  return (
    <div
      style={{
        width: "100vw",
        height: "100vh",
        // margin: "0 auto",
        marginTop: 25,
      }}
    >
      <Grid container spacing={1}>
        {loading ? (
          <Grid
            item
            xl={3}
            lg={12}
            sx={{
              display: "flex",
              // flexDirection: "column",
              justifyContent: "center",
              alignItems: "center",
            }}
          >
            <Box
              sx={{
                display: "flex",
                justifyContent: "center",
              }}
            >
              <CircularProgress color="primary" size={60} sx={{ mb: 2 }} />
            </Box>
          </Grid>
        ) : (
          <Grid
            item
            xl={3}
            lg={12}
            sx={{
              display: "flex",
              // flexDirection: "column",
              justifyContent: "center",
              alignItems: "center",
            }}
          >
            <Box
              component={"form"}
              sx={{
                "& > :not(style)": { m: 1, width: "40ch" },
                display: "flex",
                flexDirection: "column",
                justifyContent: "center",
                alignItems: "center",
              }}
            >
              <TextField
                id="service"
                label="Service"
                name="service"
                variant="outlined"
                size="small"
                onChange={(e) =>
                  setFormVal({ ...formVal, [e.target.name]: e.target.value })
                }
              />
              <TextField
                id="distance"
                label="Distance"
                variant="outlined"
                name="meters"
                size="small"
                InputProps={{
                  endAdornment: (
                    <InputAdornment position="end">m</InputAdornment>
                  ),
                }}
                onChange={(e) =>
                  setFormVal({ ...formVal, [e.target.name]: e.target.value })
                }
              />

              <TextField
                id="currLoc"
                label="Address"
                variant="outlined"
                name="address"
                size="small"
                // disabled
                placeholder="Address should include state and country"
                onChange={(e) => {
                  setFormVal({ ...formVal, [e.target.name]: e.target.value });
                  setChooseAddress(true);
                }}
              />
              {!chooseAddress && (
                <Button onClick={() => getCurrentLocation()}>
                  Get Location
                </Button>
              )}
              <br />

              <Button
                variant="contained"
                color="success"
                sx={{
                  "& > :not(style)": { m: 1, width: "40ch" },
                }}
                onClick={() => {
                  // console.log(formVal);
                  getServices();
                }}
              >
                Search
              </Button>
              <Typography
                variant="body2"
                gutterBottom
                sx={{ textAlign: "center" }}
              >
                Lorem ipsum dolor sit amet, consectetur adipisicing elit. Quos
                blanditiis tenetur unde suscipit, quam beatae rerum inventore
                consectetur, neque doloribus,
              </Typography>
            </Box>
          </Grid>
        )}

        <Grid item xl={9} lg={12}>
          <ReactMapGl
            {...viewport}
            mapboxAccessToken={env.REACT_APP_MAPBOX_TOKEN}
            mapStyle="mapbox://styles/mapbox/streets-v9"
            style={{ width: "70vw", height: "70vh" }}
            onMove={(newViewport) => setViewport(newViewport.viewState)}
            onViewportChange={setViewport}
          >
            {/* Marker for initial location */}
            <Marker
              longitude={viewport.longitude}
              latitude={viewport.latitude}

              // offsetLeft={-20}
              // offsetTop={-10}
            />

            {/* Markers for selected services */}

            {selectedServices.map((services) => (
              <Marker
                key={services._id}
                longitude={services.location.coordinates[0]}
                latitude={services.location.coordinates[1]}
                color="red"
                onClick={() => handleMarkerClick(services)}
              >
                {/* <button
              className="marker-btn"
              onClick={(e) => {
                e.preventDefault();
                console.log(e.target);
                console.log(services);
                setServiceDetails(services);
              }}
            >
              <img
                src="locationimg.png"
                alt="location"
                width={"15px"}
                height={"15px"}
              />
            </button> */}
              </Marker>
            ))}
            {selectedMarker && isPopupOpen && (
              <Popup
                longitude={selectedMarker.location.coordinates[0]}
                latitude={selectedMarker.location.coordinates[1]}
                anchor="bottom"
                onClose={() => {
                  setSelectedMarker(null);
                  setPopupOpen(false);
                }}
                closeOnClick={false}
              >
                <div>
                  <h2>Name: {selectedMarker.serviceRendererName}</h2>
                  <p>Services: {selectedMarker.services}</p>
                  <p>Phone number: {selectedMarker.phoneNumber}</p>
                  <Box>
                    <Button
                      onClick={handleChatButtonClick}
                      aria-label="Start chat"
                    >
                      {loading ? "Connecting..." : "Chat Now"}{" "}
                    </Button>
                  </Box>
                </div>
              </Popup>
            )}
          </ReactMapGl>
        </Grid>
      </Grid>
      {/* <BackgroundPlayer /> */}
    </div>
  );
}

export default ServiceRendering;