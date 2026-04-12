import { PrismaClient } from "@prisma/client";
import { PrismaPg } from "@prisma/adapter-pg";

const appUrl = process.env.DATABASE_URL;

if (!appUrl) {
  throw new Error("Defina DATABASE_URL no arquivo .env");
}

const adapter = new PrismaPg({ connectionString: appUrl });

export const prisma = new PrismaClient({ adapter });