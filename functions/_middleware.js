// Cloudflare Pages middleware: Markdown content negotiation for AI agents.
// https://developers.cloudflare.com/pages/functions/middleware/
//
// When a client sends `Accept: text/markdown`, serve the raw Markdown twin
// (/<slug>/index.md, emitted by _plugins/markdown_twins.rb) instead of the full
// themed HTML page. This is the Content dimension of Cloudflare's Agent
// Readiness score, and cuts response tokens substantially for agents/LLMs.
//
// Everything else falls through to normal static asset serving via next().

const CONTENT_SIGNAL = "search=yes, ai-input=yes, ai-train=no";

export async function onRequest(context) {
  const { request, next, env } = context;
  const accept = request.headers.get("Accept") || "";

  // Only act when the client explicitly prefers Markdown, and only for the
  // pretty "/slug/" page URLs that have a twin. Never touch asset requests.
  const url = new URL(request.url);
  if (/text\/markdown/i.test(accept) && url.pathname.endsWith("/")) {
    const mdUrl = new URL(url);
    mdUrl.pathname = url.pathname + "index.md";

    // env.ASSETS.fetch goes straight to static assets (no Function recursion).
    const mdResp = await env.ASSETS.fetch(new Request(mdUrl.toString(), request));
    if (mdResp.ok) {
      const md = await mdResp.text();
      const headers = {
        "Content-Type": "text/markdown; charset=utf-8",
        "Content-Signal": CONTENT_SIGNAL,
        // ~4 chars/token heuristic; advertised as a hint, not an exact count.
        "x-markdown-tokens": String(Math.ceil(md.length / 4)),
        // Caches must key on Accept so HTML and Markdown don't clobber.
        "Vary": "Accept",
      };
      return new Response(md, { status: 200, headers });
    }
    // No twin for this path -> fall through to the normal HTML response.
  }

  return next();
}
