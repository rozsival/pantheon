export default {
  overrides: [
    {
      // Shell sources only, so the ```bash usage blocks in Markdown (`<command>`) stay untouched. The options give the
      // output of `shfmt -i 2`. bin/pantheon has no extension and stays bashly's own output.
      files: ['*.sh'],
      options: {
        binaryNextLine: false,
        plugins: ['prettier-plugin-sh'],
        spaceRedirects: false,
        switchCaseIndent: false
      }
    }
  ],
  plugins: ['prettier-plugin-packagejson', 'prettier-plugin-toml'],
  printWidth: 120,
  singleQuote: true,
  trailingComma: 'none'
};
