export default {
  defaultBrowser: "Dia",
  rewrite: [
    {
      match: (url) => url.origin === "https://app.notion.com",
      url: (url) => url.href.replace(/^https:/, "notion:"),
    },
  ],
  handlers: [
    {
      match: (url) =>
        url.protocol === "notion:" && url.hostname === "app.notion.com",
      browser: "Notion",
    },
    // macOS sends mailto links directly to its default email app.
    // Uncomment only for mailto URLs explicitly passed to Finicky.
    // {
    //   match: (url) => url.protocol === "mailto:",
    //   browser: "Mimestream",
    // },
  ],
};
