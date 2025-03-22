process.env.NODE_ENV = process.env.NODE_ENV || 'production'

process.env.WINTOOK_BOT = 'https://bot.wintook.com'
process.env.WINTOOK_API = 'https://api.wintook.com/api'
process.env.WINTOOK_OPENAI = 'https://openai.wintook.com/api'

const environment = require('./environment')

module.exports = environment.toWebpackConfig()
