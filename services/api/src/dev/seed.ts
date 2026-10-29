import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';
import { assertNotProduction, DEMO_CUSTOMER, DEMO_PROVIDERS, seedDemoData } from './demo-data';

// Entry point for `npm run db:seed` / `npx prisma db seed`. The logic lives in
// demo-data.ts, which is unit tested; this file only wires up the real
// database and bcrypt, so it is left out of coverage like main.ts.
async function main() {
  assertNotProduction(process.env);
  const prisma = new PrismaClient();
  try {
    const result = await seedDemoData(prisma, (plain) => bcrypt.hash(plain, 10));
    console.log(
      `Seeded ${result.categories} categories, ${result.subServices} sub-services, ` +
        `${result.providers} providers${result.requestCreated ? ', 1 request' : ''}.`,
    );
    console.log(
      `Demo logins (password in src/dev/demo-data.ts): customer ${DEMO_CUSTOMER.mobile}, ` +
        `providers ${DEMO_PROVIDERS.map((p) => p.mobile).join(', ')}.`,
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
