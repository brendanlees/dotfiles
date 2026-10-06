export default {
  defaultBrowser: "Dia",
  handlers: [
    {
      match: (url) => url.protocol === "mailto:",
      browser: "Mimestream",
    },
    {
      match: (url) => url.hostname === "open.spotify.com",
      browser: "Spotify",
    },
  ],
};
