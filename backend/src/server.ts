import { app } from './app.js';
import { prisma } from './utils/prismaClient.js';

const port = process.env.PORT || 3333;

const server = app.listen(port, () => {
  console.log(`Server running on http://localhost:${port}`);
});

const shutDown = async () => {
  console.log('Shutting down server...');
  await prisma.$disconnect();
  server.close(() => process.exit(0));
};

process.on('SIGINT', shutDown);
process.on('SIGTERM', shutDown);
