# scripts
 
Setup scripts for my self-hosted tools, served via [sh.mawenqian.com](https://sh.mawenqian.com).
 
## Usage
 
```bash
curl -fsSL https://sh.mawenqian.com/<script-name> | bash
```
 
```powershell
irm https://sh.mawenqian.com/<script-name> | iex
```
 
See the full list of available scripts at [sh.mawenqian.com](https://sh.mawenqian.com)


## How it works
 
`sh.mawenqian.com` is a Cloudflare Worker that reads `routes.json` from this repo and 302-redirects `sh.mawenqian.com/<name>` to the corresponding raw GitHub URL. Visiting the root shows an index of all available scripts.