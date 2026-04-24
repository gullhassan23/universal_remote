module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  parserOptions: {
    ecmaVersion: 2022,
  },
  rules: {
    "quotes": ["error", "double"],
    "object-curly-spacing": ["error", "never"],
    "require-jsdoc": "off",
    "max-len": "off",
    "indent": "off",
  },
};
