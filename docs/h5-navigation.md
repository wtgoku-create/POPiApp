# Public H5 navigation

Use `H5Page.open(context, title: title, url: url)` for public pages that the
mobile app displays in the generic H5 browser. On Web it launches the original
URL in a new browser tab (`_blank`) without pushing an app route. On native
platforms it opens the existing embedded H5 page. Supply `location` to retain
an existing go_router route, such as `/legal/privacy-policy`, on native apps.

Call it directly from the user's click handler, before asynchronous requests,
to retain browser user activation. Web navigation accepts public HTTP(S) URLs
and adds no app credentials. Launch failures show one toast and keep the source
page, including any open consent dialog, intact.

Legal links, About links, privacy consent links and notification web targets
share this entry point. Internal notification destinations remain app routes.
Teaching documents retain their current reader and native bridge behavior.
