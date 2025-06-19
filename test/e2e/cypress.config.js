const { defineConfig } = require('cypress')

module.exports = defineConfig({
  e2e: {
    setupNodeEvents(on, config) {
      // implement node event listeners here
    },
    specPattern: 'cypress/integration/**/*.spec.js',
    resultsFolder: 'results',
    videosFolder: 'cypress/videos',
    screenshotsFolder: 'cypress/screenshots',
    fixturesFolder: 'cypress/fixtures',
    supportFile: false,
  },
  reporter: 'junit',
  reporterOptions: {
    mochaFile: 'results/cypress_result.xml',
    toConsole: true,
  },
})
