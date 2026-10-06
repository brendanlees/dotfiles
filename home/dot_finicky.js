export default {
  defaultBrowser: "Dia",
  handlers: [
    // macOS sends mailto links directly to its default email app.
    // Uncomment only for mailto URLs explicitly passed to Finicky.
    // {
    //   match: (url) => url.protocol === "mailto:",
    //   browser: "Mimestream",
    // },
    {
      match: (url) => url.hostname === "open.spotify.com",
      browser: "Spotify",
    },
  ],
};
