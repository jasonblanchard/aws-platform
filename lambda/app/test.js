const { handler } = require('./index');

async function main() {
  const response = await handler({}, {});
  console.log(response);
}

main();
