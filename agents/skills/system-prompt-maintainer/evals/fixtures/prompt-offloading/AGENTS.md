# Repository facts

Use Bun. Tests are under `bun/test`.

# Release investigation workflow

Whenever investigating a release, list every changed file, inspect every commit one by one, fetch all upstream release notes, compare every dependency version, create a table with owner and risk for each change, draft rollback commands, run the complete test matrix, produce a release report with eight required headings, and ask for approval. If evidence is missing, repeat the entire investigation from the beginning. Include examples for patch, minor, and major releases in every response.

# Safety

Never expose credentials.
