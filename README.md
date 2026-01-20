# Stellar Service and Management

## Overview

Stellar Service and Management is a dynamic platform designed to simplify the process of connecting service providers with consumers. It addresses common challenges such as finding reliable providers, assessing service quality, and managing bookings efficiently. By creating a centralized marketplace, the platform makes it easy for consumers to browse various services and select those that best meet their needs.

## Key Features

- **Interactive Marketplace**: Browse and select from a diverse range of services with location-based search capabilities
- **Real-time Chat**: Seamless communication between consumers and service providers using Socket.IO
- **Quality Assurance**: Comprehensive rating and review mechanisms ensure reliable service delivery
- **Efficient Booking Management**: Helps service providers expand their reach and coordinate appointments effectively
- **Location-Based Services**: Find service providers near you with customizable search radius
- **Blockchain-Powered Payments**: Secure, transparent transactions using the Stellar network

## Architecture

The application follows a microservices architecture with the following components:

### Frontend
- Built with **React** for a responsive, modern user interface
- Styled using **Tailwind CSS** and **Material UI** components
- Interactive maps powered by **Mapbox GL**
- **Stellar SDK** integration for wallet connectivity and transactions

### Backend
- **Node.js** and **Express** for RESTful API services
- **MongoDB** for persistent data storage
- **Redis** for caching and real-time messaging support
- **Socket.IO** for real-time bidirectional communication

### Stellar Integration
- Integrated with the **Stellar blockchain** for secure and efficient transactions
- Low-cost, fast payment processing using Stellar Lumens (XLM) and custom assets
- Smart contract capabilities via **Soroban** for escrow and automated payments
- Multi-currency support for cross-border service payments

## Getting Started

### Prerequisites

Ensure you have the following installed:

- Node.js (v16 or later)
- npm
- MongoDB (local or remote connection)
- Redis (optional, for enhanced real-time features)
- Docker (optional, for running services in containers)
- Stellar account (testnet for development, mainnet for production)

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Servora/servicemgtapp.git
   cd servicemgtapp
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Create an environment file**:
   ```bash
   cp .env.example .env
   ```

4. **Update the .env file** with the required configurations:
   - MongoDB connection string
   - Redis connection details
   - JWT secret key
   - Mapbox API token
   - Stellar network configuration (testnet/mainnet)
   - Stellar Horizon URL
   - Stellar distribution account secret key

   Example configuration:
   ```env
   MONGODB_URI=mongodb://localhost:27017/stellar-service-mgmt
   REDIS_URL=redis://localhost:6379
   JWT_SECRET=your-secret-key
   MAPBOX_TOKEN=your-mapbox-token
   
   # Stellar Configuration
   STELLAR_NETWORK=testnet
   STELLAR_HORIZON_URL=https://horizon-testnet.stellar.org
   STELLAR_PLATFORM_SECRET=YOUR_SECRET_KEY
   STELLAR_PLATFORM_PUBLIC=YOUR_PUBLIC_KEY
   ```

5. **Start the development server**:
   ```bash
   npm run dev
   ```

## Running in Production

1. **Build the project**:
   ```bash
   npm run build
   ```

2. **Start the production server**:
   ```bash
   npm start
   ```

## Docker Deployment

The application can be run using Docker for consistent deployment across environments:

```bash
docker-compose up --build
```

This will start all required services including:
- Web frontend
- Service providers API
- Consumers API
- MongoDB database
- Redis cache
- Stellar blockchain integration service

## Project Structure

```
servicesmgtapi/
├── consumers-api/         # Consumer microservice
├── frontend/              # Frontend application (React)
├── stellar-integration/   # Stellar blockchain integration
│   ├── contracts/         # Soroban smart contracts (Rust)
│   ├── scripts/           # Deployment and interaction scripts
│   ├── test/              # Smart contract tests
│   └── README.md          # Stellar integration documentation
├── servicerender-api/     # Service renderer microservice
├── blockchain-api/        # API for blockchain interactions
│   ├── src/
│   │   ├── controllers/   # Controllers for Stellar operations
│   │   ├── routes/        # API routes for blockchain interactions
│   │   ├── services/      # Stellar SDK integration services
│   │   ├── utils/         # Utility functions for Stellar operations
│   │   └── app.js         # Main application file
│   └── package.json       # Dependencies for blockchain API
├── .gitignore
├── docker-compose.yml
├── README.md
└── contribution.md
```

## Stellar Blockchain Features

### Payment Processing
- **Instant Payments**: Fast transaction finality (3-5 seconds)
- **Low Fees**: Minimal transaction costs compared to traditional payment processors
- **Multi-Currency**: Support for XLM and custom Stellar assets

### Smart Contracts (Soroban)
- **Escrow Services**: Automated fund holding until service completion
- **Dispute Resolution**: Smart contract-based arbitration
- **Automated Refunds**: Conditional refund logic based on service delivery

### Security
- **Decentralized**: No single point of failure
- **Transparent**: All transactions recorded on public ledger
- **Secure**: Cryptographic signatures for all operations

## API Documentation

### Stellar Integration Endpoints

```
POST /api/stellar/create-account
POST /api/stellar/payment
POST /api/stellar/escrow/create
POST /api/stellar/escrow/release
GET /api/stellar/balance/:publicKey
GET /api/stellar/transaction/:txHash
```

Full API documentation is available at `/api/docs` when running the server.

## Testing

```bash
# Run all tests
npm test

# Run Stellar integration tests
npm run test:stellar

# Run frontend tests
cd frontend && npm test
```

## Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a new branch (`git checkout -b feature-branch`)
3. Commit your changes (`git commit -m 'Add new feature'`)
4. Push to the branch (`git push origin feature-branch`)
5. Open a Pull Request

Please ensure your code follows our coding standards and includes appropriate tests.

## Security Considerations

- Never commit private keys or secret keys to the repository
- Use environment variables for all sensitive configuration
- Implement rate limiting on blockchain operations
- Regular security audits recommended for production deployment
- Use Stellar's testnet for development and testing

## Roadmap

- [ ] Mobile application (React Native)
- [ ] Multi-signature wallet support
- [ ] Stablecoin payment options (USDC on Stellar)
- [ ] Advanced analytics dashboard
- [ ] Integration with traditional payment gateways
- [ ] Multi-language support


## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

© 2024 Stellar Service and Management. All rights reserved.

Built with ❤️ by the Stellar Service and Management Team
