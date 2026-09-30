# Emit a raw Markdown "twin" of every post and page for AI-agent content
# negotiation (Cloudflare Agent Readiness -> Content dimension).
#
# For a page served at /some-slug/ this writes /some-slug/index.md containing the
# page's own Markdown source (front matter stripped) with an H1 title prepended.
# The functions/_middleware.js worker serves this file when a client sends
# `Accept: text/markdown`, cutting tokens vs. the full themed HTML page.
#
# We use a StaticFile subclass rather than a Page so Jekyll does NOT run the
# Markdown converter on it — a `.md` Page would be turned back into HTML, which
# is exactly what we are trying to avoid. StaticFile writes bytes verbatim.
module Jekyll
  class MarkdownTwinFile < StaticFile
    def initialize(site, dir, name, content)
      @site = site
      @dir  = dir           # output dir relative to site root, e.g. "nlp-in-5gw"
      @name = name          # "index.md"
      @content = content
      @relative_path = File.join(@dir, @name)
      @extname = File.extname(@name)
    end

    # Write our in-memory content instead of copying a source file.
    def write(dest)
      dest_path = destination(dest)
      FileUtils.mkdir_p(File.dirname(dest_path))
      File.write(dest_path, @content)
      true
    end

    # Always regenerate; there is no source mtime to compare against.
    def modified?
      true
    end
  end

  class MarkdownTwinGenerator < Generator
    safe false
    priority :lowest

    def generate(site)
      docs = site.posts.docs.dup
      pages_coll = site.collections["pages"]
      docs.concat(pages_coll.docs) if pages_coll

      docs.each do |doc|
        url = doc.url.to_s
        # Only pretty "/slug/" URLs map cleanly to "/slug/index.md".
        next unless url.end_with?("/")

        dir = url.sub(%r{\A/}, "").chomp("/")
        title = doc.data["title"].to_s
        body  = doc.content.to_s   # raw Markdown source at generate time

        md = +""
        md << "# #{title}\n\n" unless title.empty?
        md << body
        md << "\n" unless md.end_with?("\n")

        site.static_files << MarkdownTwinFile.new(site, dir, "index.md", md)
      end

      # Homepage twin at /index.md. The real index.html is a Liquid post-list
      # template, so build a genuinely useful Markdown summary from site data
      # instead: title, description, and the most recent posts.
      home = +"# #{site.config["title"]}\n\n"
      desc = site.config["description"].to_s
      home << "> #{desc}\n\n" unless desc.empty?
      home << "Homepage of #{site.config["url"]}. " \
              "See /llms.txt for a curated reading list and " \
              "/sitemap.xml for the full URL list.\n\n"
      home << "## Recent posts\n\n"
      site.posts.docs.sort_by(&:date).reverse.first(25).each do |p|
        title = p.data["title"].to_s
        ex = p.data["excerpt"]
        ex = ex.is_a?(String) ? ex.gsub(/\s+/, " ").strip : ""
        line = +"- [#{title}](#{p.url})"
        line << " — #{ex}" unless ex.empty?
        home << line << "\n"
      end
      home << "\n"
      site.static_files << MarkdownTwinFile.new(site, "", "index.md", home)
    end
  end
end
