const { defineConfig } = require('cypress')

module.exports = defineConfig({
  e2e: {
    setupNodeEvents(on, config) {

    },
    specPattern: 'cypress/integration/**/*.spec.js',
    resultsFolder: 'cypress/results',
    videosFolder: 'cypress/videos',
    screenshotsFolder: 'cypress/screenshots',
    fixturesFolder: 'cypress/fixtures',
    supportFile: 'cypress/support/index.js',
  },
  reporter: 'junit',
  reporterOptions: {
    mochaFile: 'cypress/results/e2e_result.xml',
    toConsole: true,
  },
})
