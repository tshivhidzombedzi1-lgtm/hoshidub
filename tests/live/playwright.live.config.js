const { defineConfig } = require('@playwright/test');

module.exports = defineConfig({
  testDir: __dirname,
  testMatch: /\.live\.spec\.js$/,
  timeout: 420_000,
  workers: 1,
  reporter: [['list']],
});
