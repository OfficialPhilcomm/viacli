# Setup
You need `LINEAR_API_TOKEN` set in your `ENV`.
The linear token is needed for interaction with their api.

Optionally, you can set the `OPENAI_API_TOKEN`. There are optional gpt integrations.
If you don't have an openai token, you can get request one from the APIX team.

`rake install` will install the gem to the cli.
Before using it the first time, you have to run `via setup`. This will fetch your linear user id, which is needed for some requests.

# Usage
Run `via -h` to see command usage.
More information on the issue command can be found with `via i -h` or `via issue -h`.
