const { defineConfig } = require('cypress')

module.exports = defineConfig({
  e2e: {
    setupNodeEvents(on, config) {
      // implement node event listeners here
    },
    // Ruta a tus archivos de especificaciones
    specPattern: 'cypress/integration/**/*.spec.js',
    // Directorio donde Cypress guardará los resultados de JUnit
    resultsFolder: 'cypress/results',
    videosFolder: 'cypress/videos', // Puedes quitar si no necesitas videos
    screenshotsFolder: 'cypress/screenshots', // Puedes quitar si no necesitas screenshots
    fixturesFolder: 'cypress/fixtures',
    supportFile: 'cypress/support/e2e.js', // Asegúrate de que este archivo exista en test/e2e/cypress/support/e2e.js
  },
  // Configuración del reporter JUnit
  reporter: 'junit',
  reporterOptions: {
    mochaFile: 'cypress/results/e2e_result.xml',
    toConsole: true,
  },
})